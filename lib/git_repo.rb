# frozen_string_literal: true

require 'git'

class GitRepo
  extend Forwardable

  RemoteBeenUpdatedError = Class.new(StandardError)

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

  # Find the commit where these branches split and deepen fetch until then
  def fetch_until_common_commit(_branch_a, _branch_b)
    # TODO: make this work
    git.fetch('origin', depth: 0)
  end

  def create_branch(branch, from:, rebase_onto:)
    git.checkout(branch, new_branch: true, start_point: from)
    rebase(branch, onto: rebase_onto)
    git.push('origin', branch)
  end

  def push_changes(message)
    git.add

    git.commit(message)

    begin
      git.push('origin', branch)
    rescue Git::FailedError => e
      raise RemoteBeenUpdatedError, e.message
    end
  end

  def reset_to_origin
    git.add # to make sure we include any unstaged new files
    git.reset_hard("origin/#{branch}")
    git.pull
  end

  def read_file(file)
    path = File.join(working_dir, file)
    git.pull
    File.read(path)
  rescue Errno::ENOENT
    nil
  end

  def write_file(file, contents)
    path = File.join(working_dir, file)
    File.write(path, contents, mode: 'w')
  end

  def delete_file(file)
    path = File.join(working_dir, file)
    FileUtils.rm(path)
  end

  private

  attr_reader :branch, :name, :repo

  def working_dir = File.join(workspace_dir, name)

  def git = @git ||= Git.init(working_dir)

  def checkout
    FileUtils.mkdir_p working_dir

    git.add_remote('origin', "https://#{access_token}@github.com/#{repo}")
    git.fetch('origin', depth: 1, ref: branch)
    git.checkout(branch)
  end

  # I surely must have missed something but I couldn't find any way to `rebase`
  # on the git client, so we'll have to roll our own system command on this
  # occasion
  def rebase(branch, onto:)
    git.checkout(branch)
    system('cd', working_dir)
    system('git rebase', onto, '> /dev/null 2>&1')
    # TODO: make sure we catch any errors on the rebase here
  end

  def workspace_dir = ENV.fetch('GITHUB_WORKSPACE')

  def access_token = ENV.fetch('ACCESS_TOKEN')
end
