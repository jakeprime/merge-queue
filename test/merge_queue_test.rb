# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/merge_queue'

class MergeQueueTest < Minitest::Test
  def setup
    @merge_queue = MergeQueue.new

    Comment.stubs(:init)
    PullRequest.stubs(:new).returns(pull_request)
  end

  def test_create_initial_comment
    Comment.expects(:init)

    merge_queue.call
  end

  def test_ensure_pr_mergeable
    pull_request.unstub(:mergeable?)
    pull_request.stubs(:mergeable?).returns(false)

    assert_raises MergeQueue::PrNotMergeableError do
      merge_queue.call
    end
  end

  def test_ensure_pr_rebaseable
    pull_request.unstub(:rebaseable?)
    pull_request.stubs(:rebaseable?).returns(false)

    assert_raises MergeQueue::PrNotRebaseableError do
      merge_queue.call
    end
  end

  private

  attr_reader :merge_queue

  def pull_request
    @pull_request ||= stub(mergeable?: true, rebaseable?: true)
  end
end
