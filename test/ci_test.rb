# frozen_string_literal: true

require 'test_helper'

require_relative '../lib/ci'

class CiTest < Minitest::Test
  def around(&)
    Ci.stub_consts(WAIT_TIME: 0.03, POLL_INTERVAL: 0.01, &)
  end

  def test_result_success
    assert_equal :success, ci.result
  end

  private

  def ci
    @ci ||= Ci.new(pull_request)
  end

  def pull_request
    @pull_request ||= stub
      .responds_like_instance_of(PullRequest)
  end
end
