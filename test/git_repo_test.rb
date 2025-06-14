# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/git_repo'

class GitRepoTest < Minitest::Test
  def setup
    # prevent leakage of state between tests
    GitRepo.repos = {}
    FileUtils.stubs(:mkdir_p)

    stub_git
  end

  def test_init_only_creates_one_repo_with_name
    git_repo = GitRepo.init(name: 'name', repo: 'repo')

    assert_equal git_repo, GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_create_working_directory
    FileUtils.unstub(:mkdir_p)
    FileUtils.expects(:mkdir_p).with("#{WORKSPACE_DIR}/name")

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_initializes_git
    Git.unstub(:init)
    Git.expects(:init).with("#{WORKSPACE_DIR}/name").returns(git)

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_checkout_main
    git.expects(:add_remote).with('origin', 'https://github.com/repo')
    git.expects(:fetch).with('origin', depth: 1, ref: 'main')
    git.expects(:checkout).with('main')

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_checkout_branch
    git.expects(:add_remote).with('origin', 'https://github.com/repo')
    git.expects(:fetch).with('origin', depth: 1, ref: 'branch')
    git.expects(:checkout).with('branch')

    GitRepo.init(name: 'name', repo: 'repo', branch: 'branch')
  end

  private

  attr_reader :git

  def stub_git
    @git = stub(add_remote: nil, fetch: nil, checkout: nil)
    Git.stubs(:init).returns(git)
  end
end
