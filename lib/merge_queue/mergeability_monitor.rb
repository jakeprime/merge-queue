# frozen_string_literal: true

require 'forwardable'

require_relative './errors'
require_relative './github_logger'

module MergeQueue
  class MergeabilityMonitor
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def check!
      queue_state.refresh_state

      raise RemovedFromQueueError if removed_from_queue?
      raise PrBranchUpdatedError if pr_branch_updated?

      return unless user_cancelled?

      comment.error(:user_cancelled)
      raise UserCancelledError
    end

    private

    attr_reader :merge_queue

    def_delegators :merge_queue, :comment, :git_repos, :github, :pull_request,
                   :queue_state

    def pr_branch_updated?
      local = queue_entry['sha']
      remote = git_repos['project'].remote_sha

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

    def user_cancelled?
      comment_id = comment.comment_id
      return unless comment_id

      github.issue_comment_reactions(comment_id).map(&:content).include?('-1')
    end

    def queue_entry = queue_state.entry(pull_request)
  end
end
