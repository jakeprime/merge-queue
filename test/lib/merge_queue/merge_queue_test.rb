# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/config'
require_relative '../../../lib/merge_queue/merge_queue'

module MergeQueue
  class MergeQueueTest < UnitTest
    def setup
      @merge_queue = MergeQueue.new(Config.new)

      stub_objects(:comment, :lock, :queue_state)

      # stub the happy paths for these, we can override with failures in
      # individual tests
      stub_ci(result: 'success')
      stub_pull_request(merge!: true, mergeable?: true, rebaseable?: true)

      Ci.stubs(:new).with(merge_queue).returns(ci)
      Comment.stubs(:new).with(merge_queue).returns(comment)
      Lock.stubs(:new).with(merge_queue).returns(lock)
      PullRequest.stubs(:new).with(merge_queue).returns(pull_request)
      QueueState.stubs(:new).returns(queue_state)
    end

    def test_create_initial_comment
      comment.expects(:init)

      merge_queue.call
    end

    def test_ensure_pr_mergeable
      pull_request.stubs(:mergeable?).returns(false)

      assert_raises ::MergeQueue::PrNotMergeableError do
        merge_queue.call
      end
    end

    def test_ensure_pr_rebaseable
      pull_request.stubs(:rebaseable?).returns(false)

      assert_raises ::MergeQueue::PrNotRebaseableError do
        merge_queue.call
      end
    end

    def test_create_merge_branch
      pull_request.expects(:create_merge_branch)

      merge_queue.call
    end

    def test_terminate_descendants
      ci.stubs(:result).returns('failure')

      queue_state.expects(:terminate_descendants).with(pull_request).at_least_once

      assert_raises { merge_queue.call }
    end

    def test_wait_until_front_of_queue
      queue_state.expects(:wait_until_front_of_queue).with(pull_request)

      merge_queue.call
    end

    def test_merge
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

      assert_raises ::MergeQueue::MergeFailedError do
        merge_queue.call
      end
    end

    private

    attr_reader :merge_queue
  end
end
