# frozen_string_literal: true

require 'json'
require 'test_helper'

require_relative '../lib/mergeability_monitor'
require_relative '../lib/pull_request'
require_relative '../lib/queue_state'

class QueueStateTest < Minitest::Test
  def setup
    GitRepo.stubs(:init).returns(git_repo)
    MergeabilityMonitor.stubs(:check!)
    Comment.stubs(:message)
    Comment.stubs(:error)
  end

  def around(&)
    QueueState.stub_consts(WAIT_TIME: 0.03, POLL_INTERVAL: 0.01, &)
  end

  def test_initializes_git_repo
    GitRepo
      .expects(:init)
      .with(
        name: 'queue_state',
        repo: PROJECT_REPO,
        branch: 'merge-queue-state',
        create_if_missing: true,
      )
      .returns(git_repo)

    queue_state.latest_merge_branch
  end

  def test_next_branch_counter_result
    stub_state(branchCounter: 1)

    assert_equal 2, queue_state.next_branch_counter
  end

  def test_next_branch_counter_writes_to_file
    stub_state(branchCounter: 1)

    git_repo.expects(:write_file).with do |file, contents|
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
      { name: 'early-branch', status: 'pending', count: 5 },
      { name: 'expected-branch', status: 'pending', count: 6 },
      { name: 'failing-branch', status: 'failed', count: 7 },
    ]

    stub_state(mergeBranches: merge_branches)

    assert_equal 'expected-branch', queue_state.latest_merge_branch
  end

  def test_add_branch
    initial_state = {
      branchCounter: 28,
      mergeBranches: [
        { name: 'mb-27', status: 'pending', ancestors: ['mb-26'] },
      ],
    }

    git_repo.expects(:read_file).with('state.json').returns(initial_state.to_json)

    pull_request.stubs(:as_json).returns({ name: 'mb-28' })
    pull_request.stubs(:base_branch).returns('mb-27')

    expected_state = {
      branchCounter: 28,
      mergeBranches: [
        { name: 'mb-27', status: 'pending', ancestors: ['mb-26'] },
        { name: 'mb-28', status: 'pending', ancestors: ['mb-26', 'mb-27'] },
      ],
    }

    git_repo.expects(:write_file).with do |_file, contents|
      assert_equal JSON.pretty_generate(expected_state), contents
    end

    queue_state.add_branch(pull_request)
  end

  def test_entry
    branch1 = { 'name' => 'mb-27', 'sha' => 'ca80053' }
    branch2 = { 'name' => 'mb-28', 'sha' => 'c4b005e' }

    stub_state(mergeBranches: [branch1, branch2])

    pull_request.stubs(:merge_branch).returns('mb-28')

    assert_equal branch2, queue_state.entry(pull_request)
  end

  def test_terminate_descendants
    initial_state = {
      branchCounter: 30,
      mergeBranches: [
        { name: 'mb-26', status: 'pending', ancestors: [] },
        { name: 'mb-27', status: 'failed', ancestors: ['mb-26'] },
        { name: 'mb-28', status: 'pending', ancestors: ['mb-26', 'mb-27'] },
        { name: 'mb-29', status: 'pending', ancestors: ['mb-26', 'mb-27', 'mb-28'] },
      ],
    }

    git_repo.expects(:read_file).with('state.json').returns(initial_state.to_json)

    pull_request.stubs(:merge_branch).returns('mb-27')

    expected_state = {
      branchCounter: 30,
      mergeBranches: [
        { name: 'mb-26', status: 'pending', ancestors: [] },
        { name: 'mb-27', status: 'failed', ancestors: ['mb-26'] },
      ],
    }

    git_repo.expects(:write_file).with do |_file, contents|
      assert_equal JSON.pretty_generate(expected_state), contents
    end

    queue_state.terminate_descendants(pull_request)
  end

  def test_wait_until_front_of_queue_when_front
    state = {
      branchCounter: 30,
      mergeBranches: [{ name: 'mb-26', count: 29 }],
    }
    git_repo.stubs(:read_file).with('state.json').returns(state.to_json)
    pull_request.stubs(:merge_branch).returns('mb-26')

    assert queue_state.wait_until_front_of_queue(pull_request)
  end

  def test_wait_until_front_of_queue_times_out
    state = {
      branchCounter: 30,
      mergeBranches: [{ name: 'mb-26', count: 29 }],
    }
    git_repo.stubs(:read_file).with('state.json').returns(state.to_json)
    pull_request.stubs(:branch_name).returns('mb-27')

    assert_raises QueueState::QueueTimeoutError do
      queue_state.wait_until_front_of_queue(pull_request)
    end
  end

  def test_wait_until_front_of_queue_retries_until_front
    state1 = {
      branchCounter: 30,
      mergeBranches: [{ name: 'mb-25', count: 29 }, { name: 'mb-26', count: 29 }],
    }
    state2 = {
      branchCounter: 30,
      mergeBranches: [{ name: 'mb-26', count: 29 }],
    }

    git_repo.unstub(:read_file)
    git_repo.stubs(:read_file).returns(state1.to_json, state2.to_json).twice

    pull_request.stubs(:merge_branch).returns('mb-26')

    assert queue_state.wait_until_front_of_queue(pull_request)
  end

  def test_wait_until_front_of_queue_checks_mergeability
    MergeabilityMonitor.expects(:check!).raises

    assert_raises do
      queue_state.wait_until_front_of_queue(pull_request)
    end
  end

  private

  def pull_request
    @pull_request ||= stub(
      'PullRequest',
      branch_name: 'mb-1',
      merge_branch: 'merge-queue/mb-1',
    )
      .responds_like_instance_of(PullRequest)
      .tap { PullRequest.stubs(:new).returns(it) }
  end

  def queue_state
    @queue_state ||= QueueState.new
  end

  def stub_state(**params)
    git_repo
      .stubs(:read_file)
      .returns({ branchCounter: 1, mergeBranches: [] }.merge(params).to_json)
  end

  def git_repo
    @git_repo ||= begin
      json = { branchCounter: 1, mergeBranches: [] }.to_json
      stub('GitRepo', read_file: json, write_file: true)
        .responds_like_instance_of(GitRepo)
    end
  end
end
