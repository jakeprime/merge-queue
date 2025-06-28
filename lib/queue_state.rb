# frozen_string_literal: true

require 'forwardable'
require 'json'

require_relative './comment'
require_relative './configurable'
require_relative './git_repo'
require_relative './lock'

class QueueState
  extend Forwardable
  include Configurable

  QueueTimeoutError = Class.new(StandardError)

  WAIT_TIME = 10 * 60 # 10 minutes
  POLL_INTERVAL = 10 # 10 seconds

  def self.instance = @instance ||= new

  def initialize
    Comment.instance.queue_state = self
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
    Comment.message(:joining_queue)

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
      GithubLogger.debug("Added branch: #{state}")
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
    Comment.message(:waiting_for_queue)

    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      refresh_state

      MergeabilityMonitor.check!

      first_in_queue = state['mergeBranches'].min_by { it['count'] }
      GithubLogger.info "First in queue is #{first_in_queue['name']}"

      return true if first_in_queue['name'] == pull_request.merge_branch

      sleep(POLL_INTERVAL)
    end

    Comment.error(:queue_timeout)

    raise QueueTimeoutError
  end

  def refresh_state
    git_repo.pull
    @state = nil
  end

  def entries = state['mergeBranches']

  def to_table
    QueueTableRenderer.new.to_table
  end

  private

  def branch_counter = state['branchCounter']

  def branch_counter=(value)
    with_lock do
      state['branchCounter'] = value
    end
  end

  def git_repo
    @git_repo ||= GitRepo.init(
      name: 'queue_state',
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

  def lock = @lock ||= Lock.instance
end
