# frozen_string_literal: true

require 'json'

require_relative './comment'
require_relative './git_repo'

class QueueState
  QueueTimeoutError = Class.new(StandardError)

  WAIT_TIME = 10 * 60 # 10 minutes
  POLL_INTERVAL = 10 # 10 seconds

  def self.instance = @instance ||= new

  def next_branch_counter
    self.branch_counter += 1
  end

  def latest_merge_branch
    branch = state['mergeBranches']
      .sort_by { it['count'] }
      .reject { it['status'] == 'failed' }
      .last

    branch ? branch['name'] : 'main'
  end

  def add_branch(pull_request)
    Comment.message(:joining_queue)

    merge_branches = state['mergeBranches']

    ancestors =
      if pull_request.base_branch == 'main'
        []
      else
        merge_branches
          .find { it['name'] == pull_request.base_branch }['ancestors']
          .dup
          .push(pull_request.base_branch)
      end

    new_entry = pull_request.as_json.merge(
      'status' => 'pending',
      'ancestors' => ancestors,
    )
    merge_branches.push(new_entry)

    write_state
  end

  def update_status(pull_request:, status:)
    entry(pull_request)['status'] = status

    write_state
  end

  def remove_branch(pull_request)
    state['mergeBranches'].reject! do
      it['name'] == pull_request.merge_branch
    end

    write_state
  end

  def entry(pull_request)
    state['mergeBranches'].find { it['name'] == pull_request.merge_branch }
  end

  def terminate_descendants(pull_request)
    state['mergeBranches'].reject! do
      it['ancestors'].include?(pull_request.merge_branch)
    end

    write_state
  end

  def wait_until_front_of_queue(pull_request)
    Comment.message(:waiting_for_queue)

    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      MergeabilityMonitor.check!

      @state = nil

      first_in_queue = state['mergeBranches'].min_by { it['count'] }
      GithubLogger.info "First in queue is #{first_in_queue['name']}"

      return true if first_in_queue['name'] == pull_request.merge_branch

      sleep(POLL_INTERVAL)
    end

    Comment.error(:queue_timeout)

    raise QueueTimeoutError
  end

  def entries = state['mergeBranches']

  def to_table
    QueueTableRenderer.new.to_table
  end

  private

  def branch_counter = state['branchCounter']

  def branch_counter=(value)
    state['branchCounter'] = value
    write_state
  end

  def write_state
    GithubLogger.debug("Writing state: #{state}")
    git_repo.write_file('state.json', JSON.pretty_generate(state))
  end

  def state
    @state ||= JSON.parse(git_repo.read_file('state.json'))
  end

  def git_repo
    @git_repo ||= GitRepo.init(
      name: 'queue_state',
      repo: project_repo,
      branch: 'merge-queue-state',
      create_if_missing: true,
    )
  end

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
