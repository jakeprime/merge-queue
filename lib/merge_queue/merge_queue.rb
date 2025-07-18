# frozen_string_literal: true

require 'forwardable'

require_relative './ci'
require_relative './comment'
require_relative './config'
require_relative './errors'
require_relative './github'
require_relative './github_logger'
require_relative './lock'
require_relative './mergeability_monitor'
require_relative './pull_request'
require_relative './queue_state'

# Main class running the merging process
module MergeQueue
  class MergeQueue
    extend Forwardable

    def initialize(config)
      @config = config
    end

    attr_reader :config

    # Accessors for all the objects we're going to need. These will act as global
    # accessors ensuring that we have a single instance of them that can maintain
    # state.
    def ci = @ci ||= Ci.new(self)
    def comment = @comment ||= Comment.new(self)
    def git_repos = @git_repos ||= {}
    def github = @github ||= Github.new(self)
    def lock = @lock ||= Lock.new(self)
    def mergeability_monitor = @mergeability_monitor ||= MergeabilityMonitor.new(self)
    def pull_request = @pull_request ||= PullRequest.new(self)
    def queue_state = @queue_state ||= QueueState.new(self)

    def call
      comment.init(:initializing)

      ensure_pr_rebaseable

      create_merge_branch

      handle_ci_result

      wait_until_front_of_queue

      if ci_result == Ci::SUCCESS
        merge!
      else
        comment.error(:failed_ci)
        raise CiFailedError
      end
    rescue ::MergeQueue::Error
      # these should all be handled already with appropriate commenting
      raise
    rescue StandardError => e
      # Whatever has gone wrong here it's not something we've foreseen
      GithubLogger.error("#{e} - #{e.message}")
      GithubLogger.error('Something has gone wrong, cleaning up before exiting')
      comment.error(:generic_error, "#{e}\n#{e.message}")

      queue_state.terminate_descendants(pull_request)

      raise
    ensure
      teardown
    end

    def init_git_repo(name, **)
      # make sure we don't initialize a repo twice
      if git_repos[name].nil?
        git_repo = GitRepo.new(self, name, **)
        git_repos[name] = git_repo
      end
      git_repos[name]
    end

    private

    def ensure_pr_rebaseable
      GithubLogger.debug('Checking if PR is rebaseable')

      if pull_request.blocked?
        comment.error(:not_mergeable)
        raise PrNotMergeableError
      end

      if !pull_request.rebaseable?
        comment.error(:not_rebaseable)
        raise PrNotRebaseableError
      end

      true
    end

    def create_merge_branch
      GithubLogger.debug('Creating merge branch')
      comment.message(:checking_queue)

      pull_request.create_merge_branch
    end

    def ci_result
      @ci_result ||= ci.result
    end

    def handle_ci_result
      result = ci_result

      with_lock do
        # check that we are still mergeable before proceeding
        mergeability_monitor.check!

        queue_state.update_status(pull_request:, status: result)
        terminate_descendants if ci_result == Ci::FAILURE
      end
    end

    def terminate_descendants
      queue_state.terminate_descendants(pull_request)
    end

    def wait_until_front_of_queue
      queue_state.wait_until_front_of_queue(pull_request)
    end

    def merge!
      comment.message(:ready_to_merge, include_queue: false)
      pull_request.merge!
      comment.message(:merged, include_queue: false)
    end

    def teardown
      with_lock do
        pull_request.delete_remote_branch
        queue_state.remove_branch(pull_request)
      end
      lock.ensure_released
    end

    def_delegators :lock, :with_lock
  end
end
