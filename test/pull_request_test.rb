# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/pull_request'

class PullRequestTest < Minitest::Test
  def setup
    @branch_name = 'branch-name'
    @sha = 'cab005e'
    @title = 'title'

    stub_git_repo
    stub_octokit
    stub_queue_state
    Lock.any_instance.stubs(:with_lock).yields
  end

  def test_branch_name
    assert_equal branch_name, pull_request.branch_name
  end

  def test_mergeable
    assert_predicate pull_request, :mergeable?
  end

  def test_rebaseable
    assert_predicate pull_request, :rebaseable?
  end

  def test_sha
    pull_request.create_merge_branch
    assert_equal sha, pull_request.sha
  end

  def test_title
    assert_equal title, pull_request.title
  end

  def test_create_merge_branch
    stub_queue_state(latest_merge_branch: 'merge-branch-1', next_branch_counter: 5)
    git_repo
      .expects(:create_branch)
      .with(
        "merge-branch/#{branch_name}-5",
        from: branch_name,
        rebase_onto: 'merge-branch-1',
      )
    queue_state.expects(:add_branch).with(pull_request)
    Lock.any_instance.stubs(:with_lock).yields

    pull_request.create_merge_branch
  end

  def test_create_branch
    # TODO: test this
  end

  def test_merge
    git_repo.expects(:merge_to_main!).with(branch_name)

    pull_request.merge!
  end

  def test_as_json
    stub_queue_state(next_branch_counter: 25)
    git_repo.stubs(:create_branch).returns('c48o05e')

    expected = {
      name: "merge-branch/#{branch_name}-25",
      title:,
      pr_number: PR_NUMBER,
      sha:,
      count: 25,
    }

    pull_request.create_merge_branch

    assert_equal expected, pull_request.as_json
  end

  private

  attr_reader :branch_name, :git_repo, :pull_head, :queue_state, :octokit, :sha, :title

  def stub_queue_state(**params)
    stubs = {
      next_branch_counter: 1,
      latest_merge_branch: 'main',
      add_branch: true,
    }.merge(params)

    @queue_state = stub(**stubs)
    QueueState.stubs(:new).returns(queue_state)
  end

  def stub_octokit
    @pull_head = stub(ref: branch_name, sha:)
    pull = stub(head: pull_head, mergeable?: true, rebaseable?: true, title:)
    @octokit = stub(pull:)

    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
  end

  def stub_git_repo
    @git_repo = stub(
      create_branch: true,
      fetch_until_common_commit: true,
      merge_to_main!: true,
    ).responds_like_instance_of(GitRepo)
    GitRepo
      .stubs(:init)
      .with(name: 'project', repo: PROJECT_REPO, branch: branch_name)
      .returns(git_repo)
  end

  def pull_request = @pull_request ||= PullRequest.new
end
