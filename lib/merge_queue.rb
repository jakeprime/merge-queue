# frozen_string_literal: true

require_relative './comment'
require_relative './github_logger'
require_relative './pull_request'

# Main class running the merging process
class MergeQueue
  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  def call
    create_initial_comment
    ensure_pr_rebaseable!

    create_merge_branch
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
  end

  def pull_request = @pull_request ||= PullRequest.new

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
