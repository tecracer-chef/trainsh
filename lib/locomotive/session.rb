require 'forwardable'

require 'train'

module Locomotive
  class Session
    MAGIC_STRING = "mVDK6afaqa6fb7kcMqTpR2aoUFbYsRt889G4eGoI".freeze

    extend Forwardable
    def_delegators :@connection, :platform, :run_command, :backend_type, :file, :upload, :download

    attr_reader :url, :connection

    attr_accessor :pwd, :env

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

    def run(command)
      wrapped_command = batch_commands(pwd_set, command,pwd_get) # TODO: Trashes exitcode

      # command.prefix(pwd_set) { }
      # command.postfix(pwd_get) { |output| @pwd = output }

      result = connection.run_command(wrapped_command)

      output = parse_batch(result.stdout)
      @pwd = output.last

      result.stdout = output[1]
      result.exit_status = output[2]

      result
    end

    private

    # State-keeping
    def pwd_get
      platform.windows? ? "(Get-Location).Path" : "pwd"
    end

    def pwd_set(path = pwd)
      return "" if path.nil?

      platform.windows? ? "Set-Location #{path}" : "cd #{path}"
    end

    def env_get
      # TODO
    end

    def env_set
      # TODO
    end

    def batch_commands(*args)
      separator = "\necho #{MAGIC_STRING}\n"

      args.join(separator)
    end

    def parse_batch(batch_output)
      batch_output.split(MAGIC_STRING).map(&:strip)
    end
  end
end
