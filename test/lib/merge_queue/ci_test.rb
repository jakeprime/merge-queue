# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/ci'
require_relative '../../../lib/merge_queue/errors'

module MergeQueue
  class CiTest < UnitTest
    def setup
      stub_merge_queue(:comment, :mergeability_monitor, :pull_request)
      @ci = Ci.new(merge_queue)

      Octokit::Client.stubs(:new).returns(octokit)
    end

    def around
      Ci.stub_consts(WAIT_TIME: 0.03, POLL_INTERVAL: 0.01) do
        super
      end
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

      assert_raises ::MergeQueue::CiTimeoutError do
        ci.result
      end
    end

    def test_mergeability_is_checked
      mergeability_monitor.expects(:check!).at_least_once

      ci.result
    end

    private

    def octokit
      @octokit ||= stub(status: stub(state: 'success'))
        .responds_like_instance_of(Octokit::Client)
    end
  end
end
