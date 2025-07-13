# frozen_string_literal: true

require 'forwardable'
require 'open3'

require_relative './errors'
require_relative './github_logger'

module MergeQueue
  class GitRepo
    extend Forwardable

    # Dir.chdir isn't threadsafe. This isn't really a problem in production, but
    # it makes it impossible to test multiple instances of the app running at
    # once
    def self.mutex
      @mutex ||= Mutex.new
    end

    def initialize(
      merge_queue, name, repo:, branch: default_branch, create_if_missing: false
    )
      @merge_queue = merge_queue
      @name = name
      @repo = repo
      @branch = branch

      checkout(create_if_missing:)
    end

    def create_branch(new_branch, from:, rebase_onto:)
      GithubLogger.debug("Fetching origin/#{rebase_onto}")

      command_line_git('fetch', 'origin', rebase_onto, '--depth=1')
      # git.fetch('origin', ref: rebase_onto, depth: 1)

      fetch_until_rebaseable(from, rebase_onto)

      command_line_git('checkout', from)
      command_line_git('checkout', '-b', new_branch)

      rebase(new_branch, onto: rebase_onto)
      push(new_branch)
      GithubLogger.info("Pushing #{new_branch} to origin")
      command_line_git('rev-parse', 'HEAD')
    end

    def push_changes(message)
      command_line_git('add', '.')
      command_line_git('commit', '-m', message)
      begin
        push
      rescue GitCommandLineError => e
        raise RemoteUpdatedError, e.message
      end
    end

    def merge_to_main!(branch)
      command_line_git('fetch', 'origin', default_branch)
      rebase(branch, onto: default_branch)
      push(branch, force: true)

      command_line_git('checkout', default_branch)
      pull(default_branch)
      command_line_git('merge', '--no-ff', '-m', 'Merge commit message', branch)
      push(default_branch)
    end

    def reset_to_origin
      command_line_git('add', '.') # to make sure we include any unstaged new files
      command_line_git('reset', '--hard', "origin/#{branch}")
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
      command_line_git('fetch', 'origin', branch)
      command_line_git('rev-parse', "origin/#{branch}")
    end

    def delete_remote(remote_branch)
      command_line_git('push', '--delete', 'origin', remote_branch)
    end

    def pull(ref = branch)
      GithubLogger.debug("Pulling #{ref}")
      command_line_git('pull', 'origin', ref)
    end

    private

    attr_reader :branch, :merge_queue, :name, :repo

    def_delegators :merge_queue, :config
    def_delegators :config, :access_token, :default_branch, :workspace_dir

    def working_dir = File.join(workspace_dir, name)

    def remote_uri = "https://x-access-token:#{access_token}@github.com/#{repo}"

    def checkout(create_if_missing:)
      FileUtils.mkdir_p working_dir

      command_line_git('init')
      command_line_git('config', '--local', 'user.name', 'Q-Bot')
      command_line_git('config', '--local', 'user.email', 'q-bot@jakeprime.com')

      command_line_git('remote', 'add', 'origin', remote_uri)

      begin
        command_line_git('fetch', 'origin', branch, '--depth=1')
      rescue GitCommandLineError
        GithubLogger.info("#{branch} does not exist")
        GithubLogger.info("create_if_missing: #{create_if_missing}")
        raise unless create_if_missing

        # We'll assume this error is because the merge-queue-state hasn't been
        # created yet. It could feasibly be something else, but this is the most
        # likely, and if it is something else than something more fundamental is
        # not right and we'll get an error somewhere else anyway.
        GithubLogger.info("Creating #{branch}...")

        command_line_git('checkout', '--orphan', branch)
        # We will have all the files from the original branch, need to remove
        # them to create an empty merge-queue-state

        Dir.foreach(working_dir) do |file|
          next if ['.', '..', '.git'].include?(file)

          FileUtils.rm_rf(file)
        end

        # TODO: This class shouldn't know about the queue state format
        write_file('state.json', new_lock)
        command_line_git('add', 'state.json')
        command_line_git('commit', '-m', 'Initializing merge queue branch')
        push
      end

      GithubLogger.debug "Checking out #{branch}"
      command_line_git('checkout', branch)
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
      command_line_git('checkout', branch)
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
      command_line_git('checkout', branch_a)

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
      chdir(working_dir) do
        output, err, status = Open3.capture3('git', *command)
        # binding.irb unless status.success?
        GithubLogger.debug("Git error - #{status}(#{status.success?}) - #{err}") unless status.success?
        raise GitCommandLineError, err unless status.success?

        output.chomp
      end
    end

    def push(ref = branch, force: false)
      opts = []
      opts << '--force-with-lease' if force

      # command_line_git('pull', 'origin', ref, '--rebase')
      command_line_git('push', 'origin', ref, *opts)
    end

    def chdir(dir, &)
      self.class.mutex.synchronize do
        Dir.chdir(dir, &)
      end
    end
  end
end
