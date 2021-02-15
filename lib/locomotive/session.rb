require 'forwardable'

require 'train'

module Locomotive
  class Session
    extend Forwardable
    def_delegators :@connection, :platform, :run_command, :backend_type, :file, :upload, :download

    attr_accessor :url, :connection

    def initialize(url = nil)
      connect(url) unless url.nil?
    end

    def connect(url)
      @url = url

      data = Train.unpack_target_from_uri(url)
      backend = Train.create(data[:backend], data)

      @connection = backend.connection
      connection.wait_until_ready

      at_exit { disconnect }
    end

    def disconnect
      puts "Closing session #{url}"

      connection.close
    end

    def reconnect
      disconnect

      connect(url)
    end
  end
end
