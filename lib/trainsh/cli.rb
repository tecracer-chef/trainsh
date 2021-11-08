require_relative '../trainsh'
require_relative 'session'

require_relative 'mixin/builtin_commands'
require_relative 'mixin/file_helpers'
require_relative 'mixin/sessions'

# TODO
# require_relative 'detectors/target/env.rb'
# require_relative 'detectors/target/kitchen.rb'

require 'colored'
require 'fileutils'
require 'readline'
require 'train'
require 'thor'

module TrainSH
  class Cli < Thor
    include Thor::Actions
    check_unknown_options!

    def self.exit_on_failure?
      true
    end

    map %w[version] => :__print_version
    desc 'version', 'Display version'
    def __print_version
      say "#{TrainSH::PRODUCT} #{TrainSH::VERSION} (Ruby #{RUBY_VERSION}-#{RUBY_PLATFORM})"
    end

    EXIT_COMMANDS = %w[!!! exit quit logout disconnect].freeze
    INTERACTIVE_COMMANDS = %w[more less vi vim nano].freeze

    no_commands do
      include TrainSH::Mixin::BuiltInCommands
      include TrainSH::Mixin::FileHelpers
      include TrainSH::Mixin::Sessions

      def __disconnect
        session.close

        say 'Disconnected'
      end

      # TODO
      # def __detect_url(url)
      #   url || kitchen_url || ENV['target']
      # end

      def __detect
        raise 'No session in __detect' unless session

        platform = session.platform

        say format('Platform: %<title>s %<release>s (%<arch>s)',
                   title:   platform.title,
                   release: platform.release,
                   arch:    platform.arch)
        say format('Hierarchy: %<hierarchy>s',
                   hierarchy: platform.family_hierarchy.reverse.join('/'))
        say 'Measuring ping over connection...'

        # Idle command will also trigger discovery commands on first run
        session.run_idle

        say format('Ping: %<ping>dms', ping: session.ping) if session.ping
      end

      def target_detectors
        Dir[File.join(__dir__, 'lib', '*.rb')].sort.each { |file| require file }

        TrainSH::Detectors::TargetDetector.descendants
      end

      def execute(input)
        if input == '?'
          execute_builtin 'help'
          return
        end

        case input[0]
        when '.'
          execute_locally input[1..]
        when '!'
          execute_builtin input[1..]
        when '@'
          execute_via_session input[1..]
        else
          execute_via_train input
        end
      end

      def execute_locally(input)
        system(input)
      end

      def execute_via_train(input, session_id = current_session_id)
        return if interactive_command? input

        command_result = @sessions[session_id].run(input)

        say command_result.stdout unless command_result.stdout && command_result.stdout.empty?
        say command_result.stderr.red unless command_result.stderr && command_result.stderr.empty?
      end

      def execute_builtin(input)
        cmd, *args = input.split

        ruby_cmd = cmd.tr('-', '_')

        if builtin_commands.include? ruby_cmd
          send("#{BUILTIN_PREFIX}#{ruby_cmd}".to_sym, *args)
        else
          say format('Unknown built-in "%<cmd>s"', cmd: cmd)
        end
      end

      def execute_via_session(input)
        session_id, *data = input.split

        session_id = validate_session_id(session_id)
        if session_id.nil?
          say 'Expecting valid session id, e.g. `!session 2`'.red
          return
        end

        input = data.join(' ')
        if input.empty?
          say 'Specify command to execute, e.g. `@0 ls`'
          return
        end

        execute_via_train(input, session_id)
      end

      def interactive_command?(cmd)
        return unless INTERACTIVE_COMMANDS.any? { |banned| cmd.start_with? banned }

        say 'Cannot execute interactive commands on non-tty sessions'.red
      end

      def exit_command?(cmd)
        EXIT_COMMANDS.include? cmd
      end

      def prompt
        exitcode = current_session.exitcode || 0
        exitcode_prefix = exitcode.zero? ? 'OK '.green : format('E%02d ', exitcode).red

        format(::TrainSH::PROMPT,
               exitcode:        exitcode,
               exitcode_prefix: exitcode_prefix,
               session_id:      current_session_id,
               backend:         current_session.backend || 'unknown',
               host:            current_session.host || 'unknown',
               path:            current_session.pwd || '?')
      end

      def auto_complete(partial)
        choices = []

        choices.concat(builtin_commands.map { |cmd| "!#{cmd.tr('_', '-')}" })
        choices.concat(sessions.map { |session_id| "@#{session_id}" })
        choices.concat %w[!!! ?]

        choices.filter { |choice| choice.start_with? partial }
      end

      # def get_log_level(level)
      #   valid = %w{debug info warn error fatal}
      #
      #   if valid.include?(level)
      #     l = level
      #   else
      #     l = "info"
      #   end
      #
      #   Logger.const_get(l.upcase)
      # end
    end

    # class_option :log_level, desc: "Log level", aliases: "-l", default: :info
    class_option :messy, desc: 'Skip deletion of temporary files for speedup', default: false, type: :boolean

    desc 'connect URL', 'Connect to a destination interactively'
    long_desc <<-DESC
      Create an interactive shell session with the remote system. The specified URL has to match the
      chosen transport plugin.

      Examples:
        docker://d9443b195d16
        local://
        ssh://user@remote.example.com
        winrm://Administrator:PASSWORD@10.2.42.1

      Examples from non-standard transports:
        aws-ssm://i-1234567890ab
        serial://dev/ttyUSB1/9600
        telnet://127.0.0.1
        vsphere-gom://Administrator@vcenter.server/virtual.machine

      Every transport has its own, proprietary options which can currently only be added as URL
      query parameters:
        ssh://user@remote.example.com?key_files=/home/ubuntu/test.pem

      Passwords currently have to be part of the URL.
    DESC
    def connect(url)
      # TODO: Pass options to `use_session`
      exit unless use_session(url)

      say format('Connected to %<url>s', url: session.url).bold
      say 'Running platform detection...'
      __detect

      # History persistence (TODO: Extract)
      user_conf_dir = File.join(ENV['HOME'], TrainSH::USER_CONF_DIR)
      history_file = File.join(user_conf_dir, 'history')
      FileUtils.mkdir_p(user_conf_dir)
      FileUtils.touch(history_file)
      File.readlines(history_file).each { |line| Readline::HISTORY.push line.strip }
      at_exit {
        history_file = File.join(user_conf_dir, 'history')
        File.open(history_file, 'w') { |f|
          f.write Readline::HISTORY.to_a.join("\n")
        }
      }

      # Catch Ctrl-C and exit cleanly
      stty_save = `stty -g`.chomp
      trap('INT') do
        puts '^C'
        system('stty', stty_save)
        exit
      end

      # Autocompletion
      Readline.completion_proc = method(:auto_complete).to_proc
      Readline.completion_append_character = ' '

      while (input = Readline.readline(prompt, true))
        if input.empty?
          Readline::HISTORY.pop
          next
        end

        Readline::HISTORY.pop if input.start_with? '!history'

        break if exit_command? input
        next if interactive_command? input

        execute input
      end
    end

    # desc 'copy FILE/DIR|URL FILE/DIR|URL', 'Copy files or directories'
    # def copy(url_or_file, url_or_file)
    #   # TODO?
    # end

    desc 'detect URL', 'Retrieve remote OS and platform information'
    long_desc <<~DESC
      Detect remote OS via Train. Uses the same schema as URLs for `connect`.
    DESC
    def detect(url)
      exit unless use_session(url)
      __detect
    end

    # desc 'exec URL -- (COMMAND)', 'Execute remote commands'
    # method_option :file, aliases: '-f', desc: "command file to read"
    # def exec
    #   # TODO
    #   # TODO: Also accept getting commands from STDIN and from a file
    # end

    desc 'list-transports', 'List available transports'
    def list_transports
      # TODO: Train only lazy-loads and does not have a full registry
      #       https://github.com/inspec/train/blob/be90ca53ea1c1e8aa7439c504fbee86f4b399d83/lib/train.rb#L38-L61

      # TODO: Filter for only "OS" transports as well
      transports = %w[local ssh winrm docker]

      say "Available transports: #{transports.sort.join(', ')}"
    end
  end
end
