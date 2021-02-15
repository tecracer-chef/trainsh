require 'train/errors'

module LocomotiveCli
  module BuiltInCommands
    BUILTIN_PREFIX = 'builtincmd_'.freeze

    def builtin_commands
      methods.sort.filter { |method| method.to_s.start_with? BUILTIN_PREFIX }.map { |method| method.to_s.delete_prefix BUILTIN_PREFIX }
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

    def builtincmd_detect(_args = nil)
      __detect
    end

    def builtincmd_download(remote_path = nil, local_path = nil)
      if remote_path.nil? || local_path.nil?
        say 'Expecting remote path and local path, e.g. `!download /etc/passwd /home/ubuntu`'
        return false
      end

      return unless train_mutable?

      session.download(remote_path, local_path)

    rescue ::Train::NotImplementedError
      say 'Backend for session does not implement download operation'.red
    end

    def builtincmd_edit(path = nil)
      if path.nil? || path.strip.empty?
        say 'Expecting remote path, e.g. `!less /tmp/somefile.txt`'.red
        return false
      end

      tempfile = read_file(path)

      localeditor = ENV["EDITOR"] || ENV["VISUAL"] || "vi" # TODO: configuration, Windows, ...
      say format('Using local editor `%<editor>s` for %<tempfile>s', editor: localeditor, tempfile: tempfile.path)

      system("#{localeditor} #{tempfile.path}")

      new_content = File.read(tempfile.path)

      write_file(path, new_content)
      tempfile.unlink
    rescue ::Train::NotImplementedError
      say 'Backend for session does not implement file operations'.red
    end

    def builtincmd_env(_args = nil)
      session.run_idle unless session.env

      puts session.env
    end

    def builtincmd_read(path = nil)
      if path.nil? || path.strip.empty?
        say 'Expecting remote path, e.g. `!read /tmp/somefile.txt`'.red
        return false
      end

      tempfile = read_file(path)
      return false unless tempfile

      localpager = ENV["PAGER"] || "less" # TODO: configuration, Windows, ...
      say format('Using local pager `%<pager>s` for %<tempfile>s', pager: localpager, tempfile: tempfile.path)
      system("#{localpager} #{tempfile.path}")

      tempfile.unlink
    rescue ::NotImplementedError
      say 'Backend for session does not implement file operations'.red
    end

    def builtincmd_history(_args = nil)
      puts Readline::HISTORY.to_a
    end

    def builtincmd_pwd(_args = nil)
      session.run_idle unless session.pwd

      puts session.pwd
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

      if session_id.nil?
        say 'Expecting valid session id, e.g. `!session 2`'.red
        return false
      end

      # TODO: Make this more pretty
      session_url = @sessions[session_id].url

      use_session(session_url)
    end

    def builtincmd_upload(local_path = nil, remote_path = nil)
      if remote_path.nil? || local_path.nil?
        say 'Expecting remote path and local path, e.g. `!download /home/ubuntu/passwd /etc`'
        return false
      end

      return unless train_mutable?

      session.upload(local_path, remote_path)

    rescue ::Errno::ENOENT
      say "Local file/directory '#{local_path}' does not exist".red
    rescue ::NotImplementedError
      say 'Backend for session does not implement upload operation'.red
    end

    private

    def train_mutable?
      return true if !session.respond_to?(:upload)

      say "Support for remote file modification needs at least Train #{::Locomotive::TRAIN_MUTABLE_VERSION} (is: #{::Train::VERSION})".red
    end
  end
end
