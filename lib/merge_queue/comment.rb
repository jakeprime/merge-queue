# frozen_string_literal: true

require 'forwardable'

module MergeQueue
  ###
  # Writes message to the PR as a comment. The initial message is written to a new
  # comment and then all following ones update that one.
  class Comment
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def init(content)
      message(content, init: true)
    end

    def message(content, error = nil, include_queue: true, init: false, **replacements)
      content = messages[content] if content.is_a?(Symbol)
      replacements.each { |k, v| content = content.gsub("{{#{k}}}", v) }

      content += queue_state.to_table if include_queue && queue_state
      content += "\n\n```\n#{error}\n```" if error

      GithubLogger.debug("\n--------------------------------------------------")
      GithubLogger.debug(content)
      GithubLogger.debug("--------------------------------------------------\n\n")

      if init
        result = github.add_comment(pr_number, content)
        self.comment_id = result.id
      else
        github.update_comment(comment_id, content)
      end
    rescue StandardError => e
      # we don't want a failure to write a comment to blow up the process,
      # particularly as we make a comment in the teardown
      GithubLogger.error("Failed to write comment - #{e.full_message}")
    end

    def error(content, error = nil)
      message(content, error, include_queue: false)
    end

    private

    attr_reader :merge_queue
    attr_accessor :comment_id

    def_delegators :merge_queue, :ci, :config, :github, :queue_state
    def_delegators :ci, :ci_link
    def_delegators :config, :default_branch, :pr_number

    def messages
      {
        checking_queue: '🧐 Checking current merge queue...',
        ci_failed: <<~MESSAGE,
          😔 CI failed

          It might be us or one of PRs ahead of us in the queue, checking...
        MESSAGE
        ci_passed: '🟢 CI passed...',
        ci_timeout: '💀 Timed out waiting for CI result',
        failed_ci: <<~MESSAGE,
          🔴 We’ve [failed CI](#{ci_link}) and cannot merge

          Try rebasing onto main and seeing if you have any test failures
        MESSAGE
        generic_error: '💣 Something went wrong that I don’t know how to handle',
        initializing: '🌱 Initializing merging process...',
        joining_queue: '🦤 🦃 🦆 Joining the queue...',
        merge_failed: "💣 The attempted merge to `#{default_branch}` was rejected",
        merged: '✅ Successfully merged',
        not_mergeable: <<~MESSAGE,
          ✋ Github does not think this PR is mergeable

          Make sure that all checks are passing and try again
        MESSAGE
        not_rebaseable: <<~MESSAGE,
          ✋ Github does not think this PR is rebaseable

          Try manually rebasing your branch onto main first
        MESSAGE
        pr_update: <<~MESSAGE,
          🙃 The PR has been updated since the merge started

          I’m ejecting, try again when you’re ready to merge again
        MESSAGE
        ready_to_merge: '🙌 Ready to merge...',
        removed_from_queue:
          '👎 Bad luck, an earlier PR in the queue has failed, please try again',
        queue_timeout: '💀 Timed out waiting to get to the front of the queue',
        waiting_for_ci: "🤞 Waiting on [CI result](#{ci_link})...",
        waiting_for_queue: '⏳ Waiting to reach the front of the queue...',
      }
    end
  end
end
