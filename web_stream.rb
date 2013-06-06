require_relative 'lib/config'
require_relative 'lib/emoji'

require 'sinatra'

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
    out.callback { detail_conns.delete(ts) }
  end
end

Thread.new do
  # we need a new instance of the redis object for this
  t_redis = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)

  t_redis.psubscribe('stream.tweet_updates.*') do |on|
    on.pmessage do |match, channel, message|
      channel_id = channel.split('.')[2] #TODO: perf profile this versus a regex later
      detail_conns.select { |c| c.tag == channel_id}.each do |ts|
        ts.out << "event: #{channel}\n"
        ts.out << "data: #{message}\n\n"
      end
    end
  end

end