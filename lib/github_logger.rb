# frozen_string_literal: true

class GithubLogger
  def self.log(message, level: :info)
    # The ::level:: format is respected by Github actions
    # By default `debug` logs will not be output, but will be if debug mode is
    # enable on the run
    puts "::#{level}:: #{message}" unless ENV['ENVIRONMENT'] == 'test'
  end

  def self.debug(message)
    log(message, level: :debug)
  end

  def self.info(message)
    log(message, level: :info)
  end

  def self.warn(message)
    log(message, level: :warn)
  end

  def self.error(message)
    log(message, level: :error)
  end
end
