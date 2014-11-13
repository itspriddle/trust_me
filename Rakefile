$:.unshift "lib"

begin
  require "rspec/core/rake_task"
  require "bundler/gem_tasks"
  require "rake-tomdoc"
rescue LoadError
  abort "Please run `bundle install`"
end

RSpec::Core::RakeTask.new :spec
task :default => :spec
