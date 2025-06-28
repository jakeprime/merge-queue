# frozen_string_literal: true

require 'test_helper'

require 'dotenv'
require 'vcr'

# These are real values, enabling a proper run through using VCR
env = Dotenv.parse('.env.test')

INTEGRATION_TEST_CONFIG = {
  access_token: env['ACCESS_TOKEN'],
  project_repo: 'jakeprime/merge-queue',
  default_branch: 'integration-test-main',
  pr_number: '1',
}.freeze

VCR.configure do |config|
  config.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<ACCESS_TOKEN>') { Config.access_token }
end

class IntegrationTest < Minitest::Test
  def around
    super do
      INTEGRATION_TEST_CONFIG.each { |k, v| Config.public_send("#{k}=", v) }
      yield
    end
  end
end
