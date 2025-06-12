# frozen_string_literal: true

require 'memery'
require 'octokit'

class Comment
  include Memery

  def self.instance = Comment.new

  def self.init(message)
    Comment.instance.message(message, init: true)
  end

  def message(message, init: false)
    if init
      result = client.add_comment(project_repo, pr_number, message)
      self.comment_id = result.id
    else
      client.update_comment(project_repo, comment_id, message)
    end
  end

  private

  attr_accessor :comment_id

  def client
    Octokit::Client.new(access_token:)
  end
  memoize :client

  def access_token = ENV.fetch('ACCESS_TOKEN')
  def pr_number = ENV.fetch('PR_NUMBER')
  def project_repo = ENV.fetch('GITHUB_REPOSITORY')
end
