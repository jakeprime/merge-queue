# frozen_string_literal: true

require_relative './merge_queue/merge_queue'

module MergeQueue
  def self.call(config = {})
    retry_attempts = ENV.fetch('RETRY_ATTEMPTS', 3)

    retry_attempts.times do
      merge_queue = MergeQueue.new.configure do |c|
        c.access_token = config.fetch(:access_token, ENV['ACCESS_TOKEN'])
        c.ci_poll_interval = config.fetch(:ci_poll_interval, ENV['CI_POLL_INTERVAL'].to_f)
        c.ci_wait_time = config.fetch(:ci_wait_time, ENV['CI_TIMEOUT'].to_f)
        c.lock_poll_interval = config.fetch(
          :lock_poll_interval, ENV['LOCK_POLL_INTERVAL'].to_f,
        )
        c.lock_wait_time = config.fetch(:lock_wait_time, ENV['LOCK_TIMEOUT'].to_f)
        c.pr_number = config.fetch(:pr_number, ENV['PR_NUMBER'])
        c.project_repo = config.fetch(:project_repo, ENV['GITHUB_REPOSITORY'])
        c.run_id = config.fetch(:run_id, ENV['GITHUB_RUN_ID'])
        c.workspace_dir = config.fetch(:workspace_dir, ENV['GITHUB_WORKSPACE'])
      end

      merge_queue.call
      break
    rescue RetriableError
      # Try the whole process again
    end
  end
end
