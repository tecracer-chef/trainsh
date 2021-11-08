require_relative '../target'

require 'yaml' unless defined?(YAML)

module TrainSH
  module Detectors
    class KitchenTarget < TargetDetector
      def self.url
        return unless kitchen_directory

        files = Dir.glob("#{kitchen_directory}/*.yml")
        return if files.empty?

        # TODO: allow connecting to multiple instances
        if files.count > 1
          say "Found #{files.count} active kitchen instances, while only supporting 1"
          exit
        end

        # Can get IP only from YAML files
        instance_yaml = YAML.load_file(files.first)

        # Can get user + protocol only from kitchen
        instance_name = File.basename(files.first, '.yml')
        instance_data = YAML.safe_load(`kitchen diagnose #{instance_name} --json`)
        transport = instance_data.dig('instances', instance_name, 'transport')

        # TODO: Additional parameters like keypair etc
        format('%<transport>s://%<user>s%<password>s@%<host>s',
               transport: transport['name'],
               user: transport['username'] || transport['user'],
               password: transport['password'] ? ":#{transport['password']}" : '',
               host: instance_yaml['hostname'] || instance_yaml['host']
              )
      end

      def self.kitchen_directory
        # TODO: Recurse up
        '.kitchen' if Dir.exist?('.kitchen')
      end
    end
  end
end
