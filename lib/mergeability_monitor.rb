# frozen_string_literal: true

require_relative './github_logger'
require_relative './pull_request'

class MergeabilityMonitor
  PrBranchUpdatedError = Class.new(StandardError)
  RemovedFromQueueError = Class.new(StandardError)

  def self.check!
    new.check!
  end

  def check!
    raise RemovedFromQueueError if removed_from_queue?
    raise PrBranchUpdatedError if pr_branch_updated?
  end

  private

  def pr_branch_updated?
    local = queue_entry['sha']
    remote = GitRepo.find('project').remote_sha

    if remote == local
      false
    else
      GithubLogger.error 'PR has been updated'
      true
    end
  end

  def removed_from_queue?
    if queue_entry.nil?
      GithubLogger.error 'Removed from queue'
      true
    else
      false
    end
  end

  def queue_entry = @queue_entry = queue_state.entry(pull_request)

  def queue_state = @queue_state ||= QueueState.new
  def pull_request = @pull_request ||= PullRequest.instance
end
