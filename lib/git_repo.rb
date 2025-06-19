# frozen_string_literal: true

require 'git'

require_relative '../lib/github_logger'

class GitRepo
  extend Forwardable

  RemoteBeenUpdatedError = Class.new(StandardError)

  # We only want to init a repo once, and then be able to access it at any time,
  # so keep a persistent list of them
  @repos = {}

  class << self
    attr_accessor :repos
  end

  def self.init(name:, repo:, branch: 'main', create_if_missing: false)
    return find(name) if find(name)

    repos[name] = new(name:, repo:, branch:, create_if_missing:)
  end

  def self.find(name)
    repos[name]
  end

  def initialize(name:, repo:, branch: 'main', create_if_missing: false)
    @name = name
    @repo = repo
    @branch = branch

    checkout(create_if_missing:)
  end

  # Find the commit where these branches split and deepen fetch until then
  def fetch_until_common_commit(_branch_a, _branch_b)
    # TODO: make this work
    git.fetch('origin', depth: 0)
  end

  def create_branch(new_branch, from:, rebase_onto:)
    git.checkout(new_branch, new_branch: true, start_point: from)
    rebase(new_branch, onto: rebase_onto)
    git.push('origin', new_branch)
    git.object('HEAD').sha
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

  def merge_to_main!(branch)
    git.fetch('origin', ref: 'main')
    rebase(branch, onto: 'origin/main')
    git.push('origin', branch, force: true)

    git.checkout('main')
    git.pull('origin')
    git.merge(branch, 'Merge commit message', no_ff: true)
    # TODO: can we do this with-lease?
    git.push('origin', 'main', force: true)
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

  def remote_sha
    git.fetch('origin', ref: branch)
    git.rev_parse("origin/#{branch}")
  end

  private

  attr_reader :branch, :name, :repo

  def working_dir = File.join(workspace_dir, name)

  def git = @git ||= Git.init(working_dir)

  def checkout(create_if_missing:)
    FileUtils.mkdir_p working_dir

    git.add_remote('origin', "https://#{access_token}@github.com/#{repo}")

    begin
      git.fetch('origin', depth: 1, ref: branch)
    rescue Git::FailedError
      GithubLogger.info("#{branch} does not exist")
      GithubLogger.info("create_if_missing: #{create_if_missing}")
      raise unless create_if_missing

      GithubLogger.info("Creating #{branch}...")

      Dir.chdir(working_dir) do
        system('git', 'checkout', '--orphan', branch)
      end
      git.commit('Initializing merge queue branch', allow_empty: true)
      git.push('origin', branch)
    end

    git.checkout(branch)
  end

  # I surely must have missed something but I couldn't find any way to `rebase`
  # on the git client, so we'll have to roll our own system command on this
  # occasion
  def rebase(branch, onto:)
    git.checkout(branch)
    Dir.chdir(working_dir) do
      system('git', 'rebase', onto)
      # TODO: make sure we catch any errors on the rebase here
    end
  end

  def workspace_dir = ENV.fetch('GITHUB_WORKSPACE')

  def access_token = ENV.fetch('ACCESS_TOKEN')
end
