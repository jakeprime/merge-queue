# frozen_string_literal: true

module MergeQueue
  class Config
    PARAMS = %i[
      access_token
      ci_poll_interval
      ci_wait_time
      default_branch
      lock_poll_interval
      lock_wait_time
      pr_number
      project_repo
      run_id
      workspace_dir
    ].freeze

    attr_accessor(*PARAMS)

    def initialize
      self.default_branch = 'main'
      self.ci_poll_interval = 1
      self.ci_wait_time = 3
      self.lock_poll_interval = 1
      self.lock_wait_time = 3
      self.workspace_dir = '/tmp/merge-queue'
    end

    def to_s
      PARAMS.map { { it => send(it.to_sym) } }
    end
  end
end
