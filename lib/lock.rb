# frozen_string_literal: true

require_relative './git_repo'

class Lock
  CouldNotGetLockError = Class.new(StandardError)

  WAIT_TIME = 60
  POLL_INTERVAL = 5

  def with_lock
    lock!

    yield

    unlock!
  end

  def locked? = lock_cache != nil
  def locked_by_us? = locked? && lock_cache['owner'] == run_id
  def locked_by_other? = locked? && !locked_by_us?

  private

  def lock!
    return increment_lock_count if locked_by_us?

    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      invalidate_cache!
      next sleep(POLL_INTERVAL) if locked_by_other?

      init_lock
      git_repo.push_changes('Creating lock')

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
      git_repo.delete_file('lock')
      git_repo.push_changes('Releasing lock')
      invalidate_cache!
    end
  end

  def init_lock
    @lock_cache = { 'owner' => run_id, 'lockCount' => 1 }
    save!
  end

  def save!
    git_repo.write_file('lock', JSON.pretty_generate(lock_cache))
  end

  def increment_lock_count
    lock_cache['lockCount'] += 1
  end

  def decrement_lock_count
    lock_cache['lockCount'] -= 1
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
