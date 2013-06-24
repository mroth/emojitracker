require_relative 'lib/config'
require 'sinatra/base'
require 'sinatra/streaming'
require 'oj'
require 'eventmachine'

################################################
# streaming thread for score updates (main page)
################################################
class WebScoreRawStreamer < Sinatra::Base
  set :raw_conns, []

  get '/raw' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      settings.raw_conns << out
      out.callback { settings.raw_conns.delete(out) }
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.score_updates') do |on|
      on.pmessage do |match, channel, message|
        raw_conns.each do |out|
          # out << "event: #{channel}\n"
          out << "data:#{message}\n\n"
        end
      end
    end
  end

end

################################################
# 60 events per second rollup streaming thread for score updates
################################################
class WebScoreCachedStreamer < Sinatra::Base

  set :eps_conns, []
  cached_scores = {}
  semaphore = Mutex.new

  get '/eps' do
    content_type 'text/event-stream'
    stream(:keep_open) do |conn|
      settings.eps_conns << conn
      puts "STREAM: new eps_stream connection opened from #{request.ip}" if VERBOSE
      conn.callback do
        puts "STREAM: eps_stream connection closed from #{request.ip}" if VERBOSE
        settings.eps_conns.delete(conn)
      end
    end
  end

  Thread.new do
    scores = {}
    while true
      semaphore.synchronize do
        scores = cached_scores.clone
        cached_scores.clear
      end

      eps_conns.each do |out|
        out << "data:#{Oj.dump scores}\n\n" unless scores.empty?
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

  set :detail_conns, []
  get '/details/:char' do
    content_type 'text/event-stream'
    stream(:keep_open) do |out|
      ts = TaggedStream.new(out, params[:char])
      settings.detail_conns << ts
      puts "STREAM: new detailstream connection for #{ts.tag} from #{request.ip}" if VERBOSE
      out.callback do
        puts "STREAM: detailstream connection closed locally for #{ts.tag} from #{request.ip}" if VERBOSE
        settings.detail_conns.delete(ts)
      end
      out.errback do
        puts "STREAM: detailstream connection closed externally for #{ts.tag} from #{request.ip}" if VERBOSE
        settings.detail_conns.close
        settings.detail_conns.delete(ts)
      end
    end
  end

  Thread.new do
    t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)
    t_redis.psubscribe('stream.tweet_updates.*') do |on|
      on.pmessage do |match, channel, message|
        channel_id = channel.split('.')[2] #TODO: perf profile this versus a regex later
        detail_conns.select { |c| c.tag == channel_id}.each do |ts|
          ts.out << "event:#{channel}\n"
          ts.out << "data:#{message}\n\n"
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
  @stream_graphite_log_rate = 2 #matches tasseo polling rate so why not
  EM.next_tick do
    EM::PeriodicTimer.new(@stream_graphite_log_rate) do
      graphite_dyno_log("stream.raw.clients", WebScoreRawStreamer.raw_conns.count)
      graphite_dyno_log("stream.eps.clients", WebScoreCachedStreamer.eps_conns.count)
      graphite_dyno_log("stream.detail.clients", WebDetailStreamer.detail_conns.count)
    end
  end

end
