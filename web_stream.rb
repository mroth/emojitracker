require_relative 'lib/config'
require 'sinatra/base'
require 'delegate'
require 'oj'
require 'eventmachine'

##############################################################
# configure defaults around forced SSE timeouts and the like
##############################################################
def to_boolean(s)
  s and !!s.match(/^(true|t|yes|y|1)$/i)
end

SSE_FORCE_REFRESH = to_boolean(ENV['SSE_FORCE_REFRESH'] || 'true')
SSE_SCORE_RETRY_MS        = ENV['SSE_SCORE_RETRY_MS']        || 100
SSE_DETAIL_RETRY_MS       = ENV['SSE_DETAIL_RETRY_MS']       || 500
SSE_SCORE_FORCECLOSE_SEC  = ENV['SSE_SCORE_FORCECLOSE_SEC']  || 60
SSE_DETAIL_FORCECLOSE_SEC = ENV['SSE_DETAIL_FORCECLOSE_SEC'] || 120

################################################
# stream object wrapper
#
# handles sending common SSE data, and keeps track of stream age
# pass a request object to instantiate some metadata about the stream client
################################################
class WrappedStream < DelegateClass(Sinatra::Helpers::Stream)
  def initialize(wrapped_stream, request=nil)
    @created_at = Time.now.to_i

    init_client_stats(request)

    super(wrapped_stream)
  end

  def init_client_stats(request)
    unless request.nil?
      @client_ip = request.ip
      @client_user_agent = request.user_agent
    end
  end

  # Returns age of stream in seconds as Integer.
  def age
    Time.now.to_i - @created_at
  end

  def sse_set_retry(ms)
    self << "retry:#{ms}\n\n"
  end

  def sse_data(data)
    self << "data:#{data}\n\n"
  end

  def sse_event_data(event,data)
    self << "event:#{event}\ndata:#{data}\n\n"
  end
end

################################################
# streaming thread for score updates (main page)
################################################
class WebScoreRawStreamer < Sinatra::Base
  set :connections, []

  get '/raw' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      out = WrappedStream.new(out, request)
      out.sse_set_retry(SSE_SCORE_RETRY_MS) if SSE_FORCE_REFRESH
      settings.connections << out
      out.callback { settings.connections.delete(out) }
      if SSE_FORCE_REFRESH then EM.add_timer(SSE_SCORE_FORCECLOSE_SEC) { out.close } end
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.score_updates') do |on|
      on.pmessage do |match, channel, message|
        connections.each do |out|
          out.sse_data(message)
        end
      end
    end
  end

end

################################################
# 60 events per second rollup streaming thread for score updates
################################################
class WebScoreCachedStreamer < Sinatra::Base

  set :connections, []
  cached_scores = {}
  semaphore = Mutex.new

  get '/eps' do
    content_type 'text/event-stream'
    stream(:keep_open) do |conn|
      conn = WrappedStream.new(conn, request)
      conn.sse_set_retry(SSE_SCORE_RETRY_MS) if SSE_FORCE_REFRESH
      settings.connections << conn
      puts "STREAM: new eps_stream connection opened for #{request.ip}" if VERBOSE
      conn.callback do
        puts "STREAM: eps_stream connection closed for #{request.ip}" if VERBOSE
        settings.connections.delete(conn)
      end
      if SSE_FORCE_REFRESH then EM.add_timer(SSE_SCORE_FORCECLOSE_SEC) { conn.close } end
    end
  end

  Thread.new do
    scores = {}
    while true
      semaphore.synchronize do
        scores = cached_scores.clone
        cached_scores.clear
      end

      connections.each do |out|
        out.sse_data(Oj.dump scores) unless scores.empty?
      end

      sleep 0.017 #60fps
    end
  end


  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.score_updates') do |on|
      on.pmessage do |match, channel, message|
        semaphore.synchronize do
          cached_scores[message] ||= 0
          cached_scores[message] += 1
        end
      end
    end

  end

end

################################################
# streaming thread for tweet updates (detail pages)
################################################
class WebDetailStreamer < Sinatra::Base
  class TaggedStream
    attr_reader :out, :tag
    def initialize(out,tag=nil)
      @out = out
      @tag = tag
    end
  end

  set :connections, []
  get '/details/:char' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      out = WrappedStream.new(out, request)
      out.sse_set_retry(SSE_DETAIL_RETRY_MS) if SSE_FORCE_REFRESH
      ts = TaggedStream.new(out, params[:char])
      settings.detail_conns << ts
      puts "STREAM: new detailstream connection for #{ts.tag} from #{request.ip}" if VERBOSE
      out.callback do
        puts "STREAM: detailstream connection closed for #{ts.tag} from #{request.ip}" if VERBOSE
        settings.connections.delete(ts)
      end
      if SSE_FORCE_REFRESH then EM.add_timer(SSE_DETAIL_FORCECLOSE_SEC) { out.close } end
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.tweet_updates.*') do |on|
      on.pmessage do |match, channel, message|
        channel_id = channel.split('.')[2] #TODO: perf profile this versus a regex later
        connections.select { |c| c.tag == channel_id}.each do |ts|
          ts.out.sse_event_data(channel, message)
        end
      end
    end
  end

end


################################################
# main master class for the app
################################################
class WebStreamer < Sinatra::Base
  use WebScoreRawStreamer
  use WebScoreCachedStreamer
  use WebDetailStreamer

  # graphite logging for all the streams
  @stream_graphite_log_rate = 10
  EM.next_tick do
    EM::PeriodicTimer.new(@stream_graphite_log_rate) do
      graphite_dyno_log("stream.raw.clients", WebScoreRawStreamer.connections.count)
      graphite_dyno_log("stream.eps.clients", WebScoreCachedStreamer.connections.count)
      graphite_dyno_log("stream.detail.clients", WebDetailStreamer.connections.count)
    end
  end

end
