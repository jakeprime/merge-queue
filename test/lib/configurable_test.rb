# frozen_string_literal: true

require 'test_helper'

require_relative '../../lib/configurable'

class ConfigurableTest < Minitest::Test
  class DummyClass
    include Configurable
  end

  def test_setting_config
    DummyClass.new.config do |config|
      config.access_token = 'access_token'
    end

    assert_equal 'access_token', Config.access_token
  end

  def test_config_accessors
    Config.access_token = 'access_token'

    assert_equal 'access_token', DummyClass.new.access_token
  end

  def test_config_class_accessors
    Config.access_token = 'access_token'

    assert_equal 'access_token', DummyClass.access_token
  end
end
