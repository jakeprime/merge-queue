# frozen_string_literal: true

require 'test_helper'

class QueueStateTest < Minitest::Test
  def test_initializes_git_repo
    GitRepo
      .expects(:init)
      .with(name: 'queue_state', repo: PROJECT_REPO, branch: 'merge-queue-state')
      .returns(stub(read_file: { branchCounter: 1, mergeBranches: [] }.to_json))

    queue_state
  end

  def test_branch_counter
    stub_state(branchCounter: 1)

    assert_equal 2, queue_state.branch_counter!
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

  def stub_state(**params)
    json = { branchCounter: 1, mergeBranches: [] }.merge(params).to_json
    git_repo = stub(read_file: json)
    GitRepo.stubs(:init).returns(git_repo)
  end
end
