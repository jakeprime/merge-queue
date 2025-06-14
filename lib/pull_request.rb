# frozen_string_literal: true

require 'octokit'

require_relative './queue_state'

# Represents the pull request we want to merge
class PullRequest
  extend Forwardable

  attr_reader :base_branch, :merge_branch

  def initialize
    @result = octokit.pull(project_repo, pr_number)
  end

  def_delegators :@result, :mergeable?, :rebaseable?, :title

  def branch_name = result.head.ref
  def sha = result.head.sha

  def init_merge_branches
    @base_branch = queue_state.latest_merge_branch || 'main'

    branch_counter = queue_state.branch_counter!
    @merge_branch = "merge-branch/#{title}-#{branch_counter}"
  end

  private

  attr_reader :result

  def queue_state = @queue_state ||= QueueState.new

  def octokit = @octokit ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
