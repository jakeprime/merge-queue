# frozen_string_literal: true

require_relative './config'

module Configurable
  def config
    yield Config
    self
  end

  def self.included(base)
    Config::PARAMS.each do |param|
      base.define_method(param) { Config.public_send(param) }
      base.define_singleton_method(param) { Config.public_send(param) }
    end
  end
end
