# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/ci'
require_relative '../lib/mergeability_monitor'

class CiTest < Minitest::Test
  def setup
    Octokit::Client.stubs(:new).returns(octokit)
    MergeabilityMonitor.stubs(:check!)
    Comment.stubs(:message)
  end

  def around(&)
    Ci.stub_consts(WAIT_TIME: 0.03, POLL_INTERVAL: 0.01, &)
  end

  def test_result_success
    octokit.stubs(:status).returns(stub(state: 'success'))

    assert_equal 'success', ci.result
  end

  def test_result_retries_if_pending
    octokit.unstub(:status)
    octokit
      .expects(:status)
      .returns(stub(state: 'pending'), stub(state: 'success'))
      .twice

    assert_equal 'success', ci.result
  end

  def test_result_times_out
    octokit.stubs(:status).returns(stub(state: 'pending'))

    assert_raises Ci::CiTimeoutError do
      ci.result
    end
  end

  def test_mergeability_is_checked
    MergeabilityMonitor.expects(:check!).at_least_once

    ci.result
  end

  private

  def ci
    @ci ||= Ci.new(pull_request)
  end

  def pull_request
    @pull_request ||= stub(
      merge_sha: 'cab005e',
      merge_branch: 'merge-branch/pr1-1',
    )
      .responds_like_instance_of(PullRequest)
  end

  def octokit
    @octokit ||= stub(status: stub(state: 'success'))
      .responds_like_instance_of(Octokit::Client)
  end
end
