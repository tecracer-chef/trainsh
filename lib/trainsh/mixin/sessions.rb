require_relative '../session'

module TrainSH
  module Mixin
    module Sessions
      def use_session(url)
        @sessions = [] if @sessions.nil?

        existing_id = @sessions.index { |session| session.url == url }

        if existing_id.nil?
          @current_session_id = @sessions.count
          @sessions << TrainSH::Session.new(url)
        else
          @current_session_id = existing_id
        end
      rescue Train::PluginLoadError
        say format('No Train plugin found for url %<url>s', url: url).red
        nil
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

      def current_session
        @sessions[current_session_id]
      end

      def validate_session_id(session_id)
        unless session_id
          say 'Expecting valid session id, e.g. `!session 2`'.red
          return
        end

        unless session_id.match?(/^[0-9]+$/)
          say 'Expected session id to be numeric'.red
          return
        end

        if @sessions[session_id.to_i].nil?
          say 'Expecting valid session id, e.g. `!session 2`'.red

          say "\nActive sessions:"
          @sessions.each_with_index { |data, idx| say "[#{idx}] #{data.url}" }
          say

          return
        end

        session_id.to_i
      end
    end
  end
end
