# frozen_string_literal: true

class Config
  PARAMS = %i[
    access_token default_branch pr_number project_repo run_id workspace_dir
  ].freeze

  class << self
    attr_accessor(*PARAMS)
  end

  self.default_branch = 'main'
  self.workspace_dir = '/tmp/merge-queue'
end
