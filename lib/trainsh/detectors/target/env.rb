require_relative '../target'

module TrainSH
  module Detectors
    class EnvTarget < TargetDetector
      def self.url
        ENV['TARGET']
      end
    end
  end
end
