# frozen_string_literal: true

module MergeQueue
  class Config
    DEFAULTS = {
      ci_poll_interval: 10,
      ci_timeout: 20 * 60, # 20 minutes
      default_branch: 'main',
      lock_poll_interval: 3,
      lock_timeout: 30,
      queue_poll_interval: 5,
      queue_timeout: 5 * 60, # 5 minutes
      workspace_dir: '/tmp/merge_queue',
    }.freeze

    def initialize(**)
      @params = DEFAULTS.merge(envs).merge(**)

      params.keys.each do |param|
        self.class.define_method(param) { params[param] }
        self.class.define_method(:"#{param}=") { params[param] = it }
      end
    end

    private

    attr_reader :params

    def envs
      {
        access_token: ENV['ACCESS_TOKEN'],
        ci_timeout: ENV['CI_TIMEOUT']&.to_f,
        default_branch: ENV['DEFAULT_BRANCH'],
        pr_number: ENV['PR_NUMBER'],
        project_repo: ENV['GITHUB_REPOSITORY'],
        run_id: ENV['GITHUB_RUN_ID'],
        workspace_dir: ENV['GITHUB_WORKSPACE'],
      }.compact
    end
  end
end
