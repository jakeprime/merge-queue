# frozen_string_literal: true

require_relative './merge_queue/merge_queue'

module MergeQueue
  def self.call
    merge_queue = MergeQueue.new.configure do |config|
      config.access_token = ENV['ACCESS_TOKEN']
      config.pr_number = ENV['PR_NUMBER']
      config.project_repo = ENV['GITHUB_REPOSITORY']
      config.run_id = ENV['GITHUB_RUN_ID']
      config.workspace_dir = ENV['GITHUB_WORKSPACE']
    end

    merge_queue.call
  end
end
