# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/minitest'

ENV['ENVIRONMENT'] = 'test'

# Env vars can be used anywhere, so we'll set them to constants here for all
# tests
ENV['ACCESS_TOKEN'] = ACCESS_TOKEN = 'ghp_cross_my_heart_hope_to_die'
ENV['PR_NUMBER'] = PR_NUMBER = '123'
ENV['GITHUB_REPOSITORY'] = PROJECT_REPO = 'jakeprime/skynet'
ENV['GITHUB_WORKSPACE'] = WORKSPACE_DIR = '/tmp/merge-queue'

def mock(**)
  Minitest::Mock.new(**)
end
