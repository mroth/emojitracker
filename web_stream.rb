require_relative 'lib/config'
require 'sinatra'
require 'oj'
require 'eventmachine'

################################################
# streaming thread for score updates (main page)
################################################

conns = []
get '/subscribe' do
  content_type 'text/event-stream'
  stream(:keep_open) do |out|
    conns << out
    out.callback { conns.delete(out) }
  end
end

Thread.new do
  # we need a new instance of the redis object for this
  t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)

  t_redis.psubscribe('stream.score_updates') do |on|
    on.pmessage do |match, channel, message|
      conns.each do |out|
        # out << "event: #{channel}\n"
        out << "data:#{message}\n\n"
      end
    end
  end

end

################################################
# 60 events per second rollup streaming thread for score updates
################################################

eps_conns = []
cached_scores = {}
semaphore = Mutex.new

get '/subscribe_60eps' do
  content_type 'text/event-stream'
  stream(:keep_open) do |conn|
    eps_conns << conn
    puts "STREAM: new eps_stream connection opened from #{request.ip}" if VERBOSE
    conn.callback do
      puts "STREAM: eps_stream connection closed from #{request.ip}" if VERBOSE
      eps_conns.delete(conn)
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
  # we need a new instance of the redis object for this
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

################################################
# streaming thread for tweet updates (detail pages)
################################################

class TaggedStream
  attr_reader :out, :tag
  def initialize(out,tag=nil)
    @out = out
    @tag = tag
  end
end

detail_conns = []
get '/subscribe/details/:char' do
  content_type 'text/event-stream'
  stream(:keep_open) do |out|
    ts = TaggedStream.new(out, params[:char])
    detail_conns << ts
    puts "STREAM: new detailstream connection for #{ts.tag} from #{request.ip}" if VERBOSE
    out.callback do
      puts "STREAM: detailstream connection closed for #{ts.tag} from #{request.ip}" if VERBOSE
      detail_conns.delete(ts)
    end
  end
end

Thread.new do
  # we need a new instance of the redis object for this
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

################################################
# graphite logging for all the streams
################################################
@stream_graphite_log_rate = 2 #matches tasseo polling rate so why not
EM.next_tick do
  EM::PeriodicTimer.new(@stream_graphite_log_rate) do
    graphite_dyno_log("stream.raw.clients", conns.count)
    graphite_dyno_log("stream.eps.clients", eps_conns.count)
    graphite_dyno_log("stream.detail.clients", detail_conns.count)
  end
end
