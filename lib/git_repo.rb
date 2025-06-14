# frozen_string_literal: true

class GitRepo
  # We only want to init a repo once, and then be able to access it at any time,
  # so keep a persistent list of them
  @repos = {}

  class << self
    attr_accessor :repos
  end

  def self.init(name:, repo:, branch: 'main')
    return find(name:) if find(name:)

    repos[name] = new(name:, repo:, branch:)
  end

  def self.find(name:)
    repos[name]
  end

  def initialize(name:, repo:, branch: 'main')
    @name = name
    @repo = repo
    @branch = branch

    checkout
  end

  private

  attr_reader :branch, :name, :repo

  def working_dir = File.join(workspace_dir, name)

  def checkout
    FileUtils.mkdir_p working_dir
  end

  def workspace_dir = ENV.fetch('GITHUB_WORKSPACE')
end
