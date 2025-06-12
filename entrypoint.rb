#!/usr/bin/env ruby

puts 'Running merge queue'

require_relative './lib/merge_queue'

MergeQueue.new.call
