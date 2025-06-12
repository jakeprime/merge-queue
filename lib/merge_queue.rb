# frozen_string_literal: true

require_relative './comment'
require_relative './github_logger'

class MergeQueue
  def call
    create_initial_comment
  end

  private

  def create_initial_comment
    GithubLogger.debug('Creating initial comment')

    Comment.init('🌱 Initialising merging process...')
  end
end
