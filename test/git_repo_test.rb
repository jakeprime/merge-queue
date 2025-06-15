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

  private

  attr_reader :git

  def git_repo(name: 'name', repo: 'repo')
    @git_repo ||= GitRepo.init(name:, repo:)
  end

  def stub_git
    @git = stub(
      add_remote: nil,
      checkout: nil,
      fetch: nil,
      pull: nil,
      read_file: '',
      write_file: nil,
    ).responds_like_instance_of(Git::Base)
    Git.stubs(:init).returns(git)
  end

  def stub_file
    File.stubs(:read)
    File.stubs(:write)
    FileUtils.stubs(:mkdir_p)
  end
end
