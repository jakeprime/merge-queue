# frozen_string_literal: true

require 'integration_test_helper'

require_relative '../../lib/merge_queue'

class MultipleMergeTest < IntegrationTest
  def test_multiple_merges
    # we'll need to create the queue state in this case, as otherwise the
    # parallel processes will try to create a new one each at the same time and
    # this will fail.
    initialize_queue_state

    pull_requests = 2.times.map do
      create_pull_request("Feature #{it}")
    end

    pull_requests.map do |pull_request|
      Thread.new do
        config = default_config.merge(
          pr_number: pull_request.number,
          run_id: Random.rand(100_000),
          ci_poll_interval: 0.5,
          ci_wait_time: 5,
          lock_poll_interval: 0.5,
          lock_wait_time: 5,
        )
        MergeQueue.call(config)
      end
    end
      .each(&:join)

    pull_requests.each { assert_pr_merged(it) }
  end
end
