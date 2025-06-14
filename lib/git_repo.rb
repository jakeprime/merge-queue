# frozen_string_literal: true

require 'git'

class GitRepo
  extend Forwardable

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

  def_delegators :git, :read_file

  def write_file(file, contents)
    path = File.join(working_dir, file)
    File.write(path, contents, mode: 'w')
  end

  private

  attr_reader :branch, :name, :repo

  def working_dir = File.join(workspace_dir, name)

  def git = @git ||= Git.init(working_dir)

  def checkout
    FileUtils.mkdir_p working_dir

    git.add_remote('origin', "https://github.com/#{repo}")
    git.fetch('origin', depth: 1, ref: branch)
    git.checkout(branch)
  end

  def workspace_dir = ENV.fetch('GITHUB_WORKSPACE')
end
