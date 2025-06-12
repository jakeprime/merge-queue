# frozen_string_literal: true

require_relative './comment'

class MergeQueue
  def call
    Comment.init('Initial commit')
  end
end
