# frozen_string_literal: true

# Represents the pull request we want to merge
class PullRequest
  extend Forwardable
  include Memery

  def initialize
    @result = octokit.pull(project_repo, pr_number)
  end

  def_delegators :@result, :mergeable?, :rebaseable?, :title

  def branch_name = result.head.ref
  def sha = result.head.sha

  private

  attr_reader :result

  def octokit = Octokit::Client.new(access_token:)
  memoize :octokit

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
