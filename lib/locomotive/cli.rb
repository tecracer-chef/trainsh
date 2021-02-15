require_relative '../locomotive'
require_relative 'session'

require_relative 'mixin/cli/builtin_commands'
require_relative 'mixin/cli/file_helpers'
require_relative 'mixin/cli/sessions'

# TODO
# require_relative 'detectors/target/env.rb'
# require_relative 'detectors/target/kitchen.rb'

require 'colored'
require 'readline'
require 'train'
require 'thor'

module Locomotive
  class Cli < Thor
    include Thor::Actions
    check_unknown_options!
    # add_runtime_options!

    def self.exit_on_failure?
      true
    end

    map %w[version] => :__print_version
    desc 'version', 'Display version'
    def __print_version
      say "#{Locomotive::PRODUCT} #{Locomotive::VERSION} (Ruby #{RUBY_VERSION}-#{RUBY_PLATFORM})"
    end

    EXIT_COMMANDS = %w[!!! exit quit logout disconnect].freeze
    INTERACTIVE_COMMANDS = %w[more less vi vim nano].freeze

    no_commands do
      include LocomotiveCli::BuiltInCommands
      include LocomotiveCli::FileHelpers
      include LocomotiveCli::Sessions

      def __disconnect
        session.close

        say 'Disconnected'
      end

      # TODO
      # def __detect_url(url)
      #   url || kitchen_url || ENV['target']
      # end

      def __detect
        platform = session.platform

        say format('Platform: %<title>s %<release>s (%<arch>s)',
                   title:   platform.title,
                   release: platform.release,
                   arch:    platform.arch)
        say format('Hierarchy: %<hierarchy>s',
                   hierarchy: platform.family_hierarchy.reverse.join('/'))
      end

      def target_detectors
        Dir[File.join(__dir__, 'lib', '*.rb')].sort.each { |file| require file }

        Locomotive::Detectors::TargetDetector.descendants
      end

      def execute(input)
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

        # TODO: Set last path
        # TODO: Get path after
        # TODO: Not open a new shell each time, but "append" (Env vars, Path etc)

        command_result = @sessions[session_id].run_command(input)

        say command_result.stdout unless command_result.stdout.empty?
        say command_result.stderr.red if command_result.exit_status != 0
      end

      def execute_builtin(input)
        cmd, *args = input.split(' ')

        if builtin_commands.include? cmd
          send("#{BUILTIN_PREFIX}#{cmd}".to_sym, *args)
        else
          say format('Unknown built-in "%<cmd>s"', cmd: cmd)
        end
      end

      def execute_via_session(input)
        session_id, *data = input.split(' ')

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
        format('locomotive(%<session_id>d: %<backend>s)> '.green,
               session_id: current_session_id,
               backend:    session&.backend_type || '<none>')
      end

      def auto_complete(partial)
        choices = []

        choices.concat(builtin_commands.map { |cmd| "!#{cmd}" })
        choices.concat(sessions.map { |session_id| "@#{session_id}" })
        choices.concat %w[!!!]

        choices.filter { |choice| choice.start_with? partial }
      end
    end

    desc 'connect URL', 'Connect to a destination interactively'
    def connect(url)
      use_session(url)

      say format('Connected to %<url>s', url: url).bold
      __detect

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
    def detect(url)
      use_session(url)
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
