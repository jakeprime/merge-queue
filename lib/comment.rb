# frozen_string_literal: true

require 'octokit'

###
# Writes message to the PR as a comment. The initial message is written to a new
# comment and then all following ones update that one.
class Comment
  def self.instance = @instance ||= new

  def self.init(message)
    @instance = nil
    instance.send(:message, message, init: true)
  end

  def self.message(message)
    instance.send(:message, message)
  end

  private

  attr_accessor :comment_id

  def message(message, init: false)
    if init
      result = client.add_comment(project_repo, pr_number, message)
      self.comment_id = result.id
    else
      client.update_comment(project_repo, comment_id, message)
    end
  end

  def client = @client ||= Octokit::Client.new(access_token:)

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
