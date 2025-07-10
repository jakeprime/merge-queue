# frozen_string_literal: true

require 'git'

require_relative './configurable'
require_relative './errors'
require_relative './github_logger'

module MergeQueue
  class GitRepo
    include Configurable

    # We only want to init a repo once, and then be able to access it at any time,
    # so keep a persistent list of them
    @repos = {}

    class << self
      attr_accessor :repos
    end

    def self.init(name:, repo:, branch: default_branch, create_if_missing: false)
      return find(name) if find(name)

      repos[name] = new(name:, repo:, branch:, create_if_missing:)
    end

    def self.find(name)
      repos[name]
    end

    def initialize(name:, repo:, branch: default_branch, create_if_missing: false)
      @name = name
      @repo = repo
      @branch = branch

      git.config('user.name', 'Q-Bot')
      git.config('user.email', 'q-bot@jakeprime.com')

      checkout(create_if_missing:)
    end

    def create_branch(new_branch, from:, rebase_onto:)
      GithubLogger.debug("Fetching origin/#{rebase_onto}")

      git.fetch('origin', ref: rebase_onto, depth: 1)

      fetch_until_rebaseable(from, rebase_onto)

      git.checkout(new_branch, new_branch: true, start_point: "origin/#{from}")

      rebase(new_branch, onto: rebase_onto)
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
        raise RemoteUpdatedError, e.message
      end
    end

    def merge_to_main!(branch)
      git.fetch('origin', ref: default_branch)
      rebase(branch, onto: default_branch)
      push(branch, force: true)

      # There has to be a better way than this, but if we merge too soon the PR
      # ends up in a "closed" state rather than "merged"
      sleep 10

      git.checkout(default_branch)
      pull(default_branch)
      git.merge(branch, 'Merge commit message', no_ff: true)
      push(default_branch)
    end

    def reset_to_origin
      git.add # to make sure we include any unstaged new files
      git.reset_hard("origin/#{branch}")
      pull
    end

    def read_file(file)
      path = File.join(working_dir, file)
      File.read(path).tap do
        GithubLogger.debug("Reading file #{file}: #{it}")
      end
    rescue Errno::ENOENT
      nil
    end

    def write_file(file, contents)
      GithubLogger.debug("Writing file #{file}: #{contents}")
      path = File.join(working_dir, file)
      File.write(path, contents, mode: 'w')
    end

    def delete_file(file)
      GithubLogger.debug("Deleting #{file}")
      path = File.join(working_dir, file)
      FileUtils.rm(path)
    end

    def remote_sha
      git.fetch('origin', ref: branch)
      git.rev_parse("origin/#{branch}")
    end

    def delete_remote(remote_branch)
      git.push('origin', remote_branch, force: true, delete: true)
    end

    def pull(ref = branch)
      GithubLogger.debug("Pulling #{ref}")
      git.pull('origin', ref)
    end

    private

    attr_reader :branch, :name, :repo

    def working_dir = File.join(workspace_dir, name)

    def git = @git ||= Git.init(working_dir)

    def checkout(create_if_missing:)
      FileUtils.mkdir_p working_dir

      git.add_remote('origin', "https://#{access_token}@github.com/#{repo}")

      begin
        git.fetch('origin', ref: branch, depth: 1)
      rescue Git::FailedError
        GithubLogger.info("#{branch} does not exist")
        GithubLogger.info("create_if_missing: #{create_if_missing}")
        raise unless create_if_missing

        GithubLogger.info("Creating #{branch}...")

        # TODO: This class shouldn't know about the queue state format
        command_line_git('checkout', '--orphan', branch)
        write_file('state.json', new_lock)
        git.add('state.json')
        git.commit('Initializing merge queue branch', allow_empty: true)
        push
      end

      GithubLogger.debug "Checking out #{branch}"
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
      command_line_git('rebase', "origin/#{onto}")
    rescue GitCommandLineError
      GithubLogger.debug('Rebase failed')
      raise
    end

    # There is no way to see if a branch is rebaseable without actually rebasing,
    # so we'll keep deepening until it works and then hard reset back to the
    # original state
    def fetch_until_rebaseable(branch_a, branch_b)
      retry_attempts = 10
      git.checkout(branch_a)

      sha = command_line_git('rev-parse', 'HEAD')

      retry_attempts.times do |i|
        command_line_git('rebase', "origin/#{branch_b}")
        break
      rescue GitCommandLineError
        GithubLogger.debug('Rebase failed...')
        command_line_git('rebase', '--abort')

        raise if i == retry_attempts - 1

        GithubLogger.debug('...deepening fetch and trying again')
        command_line_git('fetch', 'origin', branch_a, '--deepen=20')
        command_line_git('fetch', 'origin', branch_b, '--deepen=20')
      end

      command_line_git('reset', '--hard', sha)
    end

    def command_line_git(*command)
      Dir.chdir(working_dir) do
        output, err, status = Open3.capture3('git', *command)
        raise GitCommandLineError, err unless status.success?

        output.chomp
      end
    end

    def push(ref = branch, **opts)
      git.push('origin', ref, **opts)
    end
  end
end
