require_relative 'lib/config'
require_relative 'lib/emoji'

require 'sinatra'
require 'slim'
require 'coffee-script'

set :public_folder, 'public'

get '/' do
  slim :index
end

get '/details/:char' do
  @emoji_char = Emoji.find_by_codepoint( params[:char] )
  @emoji_char_rank = REDIS.ZREVRANK('emojitrack_score', @emoji_char.unified).to_i + 1
  slim :details
end

get '/api/details/:char' do
  @emoji_char = Emoji.find_by_codepoint( params[:char] )
  @emoji_tweets = REDIS.LRANGE("emojitrack_tweets_#{@emoji_char.unified}",0,9)
  @emoji_tweets_json = @emoji_tweets.map! {|t| Oj.load(t)}
  content_type :json
  Oj.dump( {
    'char_details' => @emoji_char,
    'recent_tweets' => @emoji_tweets_json
  })
end

get '/application.js' do
  coffee :application
end

get '/data' do
  raw_scores = REDIS.zrange('emojitrack_score', 0, -1, { withscores: true } ).reverse
  @scores = raw_scores.map do |score|
    emo_obj = Emoji.find_by_codepoint(score[0])
    # yield "FUCK" if emo_obj.nil?
    {
      "char" => Emoji.codepoint_to_char(score[0]),
      "id" => emo_obj.unified,
      "name" => emo_obj.nil? ? '***FUCK***' : emo_obj.name,
      "score" => score[1].to_i
    }
  end

  content_type :json
  Oj.dump( @scores )
end

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
        out << "data: #{message}\n\n"
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