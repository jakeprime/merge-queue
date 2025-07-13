# frozen_string_literal: true

require 'unit_test_helper'

require 'json'

require_relative '../../../lib/merge_queue/errors'
require_relative '../../../lib/merge_queue/lock'

module MergeQueue
  class LockTest < UnitTest
    def setup
      stub_merge_queue
      stub_git_repo

      # we don't want to be waiting for timeouts in the test suite
      merge_queue.config.lock_poll_interval = 0.01
      merge_queue.config.lock_timeout = 0.03
    end

    def test_with_lock_when_not_locked
      git_repo.expects(:push_changes)

      lock.with_lock {}
    end

    def test_with_lock_times_out_eventually
      git_repo.write_file('lock', locked_by_other_file)

      assert_raises ::MergeQueue::CouldNotGetLockError do
        lock.with_lock {}
      end
    end

    def test_with_lock_resets_and_retries_if_push_fails
      git_repo
        .expects(:push_changes)
        .raises(::MergeQueue::RemoteUpdatedError)
        .then.returns(true)

      git_repo.expects(:reset_to_origin)

      lock.with_lock {}
    end

    def test_with_lock_retries_when_remote_is_updated
      git_repo.expects(:read_file)
        .returns(locked_by_other_file)
        .then.returns(nil).at_least_once.at_least_once

      git_repo.expects(:push_changes)

      lock.with_lock {}
    end

    def test_nested_locking
      lock.with_lock do
        lock.with_lock {}
        assert_equal locked_by_us_file, git_repo.read_file('lock')
      end

      assert_nil git_repo.read_file('lock')
    end

    def test_ensure_released
      git_repo.write_file('lock', locked_by_us_file)

      git_repo.expects(:delete_file).with('lock').at_least_once
      git_repo.expects(:push_changes).at_least_once

      lock.with_lock do
        lock.ensure_released
      end
    end

    private

    attr_reader :git_repo

    def stub_git_repo
      @git_repo = stub(
        'GitRepo',
        create_branch: true,
        pull: true,
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

      merge_queue
        .stubs(:init_git_repo)
        .with(
          'queue_state',
          repo: PROJECT_REPO,
          branch: 'merge-queue-state',
          create_if_missing: true,
        )
        .returns(git_repo)
    end

    def locked_by_us_file = RUN_ID
    def locked_by_other_file = 'other'

    def lock = @lock ||= Lock.new(merge_queue)
  end
end
