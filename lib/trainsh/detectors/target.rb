module TrainSH
  module Detectors
    class TargetDetector
      def self.descendants
        ObjectSpace.each_object(Class).select { |klass| klass < self }
      end

      def to_s
        self.class.to_s
      end

      def url
        raise "Implement `url` for target detector #{self}"
      end
    end
  end
end
