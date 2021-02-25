lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)
require 'trainsh/constants'
require 'trainsh/version'

Gem::Specification.new do |spec|
  spec.name        = TrainSH::EXEC
  spec.version     = TrainSH::VERSION
  spec.licenses    = ['Nonstandard']

  spec.summary     = 'Interactive Shell for Remote Systems'
  spec.description = 'Based on the Train ecosystem, provide a shell to manage systems via a multitude of transports.'
  spec.authors     = ['Thomas Heinen']
  spec.email       = ['theinen@tecracer.de']
  spec.homepage    = 'https://chef.tecracer.de'

  spec.files       = Dir['lib/**/**/**']
  spec.files      += ['README.md', 'CHANGELOG.md']

  spec.required_ruby_version = '>= 2.6'

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bump', '~> 0.9'
  spec.add_development_dependency 'bundler-audit', '~> 0.7'
  spec.add_development_dependency 'mdl', '~> 0.9'
  spec.add_development_dependency 'overcommit', '~> 0.55'
  spec.add_development_dependency 'rake', '~> 12.3'
  # spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 0.92'
  # spec.add_development_dependency 'rubocop-rspec', '~> 1.42'

  spec.add_dependency 'colored', '~> 1.2'
  # spec.add_dependency 'mixlib-config', '~> 3.0'
  # spec.add_dependency 'mixlib-log', '~> 3.0'
  spec.add_dependency 'readline', '~> 0.0'
  spec.add_dependency 'thor', '~> 1.1'
  spec.add_dependency "train", ">= 3.4.9"
end
