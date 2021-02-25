require 'benchmark'
require 'forwardable'

require 'train'

module TrainSH
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

      if stdouts.count > 1
        raise 'Pre-/Postfix command processing ended up with more than one remaining stdout'
      end

      result.stdout = stdouts.first
      # result.stderr = "" # TODO
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
      commands << @command + "\n" + save_exit_code
      commands.concat @postfixes.map { |ary| ary[:command] }

      commands.join(separator)
    end

    def save_exit_code
      @connection.platform.windows? ? "$#{TrainSH::EXITCODE_VAR}=$LastExitCode" : "export #{TrainSH::EXITCODE_VAR}=$?"
    end
  end

  class Session
    extend Forwardable
    def_delegators :@connection, :platform, :run_command, :backend_type, :file, :upload, :download

    attr_reader :connection, :backend, :host

    attr_accessor :pwd, :env, :ping, :exitcode

    def initialize(url = nil)
      connect(url) unless url.nil?
    end

    def connect(url)
      @url = url

      data = Train.unpack_target_from_uri(url)

      # TODO: Wire up with "messy" parameter
      data[:cleanup] = false

      backend = Train.create(data[:backend], data)
      return false unless backend

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

    def run(command, skip_affixes: false)
      command = Command.new(command, @connection)

      # Save exit code
      command.postfix(exitcode_get) { |output| @exitcode = output.to_i }

      # Request UTF-8 instead of UTF-16
      # command.prefix("$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'") if platform.windows?

      unless skip_affixes
        command.prefix(pwd_set)
        command.postfix(pwd_get) { |output| @pwd = output }
        command.prefix(env_set)
        command.postfix(env_get) { |output| @env = output }
      end

      # Discovery tasks
      command.prefix(host_get) { |output| @host = output} if host.nil? || host == 'unknown'

      command.run
    end

    def run_idle
      @ping = ::Benchmark.measure { run('#', skip_affixes: true) }.real * 1000
    end

    private

    def exitcode_get
      "echo $#{TrainSH::EXITCODE_VAR}"
    end

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
