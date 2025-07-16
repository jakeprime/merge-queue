# frozen_string_literal: true

require 'forwardable'

require_relative './errors'
require_relative './git_repo'
require_relative './github_logger'

module MergeQueue
  class Lock
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue

      self.lock_counter = 0
    end

    def with_lock
      lock!
      result = yield
      unlock!

      result
    end

    def ensure_released
      return unless locked_by_us?

      git_repo.delete_file('lock')
      git_repo.push_changes("Releasing lock for action #{run_id} [skip ci]")
    end

    private

    attr_reader :merge_queue
    attr_accessor :lock_counter

    def_delegators :merge_queue, :config, :init_git_repo
    def_delegators :config, :lock_poll_interval, :lock_timeout, :project_repo, :run_id

    def locked_by_us? = lock_counter.positive?

    def locked_by_other?
      return false if locked_by_us?

      lock_file = git_repo.read_file('lock')
      return false if lock_file.nil?
      return false if lock_file == run_id

      true
    end

    def lock!
      return increment_lock_count if locked_by_us?

      GithubLogger.info('Attempting to lock')

      max_polls = (lock_timeout / lock_poll_interval).round
      max_polls.times do
        GithubLogger.debug("Checking lock (#{run_id} - #{lock_counter})")
        git_repo.pull

        next sleep(lock_poll_interval) if locked_by_other?

        init_lock

        GithubLogger.info('Locked')

        return true
      rescue RemoteUpdatedError
        git_repo.reset_to_origin
      end
      raise CouldNotGetLockError
    end

    def decrement_lock_count
      GithubLogger.debug 'decrementing lock count'

      self.lock_counter -= 1
    end

    def increment_lock_count
      GithubLogger.debug 'incrementing lock count'

      self.lock_counter += 1
    end

    def init_lock
      GithubLogger.debug 'initing lock'
      git_repo.write_file('lock', run_id)
      git_repo.push_changes("Creating lock for action #{run_id} [skip ci]")

      increment_lock_count
    end

    def unlock!
      decrement_lock_count
      GithubLogger.debug("unlocking - #{lock_counter}")

      return if locked_by_us?

      GithubLogger.info('Releasing lock')
      git_repo.delete_file('lock')
      git_repo.push_changes("Releasing lock for action #{run_id} [skip ci]")
    end

    def git_repo
      @git_repo ||= init_git_repo(
        'queue_state',
        repo: project_repo,
        branch: 'merge-queue-state',
        create_if_missing: true,
      )
    end
  end
end
