# frozen_string_literal: true

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
    queue_entry['sha'] != GitRepo.find('queue_state').remote_sha
  end

  def removed_from_queue?
    queue_entry.nil?
  end

  def queue_entry = @queue_entry = queue_state.entry(pull_request)

  def queue_state = @queue_state ||= QueueState.new
  def pull_request = @pull_request ||= PullRequest.instance
end
