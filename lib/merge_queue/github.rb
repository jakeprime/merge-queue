# frozen_string_literal: true

require 'octokit'

module MergeQueue
  # A simple wrapper around Octokit. All calls will always need the project repo
  # as the first argument so we can add that here before delegating. This helps
  # with testing, and decouples the application from Octokit specifically.
  class Github
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def add_comment(*) = client.add_comment(project_repo, *)

    def issue_comment_reactions(*) = client.issue_comment_reactions(project_repo, *)

    def compare(*) = client.compare(project_repo, *)

    def merge_pull_request(*) = client.merge_pull_request(project_repo, *)

    def pull(*) = client.pull(project_repo, *)

    def repository_workflow_runs(*) = client.repository_workflow_runs(project_repo, *)

    def status(*) = client.status(project_repo, *)

    def update_comment(*) = client.update_comment(project_repo, *)

    private

    attr_reader :merge_queue

    def_delegators :merge_queue, :config
    def_delegators :config, :access_token, :project_repo

    def client = @client ||= Octokit::Client.new(access_token:)
  end
end
