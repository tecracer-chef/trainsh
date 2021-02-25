# Installs a rake task for for running examples written using rspec.
#
begin
  require "rspec/core/rake_task"
  desc "Run RSpec code examples"
  RSpec::Core::RakeTask.new(:unit_test) do |t|
    t.fail_on_error = true
    t.failure_message = nil
    t.verbose = false
  end
rescue LoadError => ex
  task :unit_test do
    abort 'rspec is not available. In order to run spec, you must: gem install rspec'
  end
ensure
  task :spec => [:unit_test]
  task :test => [:unit_test]
end
