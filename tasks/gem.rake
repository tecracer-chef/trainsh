# Installs rake tasks for gemming and packaging
#
begin
  require 'rubygems/package_task'

  CLEAN.include('pkg/*')
  CLEAN.include('doc/*')

  # Dynamically load the gem spec
  filename     = '../../' + Dir.glob('*.gemspec').first
  gemspec_file = File.expand_path(filename, __FILE__)
  gemspec      = Kernel.eval(File.read(gemspec_file))

  Gem::PackageTask.new(gemspec) do |t|
    t.name = gemspec.name
    t.version = gemspec.version
    t.package_dir = "pkg"
    t.package_files = gemspec.files
  end
rescue LoadError
  task :gem do
    abort 'rubygems/package_task is not available. You should verify your rubygems installation'
  end
  task :package do
    abort 'rubygems/package_task is not available. You should verify your rubygems installation'
  end
end
