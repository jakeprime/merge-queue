# frozen_string_literal: true

require 'forwardable'
require 'json'

require_relative './errors'
require_relative './git_repo'
require_relative './queue_table_renderer'

module MergeQueue
  class QueueState
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def next_branch_counter
      with_lock do
        self.branch_counter += 1
      end
    end

    def latest_merge_branch
      with_lock do
        branch = state['mergeBranches']
          .sort_by { it['count'] }
          .reject { it['status'] == 'failed' }
          .last

        branch ? branch['name'] : default_branch
      end
    end

    def add_branch(pull_request)
      comment.message(:joining_queue)

      with_lock do
        ancestors =
          if pull_request.base_branch == default_branch
            []
          else
            state['mergeBranches']
              .find { it['name'] == pull_request.base_branch }['ancestors']
              .dup
              .push(pull_request.base_branch)
          end

        new_entry = pull_request.as_json.merge(
          'status' => 'pending',
          'ancestors' => ancestors,
        )
        state['mergeBranches'].push(new_entry)
        GithubLogger.debug("Added branch: #{state['mergeBranches']}")
      end
    end

    def update_status(pull_request:, status:)
      with_lock do
        entry(pull_request)['status'] = status
      end
    end

    def remove_branch(pull_request)
      with_lock do
        state['mergeBranches'].reject! do
          it['name'] == pull_request.merge_branch
        end
      end
    end

    def entry(pull_request)
      state['mergeBranches'].find { it['name'] == pull_request.merge_branch }
    end

    def terminate_descendants(pull_request)
      with_lock do
        state['mergeBranches'].reject! do
          it['ancestors'].include?(pull_request.merge_branch)
        end
      end
    end

    def wait_until_front_of_queue(pull_request)
      comment.message(:waiting_for_queue)

      max_polls = (queue_timeout / queue_poll_interval).round
      max_polls.times do
        mergeability_monitor.check!

        first_in_queue = state['mergeBranches'].min_by { it['count'] }
        GithubLogger.info "First in queue is #{first_in_queue['name']}"

        return true if first_in_queue['name'] == pull_request.merge_branch

        sleep(queue_poll_interval)
      end

      comment.error(:queue_timeout)

      raise QueueTimeoutError
    end

    def refresh_state
      git_repo.pull
      @state = nil
    end

    def entries = state['mergeBranches']

    def_delegators :table_renderer, :to_table

    private

    attr_reader :merge_queue

    def_delegators :merge_queue, :comment, :config, :init_git_repo, :lock,
                   :mergeability_monitor
    def_delegators :config, :default_branch, :project_repo, :queue_poll_interval,
                   :queue_timeout

    def branch_counter = state['branchCounter']

    def branch_counter=(value)
      with_lock do
        state['branchCounter'] = value
      end
    end

    def table_renderer = @table_renderer ||= QueueTableRenderer.new(merge_queue)

    def git_repo
      @git_repo ||= init_git_repo(
        'queue_state',
        repo: project_repo,
        branch: 'merge-queue-state',
        create_if_missing: true,
      )
    end

    def state
      (@state ||= JSON.parse(git_repo.read_file('state.json'))).tap do
        GithubLogger.debug("state: #{it}")
      end
    end

    def with_lock
      lock.with_lock do
        @state = nil
        result = yield
        git_repo.write_file('state.json', JSON.pretty_generate(state))

        result
      end
    end
  end
end
