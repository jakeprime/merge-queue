# frozen_string_literal: true

require 'forwardable'

module MergeQueue
  class QueueTableRenderer
    extend Forwardable

    def initialize(merge_queue)
      @merge_queue = merge_queue
    end

    def to_table
      return '' if queue_state.entries.none?

      ['', '', header, rows].flatten.join("\n")
    end

    private

    attr_reader :merge_queue

    def_delegators :merge_queue, :config, :pull_request, :queue_state
    def_delegators :config, :pr_number, :project_repo

    def header
      [
        '### Your place in the queue:',
        '',
        'Position | Status | PR | CI Run',
        ':---: | :---: | :--- | :---',
      ]
    end

    def rows
      queue_state.entries.map.with_index do |entry, index|
        [
          index + 1,
          status(entry),
          our_position?(entry) ? '🫵' : pr_link(entry),
          ci_link(entry),
        ].join(' | ')
      end
    end

    def status(entry)
      {
        Ci::SUCCESS => '🟢',
        Ci::PENDING => '🟡',
        Ci::FAILURE => '🔴',
      }.fetch(entry['status'])
    end

    def our_position?(entry)
      entry['name'] == pull_request.merge_branch
    end

    def pr_link(entry)
      # redirect.github creates a link without a backlink
      "[#{entry['title']}](https://redirect.github.com/#{project_repo}/pull/#{entry['pr_number']})"
    end

    def ci_link(entry)
      "[#{entry['pr_branch']}](https://app.circleci.com/pipelines/github/#{project_repo}?branch=#{entry['name']})"
    end
  end
end
