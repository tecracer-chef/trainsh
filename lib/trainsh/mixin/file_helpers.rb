require 'tempfile' unless defined?(Tempfile)

module TrainSH
  module Mixin
    module FileHelpers
      def read_file(path)
        remotefile = session.file(path)
        say format('Remote file %<filename>s does not exist', filename: path) unless remotefile.exist?

        localfile = Tempfile.open
        localfile.write(remotefile.content || '')
        localfile.close

        localfile
      end

      def write_file(path, content)
        remotefile = session.file(path)
        remotefile.content = content
      end
    end
  end
end
