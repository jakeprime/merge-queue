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
    puts "User is #{client.user.login}"
  end

  private

  def client
    Octokit::Client.new(access_token:)
  end
  memoize :client

  def access_token = ENV.fetch('GITHUB_TOKEN')
end
