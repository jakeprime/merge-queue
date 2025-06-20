# frozen_string_literal: true

require 'octokit'

###
# Writes message to the PR as a comment. The initial message is written to a new
# comment and then all following ones update that one.
class Comment
  def self.instance = @instance ||= new

  def self.init(message)
    @instance = nil
    instance.send(:message, message, init: true)
  end

  def self.message(message, **replacements)
    instance.send(:message, message, **replacements)
  end

  private

  attr_accessor :comment_id

  def message(message, init: false, **replacements)
    message = messages[message] if message.is_a?(Symbol)
    replacements.each { |k, v| message.gsub!("{{#{k}}}", v) }

    if init
      result = client.add_comment(project_repo, pr_number, message)
      self.comment_id = result.id
    else
      client.update_comment(project_repo, comment_id, message)
    end
  end

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
      removed_from_queue: '👎 Bad luck, an earlier PR in the queue has failed, please try again',
      queue_timeout: '💀 Timed out waiting to get to the front of the queue',
      waiting_for_ci: '🤞 Waiting on [CI result]({{ci_link}})...',
      waiting_for_queue: '⏳ Waiting to reach the front of the queue...',
    }
  end

  def client = @client ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
