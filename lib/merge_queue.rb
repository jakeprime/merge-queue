# frozen_string_literal: true

require_relative './ci'
require_relative './comment'
require_relative './github_logger'
require_relative './lock'
require_relative './pull_request'
require_relative './queue_state'

# Main class running the merging process
class MergeQueue
  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  def call
    Comment.init(:initializing)

    ensure_pr_rebaseable
    create_merge_branch
    terminate_descendants if ci_result == Ci::FAILURE

    wait_until_front_of_queue

    if ci_result == Ci::SUCCESS
      merge!
    else
      fail_without_retry
    end
  rescue StandardError
    GithubLogger.error('Something has gone wrong, cleaning up before exiting')

    lock.with_lock do
      queue_state.terminate_descendants(pull_request)
    end

    raise
  ensure
    teardown
  end

  private

  def ensure_pr_rebaseable
    GithubLogger.debug('Checking if PR is rebaseable')

    if !pull_request.mergeable?
      Comment.message(:not_mergeable)
      raise PrNotMergeableError
    end

    if !pull_request.rebaseable?
      Comment.message(:not_rebaseable)
      raise PrNotRebaseableError
    end

    true
  end

  def create_merge_branch
    GithubLogger.debug('Creating merge branch')

    pull_request.create_merge_branch
  end

  def ci_result
    @ci_result ||= Ci.new(pull_request).result
  end

  def terminate_descendants
    queue_state.terminate_descendants(pull_request)
  end

  def wait_until_front_of_queue
    queue_state.wait_until_front_of_queue(pull_request)
  end

  def merge!
    Comment.message(:ready_to_merge)
    pull_request.merge!
    Comment.message(:merged)
  end

  def fail_without_retry
    Comment.message('The problem is me')
  end

  def teardown
    lock.with_lock do
      pull_request.delete_remote_branch
      queue_state.remove_branch(pull_request)
    end
    lock.ensure_released
  end

  def pull_request = @pull_request ||= PullRequest.instance
  def queue_state = @queue_state ||= QueueState.new
  def lock = @lock ||= Lock.new

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
