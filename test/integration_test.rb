# frozen_string_literal: true

require 'integration_test_helper'

require_relative '../lib/merge_queue'

class IntegrationTest < Minitest::Test
  def around
    unless WORKSPACE_DIR.split('/').include?('tmp')
      raise 'WORKSPACE_DIR value must have `tmp` in its path'
    end

    FileUtils.rm_rf(WORKSPACE_DIR)
    VCR.use_cassette("#{self.class.name}/#{name}") do
      super
    end
  end

  def test_successful_merge
    assert pr_open?

    merge_queue = MergeQueue.new.config do |c|
      c.access_token = access_token
      c.project_repo = project_repo
      c.default_branch = default_branch
      c.pr_number = pr_number
    end

    merge_queue.call

    assert pr_merged?
  end

  private

  def access_token = env['ACCESS_TOKEN']
  def project_repo = 'jakeprime/merge-queue'
  def default_branch = 'integration-test-main'
  def pr_number = '1'

  def octokit = @octokit ||= Octokit::Client.new(access_token:)

  def pr_open?
    pull_request = octokit.pull(project_repo, pr_number)
    pull_request.state == 'open'
  end

  def pr_merged?
    pull_request = octokit.pull(project_repo, pr_number)
    pull_request.merged?
  end
end
