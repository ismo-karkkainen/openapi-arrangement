# frozen_string_literal: true

# Copyright 2024-2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'rubocop/rake_task'
require 'rake/testtask'


task default: [:test]
desc 'Clean.'
task :clean do
  sh 'rm -f openapi-arrangement-*.gem'
end

desc 'Build gem.'
task gem: [:clean] do
  sh 'gem build openapi-arrangement.gemspec'
end

desc 'Build and install gem.'
task install: [:gem] do
  sh 'gem install openapi-arrangement-*.gem'
end

desc 'Uninstall gem.'
task :uninstall do
  sh 'gem uninstall openapi-arrangement'
end

desc 'Test.'
task :test do
  require_relative 'coverage_simplecov'
  require 'test/unit'
  Test::Unit::AutoRunner.run(true)
end

RuboCop::RakeTask.new(:lint) do |t|
  t.patterns = [ 'lib', 'openapi-arrangement.gemspec' ]
end
