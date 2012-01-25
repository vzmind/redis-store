require 'rack/session/abstract/id'
require 'redis-store'

module Rack
  module Session
    class Redis < Abstract::ID
      attr_reader :mutex, :pool

      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge \
        :namespace    => 'rack:session',
        :redis_server => 'redis://redistogo:185b559a81a42687a85960f519105496@guppy.redistogo.com:9253'

      def initialize(app, options = {})
        super

        @mutex = Mutex.new
        options[:redis_server] ||= @default_options[:redis_server]
        @pool = ::Redis::Factory.create options[:redis_server]
      end

      def generate_sid
        loop do
          sid = super
          break sid unless @pool.get(sid)
        end
      end

      def get_session(env, sid)
        with_lock(env, [nil, {}]) do
          unless sid and session = @pool.get(sid)
            sid, session = generate_sid, {}
            unless /^OK/ =~ @pool.set(sid, session)
              raise "Session collision on '#{sid.inspect}'"
            end
          end
          [sid, session]
        end
      end

      def set_session(env, session_id, new_session, options)
        expiry = options[:expire_after].to_i
        with_lock(env, false) do
          if expiry.zero?
            @pool.set session_id, new_session
          else
            @pool.setex session_id, (expiry + 1), new_session
          end

          session_id
        end
      end

      def destroy_session(env, session_id, options)
        with_lock(env) do
          @pool.del(session_id)
          generate_sid unless options[:drop]
        end
      end

      def with_lock(env, default=nil)
        @mutex.lock if env['rack.multithread']
        yield
      rescue Errno::ECONNREFUSED
        if $VERBOSE
          warn "#{self} is unable to find Redis server."
          warn $!.inspect
        end
        default
      ensure
        @mutex.unlock if @mutex.locked?
      end

    end
  end
end

