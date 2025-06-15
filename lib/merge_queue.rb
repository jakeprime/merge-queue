# frozen_string_literal: true

require_relative './ci'
require_relative './comment'
require_relative './github_logger'
require_relative './pull_request'
require_relative './queue_state'

# Main class running the merging process
class MergeQueue
  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  def call
    create_initial_comment
    ensure_pr_rebaseable!

    create_merge_branch

    terminate_descendants if ci_result == Ci::FAILURE

    wait_until_front_of_queue

  #   if ci_result == Ci::SUCCESS
  #     merge_pr
  #   else
  #     fail_without_retry
  #   end
  end

  private

  def create_initial_comment
    GithubLogger.debug('Creating initial comment')

    Comment.init('🌱 Initialising merging process...')
  end

  def ensure_pr_rebaseable!
    GithubLogger.debug('Checking if PR is rebaseable')

    raise PrNotMergeableError unless pull_request.mergeable?
    raise PrNotRebaseableError unless pull_request.rebaseable?
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

  def pull_request = @pull_request ||= PullRequest.new
  def queue_state = @queue_state ||= QueueState.new

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
