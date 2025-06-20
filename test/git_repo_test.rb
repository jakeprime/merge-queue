# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/git_repo'

class GitRepoTest < Minitest::Test
  def setup
    # prevent leakage of state between tests
    GitRepo.repos = {}

    stub_file
    stub_git
  end

  def test_init_only_creates_one_repo_with_name
    assert_equal git_repo, GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_init_creates_branch_if_required
    Git::FailedError.any_instance.stubs(:error_message)
    git.stubs(:fetch).raises(Git::FailedError.new(''))

    Dir.expects(:chdir).with("#{WORKSPACE_DIR}/name").yields
    GitRepo.any_instance
      .expects(:system)
      .with('git', 'checkout', '--orphan', 'branch')

    GitRepo.init(name: 'name', repo: 'repo', branch: 'branch', create_if_missing: true)
  end

  def test_find_retrieves_repo
    project_repo = GitRepo.init(name: 'project', repo: 'repo')

    assert_equal project_repo, GitRepo.find('project')
  end

  def test_create_working_directory
    FileUtils.expects(:mkdir_p).with("#{WORKSPACE_DIR}/name")

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_initializes_git
    Git.expects(:init).with("#{WORKSPACE_DIR}/name").returns(git)

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_read_file_that_exists
    git.expects(:pull)
    File.expects(:read).with("#{WORKSPACE_DIR}/name/file").returns('contents')

    assert_equal 'contents', git_repo.read_file('file')
  end

  def test_read_file_that_does_not_exists
    git.expects(:pull)
    File.expects(:read).raises(Errno::ENOENT)

    assert_nil git_repo.read_file('file')
  end

  def test_reset_to_origin
    git.expects(:add)
    git.expects(:reset_hard).with('origin/branch')
    git.expects(:pull)

    git_repo.reset_to_origin
  end

  def test_delete_file
    FileUtils.expects(:rm).with("#{WORKSPACE_DIR}/name/file")

    git_repo.delete_file('file')
  end

  def test_write_file
    File.expects(:write).with("#{WORKSPACE_DIR}/name/file", 'contents', mode: 'w')

    git_repo.write_file('file', 'contents')
  end

  def test_checkout_main
    git.expects(:add_remote).with('origin', "https://#{ACCESS_TOKEN}@github.com/repo")
    git.expects(:fetch).with('origin', depth: 1, ref: 'main')
    git.expects(:checkout).with('main')

    GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_checkout_branch
    git.expects(:add_remote).with('origin', "https://#{ACCESS_TOKEN}@github.com/repo")
    git.expects(:fetch).with('origin', depth: 1, ref: 'branch')
    git.expects(:checkout).with('branch')

    GitRepo.init(name: 'name', repo: 'repo', branch: 'branch')
  end

  def test_create_branch
    git
      .expects(:checkout)
      .with('merge-branch', new_branch: true, start_point: 'branch')
    expect_rebase('merge-branch', onto: 'base-branch')
    git.expects(:object).with('HEAD').returns(stub(sha: 'c4b0o5e'))

    merge_sha = git_repo.create_branch(
      'merge-branch', from: 'branch', rebase_onto: 'base-branch',
    )
    assert_equal 'c4b0o5e', merge_sha
  end

  def test_merge_to_main
    git.expects(:fetch).with('origin', ref: 'main')
    expect_rebase('pr-branch', onto: 'origin/main')
    git.expects(:push).with('origin', 'pr-branch', force: true)
    git.expects(:checkout).with('main')
    git.expects(:pull).with('origin', 'main')
    git.expects(:merge).with('pr-branch', anything, no_ff: true)
    git.expects(:push).with('origin', 'main', force: true)

    git_repo.merge_to_main!('pr-branch')
  end

  def test_push_changes_succeeds
    git.expects(:add)
    git.expects(:commit).with('message')
    git.expects(:push).with('origin', 'branch')

    git_repo.push_changes('message')
  end

  def test_push_changes_fails_on_push
    Git::FailedError.any_instance.stubs(:error_message)
    git.expects(:push).raises(Git::FailedError.new(''))

    assert_raises GitRepo::RemoteBeenUpdatedError do
      git_repo.push_changes('message')
    end
  end

  def test_push_fails_for_any_other_reason
    git.expects(:add).raises(Git::Error)

    assert_raises Git::Error do
      git_repo.push_changes('message')
    end
  end

  def test_remote_sha
    git.expects(:fetch).with('origin', ref: 'branch')
    git.expects(:rev_parse).with('origin/branch').returns('c48005e')

    assert_equal 'c48005e', git_repo.remote_sha
  end

  private

  attr_reader :git

  def git_repo(name: 'name', repo: 'repo', branch: 'branch')
    @git_repo ||= GitRepo.init(name:, repo:, branch:)
  end

  def stub_git
    @git = stub(
      add: nil,
      add_remote: nil,
      checkout: nil,
      commit: nil,
      config: nil,
      fetch: nil,
      merge: nil,
      pull: nil,
      push: nil,
    ).responds_like_instance_of(Git::Base)
    Git.stubs(:init).returns(git)
  end

  def stub_file
    File.stubs(:read)
    File.stubs(:write)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:chdir)
  end

  def expect_rebase(branch, onto:)
    git.expects(:checkout).with(branch)
    Dir.expects(:chdir).with("#{WORKSPACE_DIR}/name").yields
    git_repo.expects(:system).with('git', 'rebase', onto)
  end
end
