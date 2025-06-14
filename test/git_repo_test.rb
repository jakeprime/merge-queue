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

  def test_read_file
    git.unstub(:read_file)
    git.expects(:read_file).with('file_path').returns('contents')

    assert_equal 'contents', git_repo.read_file('file_path')
  end

  def test_write_file
    File.expects(:write).with("#{WORKSPACE_DIR}/name/file", 'contents', mode: 'w')

    git_repo.write_file('file', 'contents')
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

  def git_repo(name: 'name', repo: 'repo')
    @git_repo ||= GitRepo.init(name:, repo:)
  end

  def stub_git
    @git = stub(add_remote: nil, checkout: nil, fetch: nil, read_file: '', write_file: '')
    Git.stubs(:init).returns(git)
  end
end
