# frozen_string_literal: true

require 'git'

require_relative '../lib/github_logger'

class GitRepo
  extend Forwardable

  GitCommandLineError = Class.new(StandardError)
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

    git.config('user.name', 'Q-Bot')
    git.config('user.email', 'q-bot@jakeprime.com')

    checkout(create_if_missing:)
  end

  def create_branch(new_branch, from:, rebase_onto:)
    # TODO: fetch only the required depth
    GithubLogger.debug("Fetching origin/#{rebase_onto}")
    git.fetch('origin', ref: rebase_onto)
    git.checkout(new_branch, new_branch: true, start_point: from)
    rebase(new_branch, onto: "origin/#{rebase_onto}")
    push(new_branch)
    GithubLogger.info("Pushing #{new_branch} to origin")
    git.object('HEAD').sha
  end

  def push_changes(message)
    git.add

    git.commit(message)

    begin
      push
    rescue Git::FailedError => e
      raise RemoteBeenUpdatedError, e.message
    end
  end

  def merge_to_main!(branch)
    git.fetch('origin', ref: 'main')
    rebase(branch, onto: 'origin/main')
    push(branch, force: true)

    git.checkout('main')
    pull('main')
    git.merge(branch, 'Merge commit message', no_ff: true)
    # TODO: can we do this with-lease?
    push('main', force: true)
  end

  def reset_to_origin
    git.add # to make sure we include any unstaged new files
    git.reset_hard("origin/#{branch}")
    pull
  end

  def read_file(file)
    path = File.join(working_dir, file)
    pull
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
    # TODO: fetch only to the depth needed
    git.fetch('origin', ref: branch)
    git.rev_parse("origin/#{branch}")
  end

  def delete_remote(remote_branch)
    git.push('origin', remote_branch, force: true, delete: true)
  end

  private

  attr_reader :branch, :name, :repo

  def working_dir = File.join(workspace_dir, name)

  def git = @git ||= Git.init(working_dir)

  def checkout(create_if_missing:)
    FileUtils.mkdir_p working_dir

    git.add_remote('origin', "https://#{access_token}@github.com/#{repo}")

    begin
      # TODO: fetch only to the depth needed
      git.fetch('origin', ref: branch)
    rescue Git::FailedError
      GithubLogger.info("#{branch} does not exist")
      GithubLogger.info("create_if_missing: #{create_if_missing}")
      raise unless create_if_missing

      GithubLogger.info("Creating #{branch}...")

      command_line_git('checkout', '--orphan', branch)
      write_file('state.json', new_lock)
      git.add('state.json')
      git.commit('Initializing merge queue branch', allow_empty: true)
      push
    end

    GithubLogger.info "git.checkout #{branch}"
    git.checkout(branch)
  end

  def new_lock
    JSON.pretty_generate(
      { branchCounter: 1, mergeBranches: [] },
    )
  end

  # I surely must have missed something but I couldn't find any way to `rebase`
  # on the git client, so we'll have to roll our own system command on this
  # occasion
  def rebase(branch, onto:)
    git.checkout(branch)
    command_line_git('rebase', onto)
  rescue GitCommandLineError
    GithubLogger.error "Failed to rebase #{branch} onto #{onto}"
    raise
  end

  def command_line_git(*command)
    Dir.chdir(working_dir) do
      _, err, status = Open3.capture3('git', *command)
      raise GitCommandLineError, err unless status.success?
    end
  end

  def pull(ref = branch)
    git.pull('origin', ref)
  end

  def push(ref = branch, **opts)
    git.push('origin', ref, **opts)
  end

  def workspace_dir = ENV.fetch('GITHUB_WORKSPACE')

  def access_token = ENV.fetch('ACCESS_TOKEN')
end
