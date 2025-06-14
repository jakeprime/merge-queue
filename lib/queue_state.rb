# frozen_string_literal: true

class QueueState
  def initialize
    load_state
  end

  attr_reader :latest_merge_branch

  def branch_counter!
    @branch_counter += 1
  end

  private

  attr_reader :state

  def load_state
    @state = JSON.parse(git.read_file('state.json'))

    @branch_counter = state['branchCounter']

    @latest_merge_branch = find_latest_merge_branch || 'main'
  end

  def find_latest_merge_branch
    branch = state['mergeBranches']
      .sort_by { it['count'] }
      .reject { it['status'] == 'failed' }
      .last

    branch ? branch['name'] : nil
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
