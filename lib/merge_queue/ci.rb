# frozen_string_literal: true

require 'forwardable'

require_relative './errors'

module MergeQueue
  class Ci
    extend Forwardable

    ERROR = 'error'
    FAILURE = 'failure'
    PENDING = 'pending'
    SUCCESS = 'success'

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

    def ci_link
      merge_branch = pull_request.merge_branch
      "https://app.circleci.com/pipelines/github/#{project_repo}?branch=#{merge_branch}"
    end

    private

    attr_reader :merge_queue, :state

    def_delegators :merge_queue, :comment, :config, :github, :mergeability_monitor,
                   :pull_request
    def_delegators :config, :ci_poll_interval, :ci_timeout, :project_repo

    # This assumes an external CI run, e.g. on Circle. If the CI step is run in
    # Github action it will not be included in the statuses of the commit. If
    # that happens the state will remain "pending" indefinitely and this will
    # timeout.
    def complete?
      terminal_statuses = [SUCCESS, FAILURE]

      state = github.status(pull_request.merge_sha).state
      GithubLogger.info "CI state is #{state}"

      if state == ERROR
        comment.error(:ci_error)
        raise CiRunError
      end

      return false unless terminal_statuses.include?(state)

      @state = state

      comment.message(:ci_passed) if state == SUCCESS
      comment.eror(:ci_failed) if state == FAILURE

      true
    end

    def max_polls = (ci_timeout / ci_poll_interval).round
  end
end
