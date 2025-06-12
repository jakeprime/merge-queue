# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/minitest'

require_relative '../lib/merge_queue'

ENV['ENVIRONMENT'] = 'test'

# Env vars can be used anywhere, so we'll set them to constants here for all
# tests
ENV['ACCESS_TOKEN'] = ACCESS_TOKEN = 'ghp_cross_my_heart_hope_to_die'
ENV['PR_NUMBER'] = PR_NUMBER = '123'
ENV['GITHUB_REPOSITORY'] = PROJECT_REPO = 'jakeprime/skynet'

def mock(**)
  Minitest::Mock.new(**)
end
