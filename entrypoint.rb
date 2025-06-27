#!/usr/bin/env ruby

# frozen_string_literal: true

require_relative './lib/merge_queue'

RETRY_ATTEMPTS = 3

RETRY_ATTEMPTS.times do
  MergeQueue.new.call
end
