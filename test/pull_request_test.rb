# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/pull_request'

class PullRequestTest < Minitest::Test
  def setup
    @branch_name = 'branch-name'
    @sha = 'cab005e'
    @title = 'title'

    stub_octokit

    @pull_request = PullRequest.new
  end

  def test_branch_name
    assert_equal branch_name, pull_request.branch_name
  end

  def test_mergeable
    assert_predicate pull_request, :mergeable?
  end

  def test_rebaseable
    assert_predicate pull_request, :rebaseable?
  end

  def test_sha
    assert_equal sha, pull_request.sha
  end

  def test_title
    assert_equal title, pull_request.title
  end

  def test_init_merge_branches_set_base_branch
    stub_queue_state(latest_merge_branch: nil)

    pull_request.init_merge_branches

    assert_equal 'main', pull_request.base_branch
  end

  def test_init_merge_branches_set_merge_branch
    stub_queue_state(branch_counter!: 2)

    pull_request.init_merge_branches

    assert_equal 'merge-branch/title-2', pull_request.merge_branch
  end

  private

  attr_reader :branch_name, :queue_state, :octokit, :pull_request, :sha, :title

  def stub_queue_state(**params)
    stubs = {
      branch_counter!: 1,
      latest_merge_branch: nil,
    }.merge(params)

    @queue_state = stub(**stubs)
    QueueState.stubs(:new).returns(queue_state)
  end

  def stub_octokit
    head = stub(ref: branch_name, sha:)
    pull = stub(head:, mergeable?: true, rebaseable?: true, title:)
    @octokit = stub(pull:)

    Octokit::Client.stubs(:new).with(access_token: ACCESS_TOKEN).returns(octokit)
  end
end
