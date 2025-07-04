# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/around/unit'
require 'minitest/rg'
require 'minitest/stub_const'
require 'mocha/minitest'
require 'webmock/minitest'

require_relative '../lib/ci'
require_relative '../lib/comment'
require_relative '../lib/config'
require_relative '../lib/lock'
require_relative '../lib/merge_queue'
require_relative '../lib/mergeability_monitor'
require_relative '../lib/pull_request'
require_relative '../lib/queue_state'

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

    attr_accessor :ci, :comment, :lock, :merge_queue, :mergeability_monitor,
                  :pull_request, :queue_state

    def stub_objects(*stubs)
      stubs.each { send("stub_#{it}") }
    end

    def stub_ci(**methods)
      @ci = stub_everything('Ci', **methods).responds_like_instance_of(Ci)
    end

    def stub_comment(**methods)
      @comment = stub_everything('Comment', **methods).responds_like_instance_of(Comment)
    end

    def stub_lock(**methods)
      @lock = stub_everything('Lock', **methods).responds_like_instance_of(Lock)

      # this is required as the mocha `.yields` call doesn't return the result
      # of the yield
      def lock.with_lock = yield
    end

    def stub_mergeability_monitor(**methods)
      @mergeability_monitor = stub_everything('MergeabilityMonitor', **methods)
        .responds_like_instance_of(MergeabilityMonitor)
    end

    def stub_pull_request(**methods)
      @pull_request = stub_everything('PullRequest', **methods)
        .responds_like_instance_of(PullRequest)
    end

    def stub_queue_state(**methods)
      @queue_state = stub_everything('QueueState', **methods)
        .responds_like_instance_of(QueueState)
    end

    # This is a special case. The main MergeQueue is passed to all other objects
    # giving them access to the single instances of other objects. For the tests
    # we can stub those individuals and then set the merge queue stub to return
    # them
    def stub_merge_queue(*stub_names)
      stub_objects(*stub_names)
      stubs = stub_names.map { [it, send(it)] }.to_h

      @merge_queue = stub_everything('MergeQueue', **stubs)
        .responds_like_instance_of(MergeQueue)
    end
  end
end
