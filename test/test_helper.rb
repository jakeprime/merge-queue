# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/around/unit'
require 'minitest/rg'
require 'minitest/stub_const'
require 'mocha/minitest'
require 'webmock/minitest'

require_relative '../lib/config'

ENV['ENVIRONMENT'] = 'test'

# Config values can be used anywhere, so we'll set them to constants here for
# all tests
DEFAULT_CONFIG = {
  access_token: ACCESS_TOKEN = 'ghp_cross_my_heart_hope_to_die',
  default_branch: DEFAULT_BRANCH = 'main',
  pr_number: PR_NUMBER = '123',
  project_repo: PROJECT_REPO = 'jakeprime/skynet',
  run_id: RUN_ID = '654321',
  workspace_dir: WORKSPACE_DIR = '/tmp/merge-queue',
}.freeze

WebMock.disable_net_connect!

module Minitest
  class Test
    def around
      DEFAULT_CONFIG.each { |k, v| Config.public_send("#{k}=", v) }

      yield
    end
  end
end
