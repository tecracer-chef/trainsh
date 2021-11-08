require 'train/errors'

module TrainSH
  module Mixin
    module BuiltInCommands
      BUILTIN_PREFIX = 'builtincmd_'.freeze

      def builtin_commands
        methods.sort.filter { |method| method.to_s.start_with? BUILTIN_PREFIX }.map { |method| method.to_s.delete_prefix BUILTIN_PREFIX }
      end

      def clean_error(message)
        say message.red
        session.exitcode = -1
      end

      def builtincmd_clear_history(_args = nil)
        Readline::HISTORY.clear
      end

      def builtincmd_connect(url = nil)
        if url.nil? || url.strip.empty?
          say 'Expecting session url, e.g. `!connect docker://123456789abcdef0`'.red
          return false
        end

        use_session(url)
      end

      # def builtincmd_copy(source = nil, destination = nil)
      #   # TODO: Copy files between sessions
      # end

      def builtincmd_help(_args = nil)
        say <<~HELP
          Unprefixed commands get sent to the remote host of the active session.

          Commands with a prefix of `@n` with n being a number will be executed on the specified session. For a list of sessions check `!sessions`.

          Commands with a prefix of `.` get executed locally.

          Builtin commands are prefixed with `!`:
        HELP

        builtin_commands.each { |cmd| say " !#{cmd}" }
      end

      def builtincmd_detect(_args = nil)
        __detect
      end

      # rubocop:disable Lint/Debugger
      def builtincmd_pry(_args = nil)
        require 'pry' unless defined?(binding.pry)
        binding.pry
      end
      # rubocop:enable Lint/Debugger

      def builtincmd_download(remote_path = nil, local_path = nil)
        if remote_path.nil? || local_path.nil?
          say 'Expecting remote path and local path, e.g. `!download /etc/passwd /home/ubuntu`'
          return false
        end

        return unless train_mutable?

        session.download(remote_path, local_path)
      rescue NotImplementedError
        clean_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        clean_error "Error occured: #{e.message}"
      end

      def builtincmd_edit(path = nil)
        if path.nil? || path.strip.empty?
          say 'Expecting remote path, e.g. `!less /tmp/somefile.txt`'.red
          return false
        end

        tempfile = read_file(path)

        localeditor = ENV['EDITOR'] || ENV['VISUAL'] || 'vi' # TODO: configuration, Windows, ...
        say format('Using local editor `%<editor>s` for %<tempfile>s', editor: localeditor, tempfile: tempfile.path)

        system("#{localeditor} #{tempfile.path}")

        new_content = File.read(tempfile.path)

        write_file(path, new_content)
        tempfile.unlink
      rescue NotImplementedError
        clean_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        clean_error "Error occured: #{e.message}"
      end

      def builtincmd_env(_args = nil)
        puts session.env
      end

      def builtincmd_read(path = nil)
        if path.nil? || path.strip.empty?
          clean_error 'Expecting remote path, e.g. `!read /tmp/somefile.txt`'
          return false
        end

        tempfile = read_file(path)
        return false unless tempfile

        localpager = ENV['PAGER'] || 'less' # TODO: configuration, Windows, ...
        say format('Using local pager `%<pager>s` for %<tempfile>s', pager: localpager, tempfile: tempfile.path)
        system("#{localpager} #{tempfile.path}")

        tempfile.unlink
      rescue NotImplementedError
        clean_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        clean_error "Error occured: #{e.message}"
      end

      def builtincmd_history(_args = nil)
        puts Readline::HISTORY.to_a
      end

      def builtincmd_host(_args = nil)
        say session.host
      end

      def builtincmd_ping(_args = nil)
        session.run_idle
        say format('Ping: %<ping>dms', ping: session.ping)
      end

      def builtincmd_pwd(_args = nil)
        say session.pwd
      end

      def builtincmd_reconnect(_args = nil)
        session.reconnect
      end

      def builtincmd_sessions(_args = nil)
        say 'Active sessions:'

        @sessions.each_with_index do |session, idx|
          say format('[%<idx>d] %<session>s', idx: idx, session: session.url)
        end
      end

      def builtincmd_session(session_id = nil)
        session_id = validate_session_id(session_id)
        return if session_id.nil?

        # TODO: Make this more pretty
        session_url = @sessions[session_id].url

        use_session(session_url)
      end

      def builtincmd_upload(local_path = nil, remote_path = nil)
        if remote_path.nil? || local_path.nil?
          clean_error 'Expecting remote path and local path, e.g. `!download /home/ubuntu/passwd /etc'
          return false
        end

        return unless train_mutable?

        session.upload(local_path, remote_path)
      rescue ::Errno::ENOENT
        clean_error "Local file/directory '#{local_path}' does not exist"
      rescue NotImplementedError
        clean_error 'Backend for session does not implement upload operation'
      rescue StandardError => e
        clean_error "Error occured: #{e.message}"
      end

      private

      def train_mutable?
        return true if session.respond_to?(:upload)

        say "Support for remote file modification needs at least Train #{::TrainSH::TRAIN_MUTABLE_VERSION} (is: #{::Train::VERSION})".red
      end
    end
  end
end
