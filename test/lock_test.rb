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
    git_repo.stubs(:read_file).with('lock').returns({ owner: RUN_ID }.to_json)

    assert_predicate lock, :locked?
    assert_predicate lock, :locked_by_us?
    refute_predicate lock, :locked_by_other?
  end

  def test_lock_status_when_locked_by_other
    git_repo.stubs(:read_file).with('lock').returns({ owner: 'other' }.to_json)

    assert_predicate lock, :locked?
    refute_predicate lock, :locked_by_us?
    assert_predicate lock, :locked_by_other?
  end

  def test_lock_status_when_not_locked
    git_repo.stubs(:read_file).with('lock').returns(nil)

    refute_predicate lock, :locked?
    refute_predicate lock, :locked_by_us?
    refute_predicate lock, :locked_by_other?
  end

  def test_with_lock_when_not_locked
    lock.stubs(:locked?).returns(false)

    git_repo.expects(:write_file).with do |file, json|
      assert_equal 'lock', file
      assert_equal RUN_ID, JSON.parse(json)['owner']
      assert_equal 1, JSON.parse(json)['lockCount']
    end
    git_repo.expects(:push_changes).with('Creating lock')

    lock.with_lock {}
  end

  def test_with_lock_times_out_eventually
    lock.stubs(:locked_by_other?).returns(true)

    assert_raises Lock::CouldNotGetLockError do
      lock.with_lock {}
    end
  end

  def test_with_lock_resets_and_retries_if_push_fails
    lock.stubs(:locked_by_other?).returns(false)
    git_repo
      .expects(:push_changes).raises(GitRepo::RemoteBeenUpdatedError)
      .then.returns(true)

    git_repo.expects(:reset_to_origin)

    lock.with_lock {}
  end

  def test_with_lock_retries_when_remote_is_updated
    lock.stubs(:locked_by_other?).returns(true, false)

    git_repo.expects(:push_changes).with('Creating lock')

    lock.with_lock {}
  end

  private

  attr_reader :git_repo

  def stub_git_repo
    @git_repo = stub(
      create_branch: true,
      delete_file: true,
      fetch_until_common_commit: true,
      push_changes: true,
      write_file: true,
    )
      .responds_like_instance_of(GitRepo)
    GitRepo
      .stubs(:init)
      .with(name: 'queue_state', repo: PROJECT_REPO, branch: 'merge-queue-state')
      .returns(git_repo)
  end

  def lock = @lock ||= Lock.new
end
