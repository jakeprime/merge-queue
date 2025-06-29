# frozen_string_literal: true

require 'forwardable'

require_relative './ci'
require_relative './comment'
require_relative './configurable'
require_relative './github_logger'
require_relative './lock'
require_relative './mergeability_monitor'
require_relative './pull_request'
require_relative './queue_state'

# Main class running the merging process
class MergeQueue
  extend Forwardable
  include Configurable

  MergeFailedError = Class.new(StandardError)
  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  # Accessors for all the objects we're going to need. These will act as global
  # accessors ensuring that we have a single instance of them that can maintain
  # state.
  def ci = @ci ||= Ci.new(self)
  def comment = @comment ||= Comment.new(self)
  def mergeability_monitor = @mergeability_monitor ||= MergeabilityMonitor.new(self)
  def pull_request = @pull_request ||= PullRequest.new(self)
  def queue_state = @queue_state ||= QueueState.new(self)
  def lock = @lock ||= Lock.new(self)

  def call
    comment.init(:initializing)

    ensure_pr_rebaseable

    create_merge_branch

    handle_ci_result

    wait_until_front_of_queue

    if ci_result == Ci::SUCCESS
      merge!
    else
      fail_without_retry
    end
  rescue StandardError
    GithubLogger.error('Something has gone wrong, cleaning up before exiting')

    queue_state.terminate_descendants(pull_request)

    raise
  ensure
    teardown
  end

  private

  def ensure_pr_rebaseable
    GithubLogger.debug('Checking if PR is rebaseable')

    if !pull_request.mergeable?
      comment.error(:not_mergeable)
      raise PrNotMergeableError
    end

    if !pull_request.rebaseable?
      comment.error(:not_rebaseable)
      raise PrNotRebaseableError
    end

    true
  end

  def create_merge_branch
    GithubLogger.debug('Creating merge branch')
    comment.message(:checking_queue)

    pull_request.create_merge_branch
  end

  def ci_result
    @ci_result ||= ci.result
  end

  def handle_ci_result
    result = ci_result

    with_lock do
      queue_state.update_status(pull_request:, status: result)
      terminate_descendants if ci_result == Ci::FAILURE
    end
  end

  def terminate_descendants
    queue_state.terminate_descendants(pull_request)
  end

  def wait_until_front_of_queue
    queue_state.wait_until_front_of_queue(pull_request)
  end

  def merge!
    comment.message(:ready_to_merge, include_queue: false)
    pull_request.merge!
    comment.message(:merged, include_queue: false)
  end

  def fail_without_retry
    comment.message('The problem is me')
    raise MergeFailedError
  end

  def teardown
    with_lock do
      pull_request.delete_remote_branch
      queue_state.remove_branch(pull_request)
    end
    lock.ensure_released
  end

  def_delegators :lock, :with_lock
end
