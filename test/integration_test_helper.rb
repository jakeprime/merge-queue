# frozen_string_literal: true

require 'test_helper'

require 'dotenv'
require 'vcr'

# These are real values, enabling a proper run through using VCR
env = Dotenv.parse('.env.test')

VCR.configure do |config|
  config.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<ACCESS_TOKEN>') { env['ACCESS_TOKEN'] }
end

class IntegrationTest < Minitest::Test
  def around
    super do
      INTEGRATION_TEST_CONFIG.each { |k, v| Config.public_send("#{k}=", v) }
      yield
    end
  end

  def env = Dotenv.parse('.env.test')
end
