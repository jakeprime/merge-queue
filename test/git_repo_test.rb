# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/git_repo'

class GitRepoTest < Minitest::Test
  def setup
    # prevent leakage of state between tests
    GitRepo.repos = {}
    FileUtils.stubs(:mkdir_p)
  end

  def test_init_only_creates_one_repo_with_name
    git_repo = GitRepo.init(name: 'name', repo: 'repo')

    assert_equal git_repo, GitRepo.init(name: 'name', repo: 'repo')
  end

  def test_create_working_directory
    FileUtils.unstub(:mkdir_p)
    FileUtils.expects(:mkdir_p).with("#{WORKSPACE_DIR}/name")

    git_repo = GitRepo.init(name: 'name', repo: 'repo')
  end
end
