# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../lib/merge_queue'
require_relative '../../lib/merge_queue/errors'

class MergeQueueTest < UnitTest
  def setup
    @merge_queue = stub('MergeQueue')
    merge_queue.stubs(:configure).returns(merge_queue)
    MergeQueue::MergeQueue.expects(:new).returns(merge_queue)
  end

  attr_reader :merge_queue, :entrypoint

  def test_merge_queue_runs_once_without_errors
    merge_queue.expects(:call).once

    MergeQueue.call
  end

  def test_merge_queue_runs_once_with_error
    merge_queue.expects(:call).raises(MergeQueue::Error).once

    assert_raises ::MergeQueue::Error do
      MergeQueue.call
    end
  end

  def test_merge_queue_retries_on_retriable_error
    merge_queue.expects(:call).once

    failing_merge_queue = stub('MergeQueueFailing').tap do
      it.stubs(:configure).returns(it)
      it.expects(:call).raises(MergeQueue::RetriableError).once
    end

    MergeQueue::MergeQueue.unstub(:new)
    MergeQueue::MergeQueue.expects(:new).returns(failing_merge_queue, merge_queue).twice

    MergeQueue.call
  end
end
