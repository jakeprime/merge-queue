# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/comment'

module MergeQueue
  class CommentTest < UnitTest
    def setup
      stub_merge_queue(:github, :queue_state)
      queue_state.stubs(:to_table).returns('')

      @comment = Comment.new(merge_queue)
    end

    def test_initial_commit
      message = 'An initial message'
      mock_result = mock(id: 321)

      github
        .expects(:add_comment)
        .with(PR_NUMBER, message)
        .returns(mock_result)

      comment.init(message)
    end

    def test_message
      message = 'A message'
      github.stubs(:add_comment).returns(mock(id: 321))
      comment.init(message)

      github.expects(:update_comment).with(321, message)

      comment.message(message)
    end
  end
end
