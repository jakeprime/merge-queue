# frozen_string_literal: true

require 'octokit'

require_relative './configurable'

module MergeQueue
  # A simple wrapper around Octokit. All calls will always need the project repo
  # as the first argument so we can add that here before delegating. This helps
  # with testing, and decouples the application from Octokit specifically.
  class Github
    include Configurable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def add_comment(*) = client.add_comment(project_repo, *)

    def pull(*) = client.pull(project_repo, *)

    def status(*) = client.status(project_repo, *)

    def update_comment(*) = client.update_comment(project_repo, *)

    private

    attr_reader :merge_queue

    def client = @client ||= Octokit::Client.new(access_token:)
  end
end
