# frozen_string_literal: true

require 'test_helper'

class CommentTest < Minitest::Test
  def setup
    @octokit = mock
    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
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

  private

  attr_reader :comment, :octokit
end
