# frozen_string_literal: true

module MergeQueue
  class GithubLogger
    def self.log(message, level: :info)
      # The ::level:: format is respected by Github actions for debug and error
      # By default `debug` logs will not be output, but will be if debug mode is
      # enable on the run
      prefix = "::#{level}:: " if %i[debug error].include?(level)

      return if ENV['ENVIRONMENT'] == 'test'

      message.chomp.split("\n").each do
        puts "#{prefix}#{timestamp} - #{it}"
      end
    end

    def self.debug(message)
      log(message, level: :debug)
    end

    def self.info(message)
      log(message, level: :info)
    end

    def self.error(message)
      log(message, level: :error)
    end

    def self.timestamp = Time.new.strftime('%H:%M:%S')
  end
end
