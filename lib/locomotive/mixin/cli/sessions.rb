require_relative '../../session'

module LocomotiveCli
  module Sessions
    def use_session(url)
      @sessions = [] if @sessions.nil?

      existing_id = @sessions.index { |session| session.url == url }

      if existing_id.nil?
        @current_session_id = @sessions.count
        @sessions << Locomotive::Session.new(url)
      else
        @current_session_id = existing_id
      end
    rescue Train::PluginLoadError
      say format('No Train plugin found for url %<url>s', url: url)
    end

    def session(session_id = current_session_id)
      @sessions[session_id]
    end

    # ?
    def sessions
      (0..@sessions.count - 1).to_a
    end

    def current_session_id
      @current_session_id ||= 0
    end

    def validate_session_id(session_id)
      unless session_id.match?(/^[0-9]+$/)
        say 'Expected session id to be numeric'.red
        return
      end

      if @sessions[session_id.to_i].nil?
        say format('No session id [%s] found', session_id).red
        return
      end

      session_id.to_i
    end
  end
end
