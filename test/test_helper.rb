# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/around/unit'
require 'minitest/rg'
require 'minitest/stub_const'
require 'mocha/minitest'
require 'webmock/minitest'

ENV['ENVIRONMENT'] = 'test'

WebMock.disable_net_connect!
