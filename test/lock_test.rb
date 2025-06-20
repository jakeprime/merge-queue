# frozen_string_literal: true

require 'test_helper'

require 'json'

require_relative '../lib/lock'

class LockTest < Minitest::Test
  def setup
    stub_git_repo
  end

  def around(&)
    # we don't want to be waiting for timeouts in the test suite
    Lock.stub_consts(POLL_INTERVAL: 0.01, WAIT_TIME: 0.03, &)
  end

  def test_lock_status_when_locked_by_us
    git_repo.write_file('lock', locked_by_us_file)

    assert_predicate lock, :locked?
    assert_predicate lock, :locked_by_us?
    refute_predicate lock, :locked_by_other?
  end

  def test_lock_status_when_locked_by_other
    git_repo.write_file('lock', locked_by_other_file)

    assert_predicate lock, :locked?
    refute_predicate lock, :locked_by_us?
    assert_predicate lock, :locked_by_other?
  end

  def test_lock_status_when_not_locked
    refute_predicate lock, :locked?
    refute_predicate lock, :locked_by_us?
    refute_predicate lock, :locked_by_other?
  end

  def test_with_lock_when_not_locked
    git_repo.expects(:push_changes).with('Creating lock')

    lock.with_lock {}
  end

  def test_with_lock_times_out_eventually
    git_repo.write_file('lock', locked_by_other_file)

    assert_raises Lock::CouldNotGetLockError do
      lock.with_lock {}
    end
  end

  def test_with_lock_resets_and_retries_if_push_fails
    git_repo
      .expects(:push_changes).raises(GitRepo::RemoteBeenUpdatedError)
      .then.returns(true)

    git_repo.expects(:reset_to_origin)

    lock.with_lock {}
  end

  def test_with_lock_retries_when_remote_is_updated
    git_repo.stubs(:read_file).with('lock').returns(locked_by_other_file, nil)

    git_repo.expects(:push_changes).with('Creating lock')

    lock.with_lock do
      assert_predicate lock, :locked_by_us?
    end

    refute_predicate lock, :locked?
  end

  def test_nested_locking
    lock.with_lock do
      assert_predicate lock, :locked_by_us?

      lock.with_lock do
        assert_predicate lock, :locked_by_us?
      end
    end

    refute_predicate lock, :locked?
  end

  def test_ensure_released
    git_repo.write_file('lock', locked_by_us_file)

    git_repo.expects(:delete_file).with('lock')
    git_repo.expects(:push_changes)

    lock.ensure_released
  end

  private

  attr_reader :git_repo

  def stub_git_repo
    @git_repo = stub(
      create_branch: true,
      fetch_until_common_commit: true,
      push_changes: true,
    ).responds_like_instance_of(GitRepo)

    def git_repo.delete_file(_file)
      @lock_contents = nil
    end

    def git_repo.read_file(_file) = @lock_contents

    def git_repo.write_file(_file, contents)
      @lock_contents = contents
    end

    GitRepo
      .stubs(:init)
      .with(
        name: 'queue_state',
        repo: PROJECT_REPO,
        branch: 'merge-queue-state',
        create_if_missing: true,
      )
      .returns(git_repo)
  end

  def locked_by_us_file = { owner: RUN_ID, lockCount: 1 }.to_json
  def locked_by_other_file = { owner: 'other', lockCount: 1 }.to_json

  def lock = @lock ||= Lock.new
end
