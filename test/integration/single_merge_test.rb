# frozen_string_literal: true

require 'integration_test_helper'

require_relative '../../lib/merge_queue'

class SingleMergeTest < IntegrationTest
  def test_single_merge
    pr = create_pull_request

    ClimateControl.modify(
      GITHUB_RUN_ID: Time.now.to_i.to_s,
      PR_NUMBER: pr.number.to_s,
    ) do
      MergeQueue.call
    end

    assert_pr_merged(pr)
  end
end
