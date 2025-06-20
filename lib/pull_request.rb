# frozen_string_literal: true

require 'octokit'

require_relative './git_repo'
require_relative './lock'
require_relative './queue_state'

# Represents the pull request we want to merge
class PullRequest
  extend Forwardable

  attr_reader :merge_sha

  def_delegators :github, :mergeable?, :rebaseable?, :title

  def branch_name = github.head.ref
  def sha = github.head.sha

  def base_branch
    @base_branch ||= begin
      ensure_lock!
      queue_state.latest_merge_branch
    end
  end

  def create_merge_branch
    with_lock do
      git_repo.fetch_until_common_commit('main')
      @merge_sha = git_repo.create_branch(
        merge_branch,
        from: branch_name,
        rebase_onto: queue_state.latest_merge_branch,
      )
      queue_state.add_branch(self)
    end
  end

  def merge!
    # TODO: ensure branch has not been updated
    git_repo.merge_to_main!(branch_name)
  end

  def as_json
    {
      name: merge_branch,
      title:,
      pr_number:,
      sha:,
      count: branch_counter,
    }
  end

  private

  attr_reader :result

  # temporary stub lock method
  def ensure_lock! = true

  def branch_counter
    @branch_counter ||= begin
      ensure_lock!
      queue_state.next_branch_counter
    end
  end

  def merge_branch = @merge_branch ||= "merge-branch/#{branch_name}-#{branch_counter}"

  def queue_state = @queue_state ||= QueueState.new

  def git_repo
    @git_repo ||= GitRepo.init(
      name: 'project',
      repo: project_repo,
      branch: branch_name,
    )
  end

  def github = @github ||= octokit.pull(project_repo, pr_number)

  def lock = @lock ||= Lock.new
  def_delegators :lock, :with_lock

  def octokit = @octokit ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
