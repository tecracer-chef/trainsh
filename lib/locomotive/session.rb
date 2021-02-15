require 'forwardable'

require 'train'

module Locomotive
  class Command
    MAGIC_STRING = "mVDK6afaqa6fb7kcMqTpR2aoUFbYsRt889G4eGoI".freeze

    attr_writer :connection

    def initialize(command, connection)
      @command = command
      @connection = connection

      @prefixes = []
      @postfixes = []
    end

    def prefix(prefix_command, &block)
      @prefixes << {
        command: prefix_command,
        block: block
      }
    end

    def postfix(postfix_command, &block)
      @postfixes << {
        command: postfix_command,
        block: block
      }
    end

    def run
      result = @connection.run_command aggregate_commands
      stdouts = parse(result)

      prefixes_stdout = stdouts.first(@prefixes.count).reverse
      @prefixes.each_with_index do |prefix, idx|
        next if prefix[:block].nil?

        prefix[:block].call prefixes_stdout[idx]
      end
      @prefixes.count.times { stdouts.shift } unless @prefixes.empty?

      postfixes_stdout = stdouts.last(@postfixes.count)
      @postfixes.each_with_index do |postfix, idx|
        next if postfix[:block].nil?

        postfix[:block].call postfixes_stdout[idx]
      end
      @postfixes.count.times { stdouts.pop } unless @postfixes.empty?

      raise 'Pre-/Postfix command processing ended up with more than one remaining stdout' unless stdouts.count == 1

      result.stdout = stdouts.first
      result.exit_status = 0 # TODO
      result
    end

    def parse(result)
      result.stdout
        .gsub(/\r\n/, "\n")
        .gsub(/ *$/, '')
        .split(MAGIC_STRING)
        .map(&:strip)
    end

    def aggregate_commands
      separator = "\necho #{MAGIC_STRING}\n"

      commands = @prefixes.reverse.map { |ary| ary[:command] }
      commands << @command
      commands.concat @postfixes.map { |ary| ary[:command] }

      commands.join(separator)
    end
  end

  class Session
    extend Forwardable
    def_delegators :@connection, :platform, :run_command, :backend_type, :file, :upload, :download

    attr_reader :connection, :backend, :host

    attr_accessor :pwd, :env

    def initialize(url = nil)
      connect(url) unless url.nil?
    end

    def connect(url)
      @url = url

      data = Train.unpack_target_from_uri(url)
      backend = Train.create(data[:backend], data)

      @backend = data[:backend]
      @host = data[:host]

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

    # Redact password information
    def url
      Addressable::URI.parse(@url).omit(:password).to_s
    end

    def run(command)
      command = Command.new(command, @connection)

      command.prefix(pwd_set)
      command.postfix(pwd_get) { |output| @pwd = output }
      command.prefix(env_set)
      command.postfix(env_get) { |output| @env = output }

      # Discovery tasks
      command.prefix(host_get) { |output| @host = output} if host.nil? || host == 'unknown'

      command.run
    end

    def run_idle
      run('#')
    end

    private

    def host_get
      "hostname"
    end

    def pwd_get
      platform.windows? ? "(Get-Location).Path" : "pwd"
    end

    def pwd_set(path = pwd)
      return "" if path.nil?

      platform.windows? ? "Set-Location #{path}" : "cd #{path}"
    end

    # TODO: Preserve Windows environment variables
    def env_get
      platform.windows? ? "" : "export"
    end

    # TODO: Preserve Windows environment variables
    def env_set
      platform.windows? ? "" : env
    end
  end
end
