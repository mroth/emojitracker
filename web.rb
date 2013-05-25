require_relative 'lib/config'
require_relative 'lib/emoji'

require 'sinatra'
require 'slim'
require 'coffee-script'

get '/' do
  slim :index
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

# get '/subscribe' do
#   content_type 'text/event-stream'
#   stream(:keep_open) do |out|
#     conns << out
#     out.callback { conns.delete(out) }
#   end
# end

# Thread.new do
#   uri = URI.parse(ENV["REDISTOGO_URL"])
#   redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

#   redis.psubscribe('stream.tweets.*') do |on|
#     on.pmessage do |match, channel, message|
#       type = channel.sub('stream.tweets.', '')

#       conns.each do |out|
#         out << "event: #{channel}\n"
#         out << "data: #{message}\n\n"
#       end
#     end
#   end

# end
