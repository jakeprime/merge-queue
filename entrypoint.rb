#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative './lib/merge_queue'

RETRY_ATTEMPTS = 1

merge_queue = MergeQueue.new.config do |config|
  config.access_token = ENV['ACCESS_TOKEN']
  config.pr_number = ENV['PR_NUMBER']
  config.project_repo = ENV['GITHUB_REPOSITORY']
  config.run_id = ENV['GITHUB_RUN_ID']
  config.workspace_dir = ENV['GITHUB_WORKSPACE']
end

RETRY_ATTEMPTS.times do
  merge_queue.call
end
