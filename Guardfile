# frozen_string_literal: true

# More info at https://github.com/guard/guard#readme

guard :minitest do
  # with Minitest::Unit
  watch(%r{^test/lib/(.+)_test\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "test/lib/#{m[1]}_test.rb" }
  watch(%r{^test/(unit_)?test_helper\.rb$}) { 'test' }
end
