source 'https://rubygems.org'

ruby file: '.tool-versions'

gem 'faraday-retry' # <- prevents warning from the git gem
gem 'git'
gem 'octokit'

group :development do
  gem 'guard'
  gem 'guard-minitest'
  gem 'rake'
  gem 'reline'
  gem 'rubocop', require: false
end

group :test do
  gem 'minitest'
  gem 'minitest-rg'
  gem 'mocha'
end
