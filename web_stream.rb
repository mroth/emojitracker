require 'sinatra/base'
require 'oj'
require 'eventmachine'
require_relative 'lib/config'
require_relative 'lib/wrapped_stream'

##############################################################
# configure defaults around forced SSE timeouts and the like
##############################################################
def to_boolean(s)
  s and !!s.match(/^(true|t|yes|y|1)$/i)
end

SSE_FORCE_REFRESH = to_boolean(ENV['SSE_FORCE_REFRESH'] || 'false')
SSE_SCORE_RETRY_MS        = ENV['SSE_SCORE_RETRY_MS']        || 100
SSE_DETAIL_RETRY_MS       = ENV['SSE_DETAIL_RETRY_MS']       || 500
SSE_SCORE_FORCECLOSE_SEC  = ENV['SSE_SCORE_FORCECLOSE_SEC']  || 300
SSE_DETAIL_FORCECLOSE_SEC = ENV['SSE_DETAIL_FORCECLOSE_SEC'] || 300

ENABLE_RAW_STREAM = to_boolean(ENV['ENABLE_RAW_STREAM'] || 'true')

################################################
# convenience method for stream connect logging
################################################
def log_connect(stream_obj)
  puts "STREAM: connect for #{stream_obj.request_path} from #{request.ip}" if VERBOSE
  REDIS.PUBLISH 'stream.admin.connect', stream_obj.to_json
end

def log_disconnect(stream_obj)
  puts "STREAM: disconnect for #{stream_obj.request_path} from #{request.ip}" if VERBOSE
  REDIS.PUBLISH 'stream.admin.disconnect', stream_obj.to_json
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
      log_connect(out)
      out.callback { log_disconnect(out); settings.connections.delete(out) }
      if SSE_FORCE_REFRESH then EM.add_timer(SSE_SCORE_FORCECLOSE_SEC) { out.close } end
    end
  end

  #allow raw stream to be disabled since we arent using it for anything official now and will save on redis connections
  if ENABLE_RAW_STREAM
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
      log_connect(conn)
      conn.callback do
        log_disconnect(conn)
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

  set :connections, []

  get '/details/:char' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      tag = params[:char]
      out = WrappedStream.new(out, request, tag)
      out.sse_set_retry(SSE_DETAIL_RETRY_MS) if SSE_FORCE_REFRESH
      settings.connections << out
      log_connect(out)
      out.callback do
        log_disconnect(out)
        settings.connections.delete(out)
      end
      if SSE_FORCE_REFRESH then EM.add_timer(SSE_DETAIL_FORCECLOSE_SEC) { out.close } end
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.tweet_updates.*') do |on|
      on.pmessage do |match, channel, message|
        channel_id = channel.split('.')[2] #TODO: perf profile this versus a regex later
        connections.select { |c| c.match_tag?(channel_id) }.each do |conn|
          conn.sse_event_data(channel, message)
        end
      end
    end
  end

end

################################################
# admin stuff
################################################
class WebStreamerAdmin < Sinatra::Base

  get '/admin' do
    slim :stream_admin
  end

  get '/admin/data.json' do
    content_type :json
    Oj.dump(
      {
        'stream_raw_clients' => WebScoreRawStreamer.connections.map(&:to_hash),
        'stream_eps_clients' => WebScoreCachedStreamer.connections.map(&:to_hash),
        'stream_detail_clients' => WebDetailStreamer.connections.map(&:to_hash),
        'stream_admin_clients' => WebStreamerAdmin.connections.map(&:to_hash)
      }
    )
  end

  set :connections, []
  get '/admin/updates.sse' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      out = WrappedStream.new(out, request)
      settings.connections << out
      log_connect(out)
      out.callback { log_disconnect(out); settings.connections.delete(out) }

      EM.add_periodic_timer(30) { out.sse_data('.') } #ghetto keepalive TODO: do me the right way
      if SSE_FORCE_REFRESH then EM.add_timer(300) { out.close } end
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.admin.*') do |on|
      on.pmessage do |match, channel, message|
        admin_event = channel.split('.')[2]
        connections.each {|out| out.sse_event_data(admin_event, message)}
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
  use WebStreamerAdmin

  # cleanup methods for force a stream disconnect on servers like heroku where server cant detect it :(
  post '/cleanup/scores' do
    puts "CLEANUP: force scores disconnect for #{request.ip}" if VERBOSE
    matched_conns = WebScoreCachedStreamer.connections.select { |conn| conn.client_ip == request.ip }
    matched_conns.each(&:close)
    content_type :json
    Oj.dump( { 'status' => 'OK', 'closed' => matched_conns.count } )
  end

  post '/cleanup/details/:id' do
    id = params[:id]
    puts "CLEANUP: force details #{id} disconnect for #{request.ip}" if VERBOSE
    matched_conns = WebDetailStreamer.connections.select { |conn| conn.client_ip == request.ip  && conn.tag == id}
    matched_conns.each(&:close)
    content_type :json
    Oj.dump( { 'status' => 'OK', 'closed' => matched_conns.count } )
  end

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
