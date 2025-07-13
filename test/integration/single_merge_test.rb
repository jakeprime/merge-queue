# frozen_string_literal: true

require 'integration_test_helper'

require_relative '../../lib/merge_queue'

class SingleMergeTest < IntegrationTest
  def test_single_merge
    pull_request = create_pull_request

    config = default_config.merge(
      pr_number: pull_request.number,
      run_id: Random.rand(100_000),
    )

    MergeQueue.call(**config)

    assert_pr_merged(pull_request)
  end
end
