# frozen_string_literal: true

require 'test_helper'

require_relative '../../../lib/merge_queue/errors'
require_relative '../../../lib/merge_queue/mergeability_monitor'

module MergeQueue
  class MergeabilityMonitorTest < Minitest::Test
    def setup
      @original_sha = 'ca8005e'
      @updated_sha = 'c4b0053'

      stub_merge_queue(:comment, :pull_request, :queue_state)
      stub_git_repo

      @mergeability_monitor = MergeabilityMonitor.new(merge_queue)
    end

    def test_no_error_when_mergeable
      queue_state.stubs(:entry).returns({ 'sha' => original_sha })
      mergeability_monitor.check!
    end

    def test_when_pr_has_been_removed_from_queue
      queue_state.stubs(:entry).returns(nil)

      assert_raises ::MergeQueue::RemovedFromQueueError do
        mergeability_monitor.check!
      end
    end

    def test_when_remote_has_been_updated
      queue_state.stubs(:entry).returns({ 'sha' => original_sha })
      git_repo.stubs(:remote_sha).returns(updated_sha)

      assert_raises ::MergeQueue::PrBranchUpdatedError do
        mergeability_monitor.check!
      end
    end

    private

    attr_reader :original_sha, :updated_sha

    def git_repo
      @git_repo ||= stub(
        'GitRepo',
        remote_sha: original_sha,
      ).responds_like_instance_of(GitRepo)
    end

    def stub_git_repo
      GitRepo.stubs(:find).with('project').returns(git_repo)
    end
  end
end
