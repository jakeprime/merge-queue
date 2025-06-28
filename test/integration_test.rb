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

  def env = Dotenv.parse('.env.test')

  def test_successful_merge
    merge_queue = MergeQueue.new.config do |c|
      c.access_token = env['ACCESS_TOKEN']
      c.project_repo = 'jakeprime/merge-queue'
      c.default_branch = 'integration-test-main'
      c.pr_number = '1'
    end

    merge_queue.call
  end
end
