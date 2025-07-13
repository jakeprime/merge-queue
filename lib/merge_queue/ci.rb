# frozen_string_literal: true

require 'forwardable'

require_relative './errors'

module MergeQueue
  class Ci
    extend Forwardable

    SUCCESS = 'success'
    FAILURE = 'failure'
    PENDING = 'pending'

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def result
      comment.message(:waiting_for_ci, ci_link:)

      max_polls.times do
        mergeability_monitor.check!
        return state if complete?

        sleep(ci_poll_interval)
      end

      comment.error(:ci_timeout)
      raise CiTimeoutError
    end

    private

    attr_reader :merge_queue, :state

    def_delegators :merge_queue, :comment, :config, :github, :mergeability_monitor,
                   :pull_request
    def_delegators :config, :ci_poll_interval, :ci_timeout, :project_repo

    def complete?
      state = github.status(pull_request.merge_sha).state
      GithubLogger.info "CI state is #{state}"

      return false if state == PENDING

      @state = state

      comment.message(:ci_passed) if state == SUCCESS
      comment.error(:ci_failed) if state == FAILURE

      true
    end

    def ci_link
      merge_branch = pull_request.merge_branch
      "https://app.circleci.com/pipelines/github/#{project_repo}?branch=#{merge_branch}"
    end

    def max_polls = (ci_timeout / ci_poll_interval).round
  end
end
