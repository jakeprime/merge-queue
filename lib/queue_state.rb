# frozen_string_literal: true

require 'json'

require_relative './git_repo'

class QueueState
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

  private

  def branch_counter = state['branchCounter']

  def branch_counter=(value)
    state['branchCounter'] = value
    write_state
  end

  def write_state
    git.write_file('state.json', JSON.pretty_generate(state))
  end

  def state
    @state ||= JSON.parse(git.read_file('state.json'))
  end

  def git
    @git ||= GitRepo.init(
      name: 'queue_state',
      repo: project_repo,
      branch: 'merge-queue-state',
    )
  end

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
