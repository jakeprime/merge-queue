# frozen_string_literal: true

require 'forwardable'

require_relative './configurable'

module MergeQueue
  ###
  # Writes message to the PR as a comment. The initial message is written to a new
  # comment and then all following ones update that one.
  class Comment
    extend Forwardable
    include Configurable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def init(content)
      message(content, init: true)
    end

    def message(content, include_queue: true, init: false, **replacements)
      content = messages[content] if content.is_a?(Symbol)
      replacements.each { |k, v| content = content.gsub("{{#{k}}}", v) }

      content += queue_state.to_table if include_queue && queue_state

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

    def error(content)
      message(content, include_queue: false)
    end

    private

    attr_accessor :comment_id

    def_delegators :@merge_queue, :github, :queue_state

    def messages
      {
        checking_queue: '🧐 Checking current merge queue...',
        ci_failed: <<~MESSAGE,
          😔 CI failed

          It might be us or one of PRs ahead of us in the queue, checking...
        MESSAGE
        ci_passed: '🟢 CI passed...',
        ci_timeout: '💀 Timed out waiting for CI result',
        initializing: '🌱 Initializing merging process...',
        joining_queue: '🦤 🦃 🦆 Joining the queue...',
        merged: '✅ Victory, a successful merge',
        not_mergeable: '✋ Github does not think this PR is mergeable',
        not_rebaseable: <<~MESSAGE,
          ✋ Github does not think this PR is rebaseable

          Try manually rebasing your branch onto main first
        MESSAGE
        pr_update: <<~MESSAGE,
          🙃 The PR has been updated since the merge started

          I’m ejecting, try again whenever you’re ready
        MESSAGE
        ready_to_merge: '🙌 Ready to merge...',
        removed_from_queue:
          '👎 Bad luck, an earlier PR in the queue has failed, please try again',
        queue_timeout: '💀 Timed out waiting to get to the front of the queue',
        waiting_for_ci: '🤞 Waiting on [CI result]({{ci_link}})...',
        waiting_for_queue: '⏳ Waiting to reach the front of the queue...',
      }
    end
  end
end
