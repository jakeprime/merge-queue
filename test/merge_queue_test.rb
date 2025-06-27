# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/merge_queue'

class MergeQueueTest < Minitest::Test
  def setup
    @merge_queue = MergeQueue.new

    Ci.stubs(:new).with(pull_request).returns(ci)
    Comment.stubs(:init)
    Comment.stubs(:message)
    Comment.stubs(:error)
    Lock.stubs(:instance).returns(lock)
    PullRequest.stubs(:instance).returns(pull_request)
    QueueState.stubs(:instance).returns(queue_state)
  end

  def test_create_initial_comment
    Comment.expects(:init)

    merge_queue.call
  end

  def test_ensure_pr_mergeable
    pull_request.stubs(:mergeable?).returns(false)

    assert_raises MergeQueue::PrNotMergeableError do
      merge_queue.call
    end
  end

  def test_ensure_pr_rebaseable
    pull_request.stubs(:rebaseable?).returns(false)

    assert_raises MergeQueue::PrNotRebaseableError do
      merge_queue.call
    end
  end

  def test_create_merge_branch
    pull_request.expects(:create_merge_branch)

    merge_queue.call
  end

  def test_terminate_descendants
    ci.stubs(:result).returns('failure')

    queue_state.expects(:terminate_descendants).with(pull_request)

    merge_queue.call
  end

  def test_wait_until_front_of_queue
    queue_state.expects(:wait_until_front_of_queue).with(pull_request)

    merge_queue.call
  end

  def test_merge
    skip 'removing actual merge to test dry runs'
    pull_request.expects(:merge!)

    merge_queue.call
  end

  def test_update_status
    queue_state.expects(:update_status).with(pull_request:, status: 'success')

    merge_queue.call
  end

  def test_fail_without_retry
    ci.stubs(result: 'failure')

    pull_request.expects(:merge!).never

    merge_queue.call
  end

  private

  attr_reader :merge_queue

  def pull_request
    @pull_request ||= stub(
      'PullRequest',
      branch_name: 'branch',
      create_merge_branch: true,
      delete_remote_branch: nil,
      merge!: true,
      mergeable?: true,
      rebaseable?: true,
    ).responds_like_instance_of(PullRequest)
  end

  def ci
    @ci ||= stub('Ci', result: 'success').responds_like_instance_of(Ci)
  end

  def queue_state
    @queue_state ||= stub(
      'QueueState',
      remove_branch: nil,
      terminate_descendants: true,
      update_status: nil,
      wait_until_front_of_queue: true,
    ).responds_like_instance_of(QueueState)
  end

  def lock
    @lock ||= stub(
      'Lock',
      ensure_released: nil,
    ).responds_like_instance_of(Lock).tap do
      it.stubs(:with_lock).yields
    end
  end
end
