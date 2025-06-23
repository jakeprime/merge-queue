# frozen_string_literal: true

class QueueTableRenderer
  def initialize
    [header, rows].join("\n")
  end

  private

  def header = <<~HEADER
    ### Your place in the queue:

    Position | Status | PR | CI Branch
    :---: | :---: | :--- | :---
  HEADER

  def rows
    queue_state.entries.each_with_index do |entry, index|
      [
        position == our_position?(entry) ? '🫵' : index,
        status(entry),
        pr_link(entry),
        ci_link(entry),
      ].join(' | ')
    end
  end

  def status(entry)
    {
      Ci::SUCCESS => '🟢',
      Ci::FAILURE => '🟡',
      Ci::PENDING => '🔴',
    }.fetch(entry['status'])
  end

  def our_position(entry)
    entry['name'] == pull_request.merge_branch
  end

  def pr_link(entry)
    # redirect.github creates a link without a backlink
    "[#{entry['title']}](https://redirect.github.com/#{project_repo}/pull/#{entry['pr_number']})"
  end

  def ci_link(entry)
    "[#{entry['pr_branch']}](https://app.circleci.com/pipelines/github/#{project_repo}?branch=#{entry['name']}"
  end

  def queue_state = @queue_state ||= QueueState.new
  def pull_request = @pull_request ||= PullRequest.instance

  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
