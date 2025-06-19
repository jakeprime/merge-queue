# frozen_string_literal: true

require 'json'

require_relative './git_repo'

class QueueState
  QueueTimeoutError = Class.new(StandardError)

  WAIT_TIME = 10 * 60 # 10 minutes
  POLL_INTERVAL = 10 # 10 seconds

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
    merge_branches = state['mergeBranches']
    ancestors = merge_branches
      .find { it['name'] == pull_request.base_branch }['ancestors']
      .dup
      .push(pull_request.base_branch)

    new_entry = pull_request.as_json.merge(status: 'pending', ancestors:)
    merge_branches.push(new_entry)

    write_state
  end

  def entry(pull_request)
    state['mergeBranches'].find { it['name'] == pull_request.branch_name }
  end

  def terminate_descendants(pull_request)
    state['mergeBranches'].reject! do
      it['ancestors'].include?(pull_request.branch_name)
    end

    write_state
  end

  def wait_until_front_of_queue(pull_request)
    max_polls = (WAIT_TIME / POLL_INTERVAL).round
    max_polls.times do
      MergeabilityMonitor.check!

      @state = nil

      first_in_queue = state['mergeBranches'].min_by { it['count'] }
      return true if first_in_queue['name'] == pull_request.branch_name

      sleep(POLL_INTERVAL)
    end

    raise QueueTimeoutError
  end

  private

  def branch_counter = state['branchCounter']

  def branch_counter=(value)
    state['branchCounter'] = value
    write_state
  end

  def write_state
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
    )
  end

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
