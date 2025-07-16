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

      git('fetch', 'origin', rebase_onto, '--depth=1')

      fetch_until_rebaseable(from, rebase_onto)

      git('checkout', from)
      git('checkout', '-b', new_branch)

      rebase(new_branch, onto: rebase_onto)
      push(new_branch)
      GithubLogger.info("Pushing #{new_branch} to origin")
      git('rev-parse', 'HEAD')
    end

    def push_changes(message)
      git('add', '.')
      git('commit', '-m', message)
      begin
        push
      rescue GitCommandLineError => e
        raise RemoteUpdatedError, e.message
      end
    end

    def merge_to_main!(pr_branch, merge_branch)
      git('fetch', 'origin', default_branch)
      rebase(pr_branch, onto: default_branch)
      push(pr_branch, force: true)

      status = github.compare(default_branch, pr_branch)
      GithubLogger.log("PR branch state compared to main: #{status}")

      github.merge_pull_request(pr_number)
    rescue StandardError => e
      raise PrMergeFailedError, e
    end

    def merge_commit_message
      repo_without_owner = repo.split('/')[1..].join('/')

      <<~MESSAGE
        Merge pull request ##{pr_number} from #{repo_without_owner}/#{branch}

        #{pull_request.title}
      MESSAGE
    end

    def reset_to_origin
      git('add', '.') # to make sure we include any unstaged new files
      git('reset', '--hard', "origin/#{branch}")
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
      git('fetch', 'origin', branch)
      git('rev-parse', "origin/#{branch}")
    end

    def delete_remote(remote_branch)
      git('push', '--delete', 'origin', remote_branch)
    end

    def pull(ref = branch)
      GithubLogger.debug("Pulling #{ref}")
      git('pull', 'origin', ref)
    end

    private

    attr_reader :branch, :merge_queue, :name, :repo

    def_delegators :merge_queue, :config, :github, :pull_request
    def_delegators :config, :access_token, :default_branch, :pr_number, :workspace_dir

    def working_dir = File.join(workspace_dir, name)

    def remote_uri = "https://x-access-token:#{access_token}@github.com/#{repo}"

    def checkout(create_if_missing:)
      FileUtils.mkdir_p working_dir

      git('init')
      git('config', '--local', 'user.name', 'Q-Bot')
      git('config', '--local', 'user.email', 'q-bot@jakeprime.com')

      git('remote', 'add', 'origin', remote_uri)

      begin
        git('fetch', 'origin', branch, '--depth=1')
      rescue GitCommandLineError
        GithubLogger.info("#{branch} does not exist")
        GithubLogger.info("create_if_missing: #{create_if_missing}")
        raise unless create_if_missing

        # We'll assume this error is because the merge-queue-state hasn't been
        # created yet. It could feasibly be something else, but this is the most
        # likely, and if it is something else than something more fundamental is
        # not right and we'll get an error somewhere else anyway.
        GithubLogger.info("Creating #{branch}...")

        git('checkout', '--orphan', branch)
        # We will have all the files from the original branch, need to remove
        # them to create an empty merge-queue-state

        Dir.foreach(working_dir) do |file|
          next if ['.', '..', '.git'].include?(file)

          FileUtils.rm_rf(file)
        end

        # TODO: This class shouldn't know about the queue state format
        write_file('state.json', new_lock)
        git('add', 'state.json')
        git('commit', '-m', 'Initializing merge queue branch')
        push
      end

      GithubLogger.debug "Checking out #{branch}"
      git('checkout', branch)
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
      git('checkout', branch)
      git('rebase', "origin/#{onto}")
    rescue GitCommandLineError
      GithubLogger.debug('Rebase failed')
      raise
    end

    # There is no way to see if a branch is rebaseable without actually rebasing,
    # so we'll keep deepening until it works and then hard reset back to the
    # original state
    def fetch_until_rebaseable(branch_a, branch_b)
      retry_attempts = 10
      git('checkout', branch_a)

      sha = git('rev-parse', 'HEAD')

      retry_attempts.times do |i|
        git('rebase', "origin/#{branch_b}")
        break
      rescue GitCommandLineError
        GithubLogger.debug('Rebase failed...')
        git('rebase', '--abort')

        raise if i == retry_attempts - 1

        GithubLogger.debug('...deepening fetch and trying again')
        git('fetch', 'origin', branch_a, '--deepen=20')
        git('fetch', 'origin', branch_b, '--deepen=20')
      end

      git('reset', '--hard', sha)
    end

    def git(*command)
      chdir(working_dir) do
        output, err, status = Open3.capture3('git', *command)

        unless status.success?
          GithubLogger.debug("Git error - #{status}(#{status.success?}) - #{err}")
          raise GitCommandLineError, err
        end

        output.chomp
      end
    end

    def push(ref = branch, force: false)
      opts = []
      opts << '--force-with-lease' if force

      git('push', 'origin', ref, *opts)
    end

    def chdir(dir, &)
      self.class.mutex.synchronize do
        Dir.chdir(dir, &)
      end
    end
  end
end
