require 'sinatra/base'
require 'oj'
require 'eventmachine'
require_relative 'lib/config'
require_relative 'lib/wrapped_stream'

##############################################################
# configure defaults around forced SSE timeouts and the like
##############################################################
SSE_SCORE_RETRY_MS        = ENV['SSE_SCORE_RETRY_MS']        || 100
SSE_DETAIL_RETRY_MS       = ENV['SSE_DETAIL_RETRY_MS']       || 500
SSE_SCORE_FORCECLOSE_SEC  = ENV['SSE_SCORE_FORCECLOSE_SEC']  || 300
SSE_DETAIL_FORCECLOSE_SEC = ENV['SSE_DETAIL_FORCECLOSE_SEC'] || 300

SSE_FORCE_REFRESH               = to_boolean(ENV['SSE_FORCE_REFRESH']               || 'false')
ENABLE_RAW_STREAM               = to_boolean(ENV['ENABLE_RAW_STREAM']               || 'true')
ENABLE_KIOSK_INTERACTION_STREAM = to_boolean(ENV['ENABLE_KIOSK_INTERACTION_STREAM'] || 'false')

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
# streaming thread for kiosk interaction
################################################
class WebKioskInteractionStreamer < Sinatra::Base

  set :connections, []

  get '/kiosk_interaction' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      out = WrappedStream.new(out, request)
      settings.connections << out
      log_connect(out)
      out.callback { log_disconnect(out); settings.connections.delete(out) }
    end
  end

  if ENABLE_KIOSK_INTERACTION_STREAM
    Thread.new do
      puts "SUBSCRIBING TO KIOSK INTERACTIVE STREAM YO"
      t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
      t_redis.psubscribe('stream.interaction.*') do |on|
        on.pmessage do |match, channel, message|
          puts "DEBUG: streamer received interaction request from redis" #TODO: REMOVE ME******
          connections.each do |out|
            out.sse_event_data(channel, message)
          end
        end
      end
    end
  end

end

################################################
# admin stuff
################################################

class WebStreamerReporting < Sinatra::Base

  module ReportingUtils
    STREAM_STATUS_REDIS_KEY = 'admin_stream_status'
    STREAM_STATUS_UPDATE_RATE = 5

    def self.current_status
      {
        'node'        => self.node_name,
        'reported_at' => Time.now.to_i,
        'connections' => {
          'stream_raw'    => WebScoreRawStreamer.connections.map(&:to_hash),
          'stream_eps'    => WebScoreCachedStreamer.connections.map(&:to_hash),
          'stream_detail' => WebDetailStreamer.connections.map(&:to_hash)
        }
      }
    end

    def self.node_name
      @node_name ||= 'mri-' + ENV['RACK_ENV'] + '-' + (ENV['DYNO'] || 'unknown')
    end

    def self.push_node_status_to_redis
      REDIS.HSET STREAM_STATUS_REDIS_KEY, self.node_name, Oj.dump(self.current_status)
    end

  end

  # periodically log the updates
  EM.next_tick do
    EM.add_periodic_timer(ReportingUtils::STREAM_STATUS_UPDATE_RATE) do
      ReportingUtils.push_node_status_to_redis
    end
  end

  helpers ReportingUtils

  get '/admin/?' do
    redirect '/admin/', 301
  end

  get '/admin/node.json' do
    content_type :json
    Oj.dump ReportingUtils.current_status
  end

end

################################################
# main master class for the app
################################################
class WebStreamer < Sinatra::Base
  use WebKioskInteractionStreamer if ENABLE_KIOSK_INTERACTION_STREAM
  use WebScoreRawStreamer         if ENABLE_RAW_STREAM
  use WebScoreCachedStreamer
  use WebDetailStreamer
  use WebStreamerReporting

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

  @stream_graphite_log_rate = 10
  EM.next_tick do
    # graphite logging for all the streams
    EM::PeriodicTimer.new(@stream_graphite_log_rate) do
      graphite_dyno_log("stream.raw.clients",     WebScoreRawStreamer.connections.count)
      graphite_dyno_log("stream.eps.clients",     WebScoreCachedStreamer.connections.count)
      graphite_dyno_log("stream.detail.clients",  WebDetailStreamer.connections.count)
    end
  end

end
