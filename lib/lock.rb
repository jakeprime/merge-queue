# frozen_string_literal: true

require_relative './git_repo'

class Lock
  CouldNotGetLockError = Class.new(StandardError)

  WAIT_TIME = 60
  POLL_INTERVAL = 5

  def with_lock
    get_lock

    yield

    release_lock
  end

  def locked? = lock_state != nil
  def locked_by_us? = locked? && lock_state['owner'] == run_id
  def locked_by_other? = locked? && !locked_by_us?

  private

  def get_lock
    # TODO: implement semaphore lock counting
    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      next sleep(POLL_INTERVAL) if locked_by_other?

      create_lock
      git_repo.push_changes('Creating lock')

      return true
    rescue GitRepo::RemoteBeenUpdatedError
      git_repo.reset_to_origin
    end

    raise CouldNotGetLockError
  end

  def lock_state
    json = git_repo.read_file('lock')
    return unless json

    JSON.parse(json)
  end

  def release_lock
    # TODO: implement semaphore lock counting
    git_repo.delete_file('lock')
    git_repo.push_changes('Releasing lock')
  end

  def create_lock
    git_repo.write_file(
      'lock',
      JSON.pretty_generate({ owner: run_id, lockCount: 1 }),
    )
  end

  def git_repo
    @git_repo ||= GitRepo.init(
      name: 'queue_state',
      repo: project_repo,
      branch: 'merge-queue-state',
    )
  end

  def project_repo = ENV['GITHUB_REPOSITORY']
  def run_id = ENV['GITHUB_RUN_ID']
end
