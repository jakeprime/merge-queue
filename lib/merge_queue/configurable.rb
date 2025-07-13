# frozen_string_literal: true

require_relative './config'

module MergeQueue
  module Configurable
    def self.included(base)
      Config::PARAMS.each do |param|
        base.define_method(param) { merge_queue.config.public_send(param) }
      end
    end
  end
end
