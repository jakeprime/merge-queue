# frozen_string_literal: true

source 'https://rubygems.org'

ruby file: '.tool-versions'

gem 'faraday-retry' # <- prevents warning from the git gem
gem 'octokit'

group :development, :test do
  gem 'debug'
  gem 'irb'
end

group :development do
  gem 'guard'
  gem 'guard-minitest'
  gem 'rake'
  gem 'reline'
  gem 'rubocop', require: false
end

group :test do
  gem 'climate_control'
  gem 'dotenv'
  gem 'minitest'
  gem 'minitest-around'
  gem 'minitest-rg'
  gem 'minitest-stub-const'
  gem 'mocha'
  gem 'webmock'
end
