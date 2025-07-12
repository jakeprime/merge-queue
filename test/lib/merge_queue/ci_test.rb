# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/ci'
require_relative '../../../lib/merge_queue/errors'

module MergeQueue
  class CiTest < UnitTest
    def setup
      stub_merge_queue(:comment, :github, :mergeability_monitor, :pull_request)
      @ci = Ci.new(merge_queue)
    end

    def around
      Ci.stub_consts(WAIT_TIME: 0.03, POLL_INTERVAL: 0.01) do
        super
      end
    end

    def test_result_success
      github.stubs(:status).returns(stub(state: 'success'))

      assert_equal 'success', ci.result
    end

    def test_result_retries_if_pending
      github
        .expects(:status)
        .returns(stub(state: 'pending'), stub(state: 'success'))
        .twice

      assert_equal 'success', ci.result
    end

    def test_result_times_out
      github.stubs(:status).returns(stub(state: 'pending'))

      assert_raises ::MergeQueue::CiTimeoutError do
        ci.result
      end
    end

    def test_mergeability_is_checked
      github.stubs(:status).returns(stub(state: 'success'))
      mergeability_monitor.expects(:check!).at_least_once

      ci.result
    end
  end
end
