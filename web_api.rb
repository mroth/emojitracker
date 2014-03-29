require 'sinatra/base'
require 'dalli'
require 'rack-cache'
require 'oj'
require 'emoji_data'

class WebAPI < Sinatra::Base

  get '/details/:char' do
    cache_control :public, max_age: 30

    @emoji_char = EmojiData.find_by_unified( params[:char] )
    @emoji_char_rank = REDIS.ZREVRANK('emojitrack_score', @emoji_char.unified).to_i + 1
    @emoji_tweets = REDIS.LRANGE("emojitrack_tweets_#{@emoji_char.unified}",0,9)
    @emoji_tweets_json = @emoji_tweets.map! {|t| Oj.load(t)}
    content_type :json
    Oj.dump( {
      'char' => @emoji_char.char,
      'char_details' => @emoji_char,
      'popularity_rank' => @emoji_char_rank,
      'recent_tweets' => @emoji_tweets_json
    })
  end

  get '/rankings' do
    cache_control :public, max_age: 10  # this needs to be pretty fresh :-/

    raw_scores = REDIS.zrevrange('emojitrack_score', 0, -1, { withscores: true } )
    @scores = raw_scores.map do |score|
      emo_obj = EmojiData.find_by_unified(score[0])
      {
        "char"  => EmojiData.unified_to_char(score[0]),
        "id"    => emo_obj.unified,
        "name"  => emo_obj.name,
        "score" => score[1].to_i
      }
    end

    content_type :json
    Oj.dump( @scores )
  end

  get '/stats' do
    @raw_score = REDIS.zrevrange('emojitrack_score', 0, -1, { withscores: true } ).map { |s| s[1] }.inject(:+).to_i
    Oj.dump(
      {
        'raw_score' => @raw_score
      }
    )
  end

end
