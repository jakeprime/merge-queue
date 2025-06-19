# frozen_string_literal: true

require 'octokit'

require_relative './mergeability_monitor'
require_relative './pull_request'

class Ci
  SUCCESS = 'success'
  FAILURE = 'failure'
  PENDING = 'pending'

  # WAIT_TIME = 20 * 60 # 20 minutes
  # POLL_INTERVAL = 10 # 10 seconds
  WAIT_TIME = 60 # 20 minutes
  POLL_INTERVAL = 5 # 10 seconds

  CiTimeoutError = Class.new(StandardError)

  def initialize(pull_request)
    @pull_request = pull_request
  end

  attr_reader :pull_request

  def result
    max_polls.times do
      MergeabilityMonitor.check!
      return state if complete?

      sleep(POLL_INTERVAL)
    end

    raise CiTimeoutError
  end

  private

  attr_reader :state

  def complete?
    state = octokit.status(project_repo, pull_request.merge_sha).state
    return false if state == PENDING

    @state = state

    true
  end

  def max_polls = (WAIT_TIME / POLL_INTERVAL).round

  def octokit = @octokit ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
