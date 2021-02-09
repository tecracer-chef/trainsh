module LocomotiveCli
  module BuiltInCommands
    BUILTIN_PREFIX = 'builtincmd_'.freeze

    def builtin_commands
      methods.sort.filter { |method| method.to_s.start_with? BUILTIN_PREFIX }.map { |method| method.to_s.delete_prefix BUILTIN_PREFIX }
    end

    def builtincmd_connect(url = nil)
      if url.nil? || url.strip.empty?
        say 'Expecting session url, e.g. `!connect docker://123456789abcdef0`'.red
        return false
      end

      use_session(url)
    end

    def builtincmd_detect(_args = nil)
      __detect
    end

    def builtincmd_history(_args = nil)
      puts Readline::HISTORY.to_a
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

      # TODO: Seems weird
      session_url = @sessions[session_id].url

      use_session(session_url)
    end
  end
end
