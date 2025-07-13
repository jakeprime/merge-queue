# frozen_string_literal: true

require_relative './merge_queue/merge_queue'

module MergeQueue
  def self.call(params = {})
    config = Config.new(**params)

    retry_attempts = ENV.fetch('RETRY_ATTEMPTS', 3)

    retry_attempts.times do
      merge_queue = MergeQueue.new(config)
      merge_queue.call
      break
    rescue RetriableError
      # Try the whole process again
    end
  end
end
