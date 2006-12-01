require 'rubygems' 
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

PKG_VERSION = "0.1"

$VERBOSE = nil
TEST_CHANGES_SINCE = Time.now - 600 # Recent tests = changed in last 10 minutes

desc "Run all the unit tests"
task :default => :test

# Run all the unit tests
desc "Run the unit tests in test"
Rake::TestTask.new(:test) { |t|
#  t.loader = :testrb
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = false
}

