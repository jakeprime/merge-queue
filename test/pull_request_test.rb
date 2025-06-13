# frozen_string_literal: true

require 'test_helper'

class PullRequestTest < Minitest::Test
  def setup
    @branch_name = 'branch-name'
    @sha = 'cab005e'
    @title = 'title'

    stub_octokit
  end

  def test_branch_name
    pull_request = PullRequest.new

    assert_equal branch_name, pull_request.branch_name
  end

  def test_mergeable
    pull_request = PullRequest.new

    assert_predicate pull_request, :mergeable?
  end

  def test_rebaseable
    pull_request = PullRequest.new

    assert_predicate pull_request, :rebaseable?
  end

  def test_sha
    pull_request = PullRequest.new

    assert_equal sha, pull_request.sha
  end

  def test_title
    pull_request = PullRequest.new

    assert_equal title, pull_request.title
  end

  private

  attr_reader :branch_name, :octokit, :sha, :title

  def stub_octokit
    head = stub(ref: branch_name, sha:)
    pull = stub(head:, mergeable?: true, rebaseable?: true, title:, )
    @octokit = stub(pull:)

    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
  end
end
