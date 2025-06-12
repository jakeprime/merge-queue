# frozen_string_literal: true

require 'test_helper'

class MergeQueueTest < Minitest::Test
  def setup
    @merge_queue = MergeQueue.new
  end

  def test_create_initial_comment
    Comment.expects(:init)

    merge_queue.call
  end

  private

  attr_reader :merge_queue
end
