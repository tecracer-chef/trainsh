require "rspec/core/rake_task"
require "bundler/gem_tasks"

Rake::Task["release"].clear

# We run tests by default
task :default => :test
#task :gem => :build

task :build do
  sh <<~EOS, { verbose: false }
    rubocop --only Lint/Syntax --fail-fast --format quiet
  EOS
end

#
# Install all tasks found in tasks folder
#
# See .rake files there for complete documentation.
#
Dir["tasks/*.rake"].each do |taskfile|
  load taskfile
end

require 'bump/tasks'
%w[set pre file current].each { |task| Rake::Task["bump:#{task}"].clear }
Bump.changelog = :editor
Bump.tag_by_default = true
