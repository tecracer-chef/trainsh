require 'train/errors'

module TrainSH
  module Mixin
    module BuiltInCommands
      BUILTIN_PREFIX = 'builtincmd_'.freeze
      SESSION_PATH_REGEX = %r{(/@(\d+):(/.*)$/)}.freeze

      def builtin_commands
        methods.sort.filter { |method| method.to_s.start_with? BUILTIN_PREFIX }.map { |method| method.to_s.delete_prefix BUILTIN_PREFIX }
      end

      def builtincmd_clear_history(_args = nil)
        Readline::HISTORY.clear
      end

      def builtincmd_connect(url = nil)
        if url.nil? || url.strip.empty?
          show_error 'Expecting session url, e.g. `!connect docker://123456789abcdef0`'
          return false
        end

        use_session(url)
      end

      def builtincmd_copy(src = nil, dst = nil)
        src_id, src_path = src&.match(SESSION_PATH_REGEX)&.captures
        dst_id, dst_path = dst&.match(SESSION_PATH_REGEX)&.captures
        unless src && dst && src_id && dst_id && src_path && dst_path
          show_error 'Expecting source and destination, e.g. `!copy @0:/etc/hosts @1:/home/ubuntu/old_hosts'
          return
        end

        src_session = session(src_id)
        dst_session = session(dst_id)
        unless src_session && dst_session
          show_error 'Expecting valid session identifiers. Check available sessions via !sessions'
          return
        end

        content = src_session.file(src_path)
        dst_session.file(dst_path).content = content

        show_message "Copied #{content.size} bytes successfully"
      end

      def builtincmd_detect(_args = nil)
        __detect
      end

      def builtincmd_download(remote_path = nil, local_path = nil)
        if remote_path.nil? || local_path.nil?
          show_error 'Expecting remote path and local path, e.g. `!download /etc/passwd /home/ubuntu`'
          return false
        end

        return unless train_mutable?

        session.download(remote_path, local_path)

        show_message "Downloaded #{remote_path} successfully"
      rescue NotImplementedError
        show_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        show_error "Error occured: #{e.message}"
      end

      def builtincmd_edit(path = nil)
        if path.nil? || path.strip.empty?
          show_error 'Expecting remote path, e.g. `!less /tmp/somefile.txt`'
          return false
        end

        tempfile = read_file(path)
        old_content = File.read(tempfile.path)

        localeditor = ENV['EDITOR'] || ENV['VISUAL'] || 'vi' # TODO: configuration, Windows, ...
        show_message format('Using local editor `%<editor>s` for %<tempfile>s', editor: localeditor, tempfile: tempfile.path)

        system("#{localeditor} #{tempfile.path}")
        new_content = File.read(tempfile.path)

        if new_content == old_content
          show_message 'No changes detected'
        else
          write_file(path, new_content)

          show_message "Wrote #{new_content.size} bytes successfully"
        end

        tempfile.unlink
      rescue NotImplementedError
        show_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        show_error "Error occured: #{e.message}"
      end

      def builtincmd_env(_args = nil)
        puts session.env
      end

      def builtincmd_help(_args = nil)
        show_message <<~HELP
          Unprefixed commands get sent to the remote host of the active session.

          Commands with a prefix of `@n` with n being a number will be executed on the specified session. For a list of sessions check `!sessions`.

          Commands with a prefix of `.` get executed locally.

          Builtin commands are prefixed with `!`:
        HELP

        builtin_commands.each { |cmd| show_message " !#{cmd}" }
      end

      def builtincmd_read(path = nil)
        if path.nil? || path.strip.empty?
          show_error 'Expecting remote path, e.g. `!read /tmp/somefile.txt`'
          return false
        end

        tempfile = read_file(path)
        return false unless tempfile

        localpager = ENV['PAGER'] || 'less' # TODO: configuration, Windows, ...
        show_message format('Using local pager `%<pager>s` for %<tempfile>s', pager: localpager, tempfile: tempfile.path)
        system("#{localpager} #{tempfile.path}")

        tempfile.unlink
      rescue NotImplementedError
        show_error 'Backend for session does not implement file operations'
      rescue StandardError => e
        show_error "Error occured: #{e.message}"
      end

      def builtincmd_history(_args = nil)
        puts Readline::HISTORY.to_a
      end

      def builtincmd_host(_args = nil)
        show_message session.host
      end

      def builtincmd_ping(_args = nil)
        session.run_idle

        show_message format('Ping: %<ping>dms', ping: session.ping)
      end

      # rubocop:disable Lint/Debugger
      def builtincmd_pry(_args = nil)
        require 'pry' unless defined?(binding.pry)
        binding.pry
      end
      # rubocop:enable Lint/Debugger

      def builtincmd_pwd(_args = nil)
        show_message session.pwd
      end

      def builtincmd_reconnect(_args = nil)
        session.reconnect
      end

      def builtincmd_sessions(_args = nil)
        show_message 'Active sessions:'

        @sessions.each_with_index do |session, idx|
          show_message format('[%<idx>d] %<session>s', idx: idx, session: session.url)
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
          show_error 'Expecting remote path and local path, e.g. `!download /home/ubuntu/passwd /etc'
          return false
        end

        return unless train_mutable?

        session.upload(local_path, remote_path)

        show_message "Uploaded to #{remote_path} successfully"
      rescue ::Errno::ENOENT
        show_error "Local file/directory '#{local_path}' does not exist"
      rescue NotImplementedError
        show_error 'Backend for session does not implement upload operation'
      rescue StandardError => e
        show_error "Error occured: #{e.message}"
      end

      private

      def train_mutable?
        return true if session.respond_to?(:upload)

        show_error "Support for remote file modification needs at least Train #{::TrainSH::TRAIN_MUTABLE_VERSION} (is: #{::Train::VERSION})"
      end
    end
  end
end
