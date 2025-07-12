# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/comment'

module MergeQueue
  class CommentTest < UnitTest
    def setup
      stub_merge_queue(:queue_state)
      queue_state.stubs(:to_table).returns('')

      @comment = Comment.new(merge_queue)

      @octokit = mock('Octokit')
      Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
    end

    def test_initial_commit
      message = 'An initial message'
      mock_result = mock(id: 321)

      octokit
        .expects(:add_comment)
        .with(PROJECT_REPO, PR_NUMBER, message)
        .returns(mock_result)

      comment.init(message)
    end

    def test_message
      message = 'A message'
      octokit.stubs(:add_comment).returns(mock(id: 321))
      comment.init(message)

      octokit
        .expects(:update_comment)
        .with(PROJECT_REPO, 321, message)

      comment.message(message)
    end

    private

    attr_reader :octokit
  end
end
