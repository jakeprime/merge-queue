# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/comment'

class CommentTest < Minitest::Test
  def setup
    @octokit = mock
    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
    QueueState.stubs(:instance).returns(queue_state)
  end

  def test_initial_commit
    message = 'An initial message'
    mock_result = mock(id: 321)

    octokit
      .expects(:add_comment)
      .with(PROJECT_REPO, PR_NUMBER, message)
      .returns(mock_result)

    Comment.init(message)
  end

  def test_message
    message = 'A message'
    octokit.stubs(:add_comment).returns(mock(id: 321))
    Comment.init(message)

    octokit
      .expects(:update_comment)
      .with(PROJECT_REPO, 321, message)

    Comment.message(message)
  end

  private

  attr_reader :comment, :octokit

  def queue_state
    @queue_state ||= stub(
      'QueueState',
      to_table: '',
    ).responds_like_instance_of(QueueState)
  end
end
