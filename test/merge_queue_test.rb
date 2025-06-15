# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/merge_queue'

class MergeQueueTest < Minitest::Test
  def setup
    @merge_queue = MergeQueue.new

    Ci.stubs(:new).with(pull_request).returns(ci)
    Comment.stubs(:init)
    PullRequest.stubs(:new).returns(pull_request)
    QueueState.stubs(:new).returns(queue_state)
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

  private

  attr_reader :merge_queue

  def pull_request
    @pull_request ||= stub(
      branch_name: 'branch',
      create_merge_branch: true,
      mergeable?: true,
      rebaseable?: true,
      terminate_descendants: true,
    )
      .responds_like_instance_of(PullRequest)
  end

  def ci
    @ci ||= stub(result: 'success').responds_like_instance_of(Ci)
  end

  def queue_state
    @queue_state ||= stub(terminate_descendants: true)
      .responds_like_instance_of(QueueState)
  end
end
