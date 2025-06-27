# frozen_string_literal: true

require_relative './ci'
require_relative './comment'
require_relative './github_logger'
require_relative './lock'
require_relative './pull_request'
require_relative './queue_state'

# Main class running the merging process
class MergeQueue
  extend Forwardable

  MergeFailedError = Class.new(StandardError)
  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  def call
    Comment.init(:initializing)

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
      Comment.error(:not_mergeable)
      raise PrNotMergeableError
    end

    if !pull_request.rebaseable?
      Comment.error(:not_rebaseable)
      raise PrNotRebaseableError
    end

    true
  end

  def create_merge_branch
    GithubLogger.debug('Creating merge branch')
    Comment.message(:checking_queue)

    pull_request.create_merge_branch
  end

  def ci_result
    @ci_result ||= Ci.new(pull_request).result
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
    Comment.message(:ready_to_merge)
    # pull_request.merge!
    Comment.message(:merged)
  end

  def fail_without_retry
    Comment.message('The problem is me')
    raise MergeFailedError
  end

  def teardown
    with_lock do
      pull_request.delete_remote_branch
      queue_state.remove_branch(pull_request)
    end
    lock.ensure_released
  end

  def pull_request = @pull_request ||= PullRequest.instance
  def queue_state = @queue_state ||= QueueState.instance
  def lock = @lock ||= Lock.instance
  def_delegators :lock, :with_lock

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
