# frozen_string_literal: true

require_relative './git_repo'
require_relative './github_logger'

class Lock
  CouldNotGetLockError = Class.new(StandardError)

  # WAIT_TIME = 60
  # POLL_INTERVAL = 5
  WAIT_TIME = 10
  POLL_INTERVAL = 2

  def with_lock
    lock!

    yield

    unlock!
  end

  def locked? = lock_cache != nil
  def locked_by_us? = locked? && lock_cache['owner'] == run_id
  def locked_by_other? = locked? && !locked_by_us?

  def ensure_released
    return unless locked_by_us?

    git_repo.delete_file('lock')
    git_repo.push_changes('Releasing lock')
  end

  private

  def lock!
    return increment_lock_count if locked_by_us?

    GithubLogger.info('Attempting to lock')

    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      GithubLogger.debug 'checking lock'

      invalidate_cache!
      next sleep(POLL_INTERVAL) if locked_by_other?

      init_lock

      git_repo.push_changes('Creating lock')

      GithubLogger.info('Locked')

      return true
    rescue GitRepo::RemoteBeenUpdatedError
      git_repo.reset_to_origin
    end

    raise CouldNotGetLockError
  end

  def lock_cache
    return @lock_cache if defined?(@lock_cache)

    json = git_repo.read_file('lock')
    return (@lock_cache = nil) unless json

    @lock_cache = JSON.parse(json)
  end

  def invalidate_cache!
    remove_instance_variable(:@lock_cache) if defined?(@lock_cache)
  end

  def unlock!
    decrement_lock_count

    if lock_cache['lockCount'].positive?
      save!
    else
      GithubLogger.info('Releasing lock')
      git_repo.delete_file('lock')
      git_repo.push_changes('Releasing lock')
      invalidate_cache!
    end
  end

  def init_lock
    GithubLogger.debug 'initing lock'

    @lock_cache = { 'owner' => run_id, 'lockCount' => 1 }
    save!
  end

  def save!
    GithubLogger.debug 'saving lock'
    git_repo.write_file('lock', JSON.pretty_generate(lock_cache))
  end

  def increment_lock_count
    GithubLogger.debug 'incrementing lock count'

    lock_cache['lockCount'] += 1
    save!
  end

  def decrement_lock_count
    GithubLogger.debug 'decrementing lock count'
    lock_cache['lockCount'] -= 1
    save!
  end

  def git_repo
    @git_repo ||= GitRepo.init(
      name: 'queue_state',
      repo: project_repo,
      branch: 'merge-queue-state',
      create_if_missing: true,
    )
  end

  def project_repo = ENV['GITHUB_REPOSITORY']
  def run_id = ENV['GITHUB_RUN_ID']
end
