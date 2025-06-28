# frozen_string_literal: true

require 'test_helper'

require_relative '../../lib/mergeability_monitor'

class MergeabilityTest < Minitest::Test
  def setup
    @original_sha = 'ca8005e'
    @updated_sha = 'c4b0053'

    stub_comment
    stub_git_repo
    stub_pull_request
    stub_queue_state
  end

  def test_check_when_mergeable
    MergeabilityMonitor.check!
  end

  def test_when_pr_has_been_removed_from_queue
    queue_state.stubs(:entry).returns(nil)

    assert_raises MergeabilityMonitor::RemovedFromQueueError do
      MergeabilityMonitor.check!
    end
  end

  def test_when_remote_has_been_updated
    git_repo.stubs(:remote_sha).returns(updated_sha)

    assert_raises MergeabilityMonitor::PrBranchUpdatedError do
      MergeabilityMonitor.check!
    end
  end

  private

  attr_reader :original_sha, :updated_sha

  def stub_queue_state
    QueueState.stubs(:instance).returns(queue_state)
  end

  def queue_state
    @queue_state ||= stub('QueueState').responds_like_instance_of(QueueState).tap do
      it.stubs(:entry).with(pull_request).returns({ 'sha' => original_sha })
    end
  end

  def git_repo
    @git_repo ||= stub(
      'GitRepo',
      remote_sha: original_sha,
    ).responds_like_instance_of(GitRepo)
  end

  def stub_git_repo
    GitRepo.stubs(:find).with('project').returns(git_repo)
  end

  def pull_request
    @pull_request ||= stub('PullRequest').responds_like_instance_of(PullRequest)
  end

  def stub_pull_request
    PullRequest.stubs(:instance).returns(pull_request)
  end

  def stub_comment
    Comment.stubs(:message)
    Comment.stubs(:error)
  end
end
