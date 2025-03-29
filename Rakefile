# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

namespace :test do
  desc "Run unit tests"
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/mcp/**/*_test.rb"]
    t.warning = false
  end
end

desc "Run standardrb linter"
task :lint do
  sh "bundle exec standardrb"
end

namespace :lint do
  desc "Auto-fix standardrb issues"
  task :fix do
    sh "bundle exec standardrb --fix"
  end
end

task default: :test
