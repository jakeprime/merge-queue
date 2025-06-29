# frozen_string_literal: true

require 'forwardable'

require_relative './github_logger'

class MergeabilityMonitor
  extend Forwardable

  PrBranchUpdatedError = Class.new(StandardError)
  RemovedFromQueueError = Class.new(StandardError)

  def initialize(merge_queue)
    @merge_queue = merge_queue
  end

  def check!
    raise RemovedFromQueueError if removed_from_queue?
    raise PrBranchUpdatedError if pr_branch_updated?
  end

  private

  def_delegators :@merge_queue, :comment, :pull_request, :queue_state

  def pr_branch_updated?
    local = queue_entry['sha']
    remote = GitRepo.find('project').remote_sha

    if remote == local
      false
    else
      comment.message(:pr_updated)
      GithubLogger.error 'PR has been updated'
      true
    end
  end

  def removed_from_queue?
    if queue_entry.nil?
      comment.error(:removed_from_queue)
      GithubLogger.error 'Removed from queue'
      true
    else
      false
    end
  end

  def queue_entry = @queue_entry = queue_state.entry(pull_request)
end
