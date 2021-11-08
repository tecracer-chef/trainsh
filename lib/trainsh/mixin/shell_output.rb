module TrainSH
  module Mixin
    module ShellOutput
      def show_error(message)
        say message.red
      end

      def show_message(message)
        say message.yellow
      end
    end
  end
end
