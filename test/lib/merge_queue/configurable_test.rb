# frozen_string_literal: true

require 'unit_test_helper'

require_relative '../../../lib/merge_queue/configurable'

module MergeQueue
  class ConfigurableTest < UnitTest
    class DummyClass
      include Configurable
    end

    def test_setting_config
      DummyClass.new.configure do |config|
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
end
