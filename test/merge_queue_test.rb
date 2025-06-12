# frozen_string_literal: true

require 'test_helper'

class MergeQueueTest < Minitest::Test
  include Memery

  def setup
    @merge_queue = MergeQueue.new

    stub_octokit

    Comment.stubs(:init)
  end

  def test_create_initial_comment
    Comment.expects(:init)

    merge_queue.call
  end

  def test_ensure_pr_mergeable
    pull_result.unstub(:mergeable?)
    pull_result.stubs(:mergeable?).returns(false)

    assert_raises MergeQueue::PrNotMergeableError do
      merge_queue.call
    end
  end

  def test_ensure_pr_rebaseable
    pull_result.unstub(:rebaseable?)
    pull_result.stubs(:rebaseable?).returns(false)

    assert_raises MergeQueue::PrNotRebaseableError do
      merge_queue.call
    end
  end

  private

  attr_reader :merge_queue, :octokit

  def stub_octokit
    @octokit = mock(pull: pull_result)
    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
  end

  def pull_result
    mock.tap do
      it.stubs(:mergeable?).returns(true)
      it.stubs(:rebaseable?).returns(true)
    end
  end
  memoize :pull_result, :octokit
end
