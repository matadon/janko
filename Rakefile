root = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift(root) unless $LOAD_PATH.include?(root)

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "config/environment"

RSpec::Core::RakeTask.new(:spec)

task :console do
    require "pry"
    ARGV.clear
    Pry.start
end
