# frozen_string_literal: true

require 'test_helper'

require_relative './integration/api_fixture'

require 'climate_control'
require 'open3'

require_relative '../lib/merge_queue/git_repo'

# We'll use a real git repo for the integration test. It will take a bit longer
# to execute, but the alternative would be to mock Git's functionality. And
# while that's certainly do-able it is error prone, and we are depending on a
# lot of git behaviour for this merge process to work safely.

class IntegrationTest < Minitest::Test
  WORKING_DIR = File.expand_path('../tmp/merge_queue_tests', __dir__)
  REMOTE_REPO_PATH = "#{WORKING_DIR}/remote_git_repo".freeze
  LOCAL_REPO_PATH = "#{WORKING_DIR}/local_git_repo".freeze
  TEST_REPO_NAME = 'octocat/Hello-World'

  def setup
    # make sure working dir repos aren't left from a previous test
    FileUtils.rm_rf(WORKING_DIR)

    mock_origin_paths
    mock_ci_result
    create_remote_repo
  end

  def default_config
    {
      access_token: 'shhh_very_secret',
      ci_poll_interval: 0.1,
      ci_wait_time: 0.3,
      lock_poll_interval: 0.1,
      lock_wait_time: 0.3,
      project_repo: REMOTE_REPO_PATH,
      workspace_dir: "#{WORKING_DIR}/#{SecureRandom.uuid}",
    }
  end

  def mock_origin_paths
    # The filepath we are using to the local test origin repo will work fine for
    # git operations, but we do need to mock it in a couple of places

    # 1. GitRepo will construct a github URI using the supplied path and the access token
    MergeQueue::GitRepo.any_instance.stubs(:remote_uri).returns(REMOTE_REPO_PATH)

    # # 2. Octokit expects an "owner/repo" github style path
    MergeQueue::Github.any_instance.stubs(:project_repo).returns(TEST_REPO_NAME)
  end

  def gh_response_headers
    {
      'Content-Type' => 'application/json; charset=utf-8',
      'X-GitHub-Media-Type' => 'github.v3; format=json',
    }
  end

  def mock_ci_result
    stub_request(:get, %r{commits/.+/status}).to_return do |request|
      sha = request.uri.to_s.match(%r{commits/(.+)/status})[1]
      {
        status: 200,
        body: ApiFixture::CommitStatus.new(sha:).to_s,
        headers: gh_response_headers,
      }
    end
  end

  def create_remote_repo
    FileUtils.mkdir_p(REMOTE_REPO_PATH)
    FileUtils.mkdir_p(LOCAL_REPO_PATH)

    # Create a bare repo that we treat like the Github remote
    Dir.chdir(REMOTE_REPO_PATH) do
      system('git', 'init', '--bare', '--quiet')
    end

    # And a working repo so we can push changes to it
    Dir.chdir(LOCAL_REPO_PATH) do
      system('git', 'init', '--quiet')
      system('git', 'remote', 'add', 'origin', REMOTE_REPO_PATH)
      File.write('code_file', <<~CODE)
        method_call(arg1)
        method_call(arg2)
      CODE
      system('git', 'add', '.')
      system('git', 'commit', '-m', 'Initial commit', '--quiet')
      system('git', 'push', '--set-upstream', 'origin', 'main', '--quiet')
    end
  end

  def initialize_queue_state
    new_lock = JSON.pretty_generate(
      { branchCounter: 1, mergeBranches: [] },
    )
    Dir.chdir(LOCAL_REPO_PATH) do
      system('git', 'checkout', 'main', '--quiet')
      system('git', 'checkout', '--orphan', 'merge-queue-state', '--quiet')
      FileUtils.rm('code_file')
      File.write('state.json', new_lock)
      system('git', 'add', '.')
      system('git', 'commit', '-m', 'Initializing merge queue branch', '--quiet')
      system('git', 'push', '--set-upstream', 'origin', 'merge-queue-state', '--quiet')
    end
  end

  def create_pull_request(title = 'Feature')
    pr = MockPullRequest.new(title)

    branch_name = pr.branch_name
    sha = pr.sha

    stub_github_request(
      "pulls/#{pr.number}",
      ApiFixture::PullRequest.new(branch_name:, sha:),
    )
    stub_github_request(
      "issues/#{pr.number}/comments", ApiFixture::Comment.new, method: :post, status: 201,
    )
    stub_github_request('issues/comments/1', method: :patch)

    pr
  end

  def stub_github_request(path, body = '', method: :get, status: 200)
    stub_request(method, "https://api.github.com/repos/#{TEST_REPO_NAME}/#{path}")
      .to_return(status:, body: body.to_s, headers: gh_response_headers)
  end

  def assert_pr_merged(pull_request)
    Dir.chdir(LOCAL_REPO_PATH) do
      system('git', 'fetch', '--quiet')

      pr_head, = Open3.capture2('git', 'rev-parse', "origin/#{pull_request.branch_name}")
      main_shas, = Open3.capture2('git', 'rev-list', 'origin/main')

      assert_includes main_shas, pr_head
    end
  end

  class MockPullRequest
    @counter = 1

    class << self
      attr_accessor :counter
    end

    def initialize(title)
      @title = title
      @branch_name = title.gsub(/[^a-zA-Z0-9]/, '-').downcase
      @number = self.class.counter += 1

      create_branch
    end

    attr_reader :title, :branch_name, :number, :sha

    def create_branch
      Dir.chdir(LOCAL_REPO_PATH) do
        system('git', 'pull', '--quiet')
        system('git', 'checkout', '-b', branch_name, '--quiet')
        File.write("code_file_#{branch_name}", <<~CODE)
          # added in #{branch_name}
          another_method_call
        CODE
        system('git', 'add', '.')
        system('git', 'commit', '-m', title, '--quiet')
        @sha, = Open3.capture2('git', 'rev-parse', 'HEAD')
        system('git', 'push', '--set-upstream', 'origin', branch_name, '--quiet')
        system('git', 'checkout', 'main', '--quiet')

        # create another commit so that main is ahead of the branch point
        File.write('code_file', <<~CODE)
          # added to main branch - #{number}
          method_call(arg1, arg2)
          method_call(arg2)
        CODE
        system('git', 'add', '.')
        system('git', 'commit', '-m', 'Random commit', '--quiet')
        system('git', 'push', '--quiet')
      end
    end
  end
end
