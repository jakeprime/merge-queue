# frozen_string_literal: true

require_relative './comment'
require_relative './github_logger'
require_relative './pull_request'

class MergeQueue
  include Memery

  PrNotMergeableError = Class.new(StandardError)
  PrNotRebaseableError = Class.new(StandardError)

  def call
    create_initial_comment
    ensure_pr_rebaseable!
  end

  private

  def create_initial_comment
    GithubLogger.debug('Creating initial comment')

    Comment.init('🌱 Initialising merging process...')
  end

  def ensure_pr_rebaseable!
    GithubLogger.debug('Checking if PR is rebaseable')

    result = client.pull(project_repo, pr_number)

    raise PrNotMergeableError unless result.mergeable?
    raise PrNotRebaseableError unless result.rebaseable?
  end

  def client = Octokit::Client.new(access_token:)
  memoize :client

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
