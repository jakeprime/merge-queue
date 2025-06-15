# frozen_string_literal: true

require 'octokit'

require_relative './pull_request'

class Ci
  WAIT_TIME = 20 * 60 # 20 minutes
  POLL_INTERVAL = 10 # 10 seconds

  CiTimeoutError = Class.new(StandardError)

  def initialize(pull_request)
    @pull_request = pull_request
  end

  def result
    max_polls.times do
      return ci_status if complete?

      sleep(POLL_INTERVAL)
    end

    raise CiTimeoutError
  end

  private

  def complete?
    state = octokit.status(project_repo, pull_request.merge_sha)
    return false unless %w[success fail].include?(state)

    @state = state

    true
  end

  def ci_status = :success

  def max_polls = (WAIT_TIME / POLL_INTERVAL).round

  def octokit = @octokit ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
end
