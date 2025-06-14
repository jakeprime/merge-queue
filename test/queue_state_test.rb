# frozen_string_literal: true

require 'json'
require 'test_helper'

require_relative '../lib/queue_state'

class QueueStateTest < Minitest::Test
  def test_initializes_git_repo
    GitRepo
      .expects(:init)
      .with(name: 'queue_state', repo: PROJECT_REPO, branch: 'merge-queue-state')
      .returns(git_repo_mock)

    queue_state.latest_merge_branch
  end

  def test_next_branch_counter_result
    stub_state(branchCounter: 1)

    assert_equal 2, queue_state.next_branch_counter
  end

  def test_next_branch_counter_writes_to_file
    stub_state(branchCounter: 1)

    git_repo_mock.expects(:write_file).with do |file, contents|
      assert_equal 'state.json', file

      state = JSON.parse(contents)
      assert_equal 2, state['branchCounter']
    end

    queue_state.next_branch_counter
  end

  def test_latest_merge_branch_when_none
    stub_state(mergeBranches: [])

    assert_equal 'main', queue_state.latest_merge_branch
  end

  def test_latest_merge_branch_when_exists
    merge_branches = [
      { name: 'early-branch', status: 'running', count: 5 },
      { name: 'expected-branch', status: 'running', count: 6 },
      { name: 'failing-branch', status: 'failed', count: 7 },
    ]

    stub_state(mergeBranches: merge_branches)

    assert_equal 'expected-branch', queue_state.latest_merge_branch
  end

  private

  def queue_state
    @queue_state ||= QueueState.new
  end

  def stub_state(**)
    GitRepo.stubs(:init).returns(git_repo_mock(**))
  end

  def git_repo_mock(**params)
    @git_repo_mock ||= begin
      json = { branchCounter: 1, mergeBranches: [] }.merge(params).to_json
      stub(read_file: json, write_file: true)
    end
  end
end
