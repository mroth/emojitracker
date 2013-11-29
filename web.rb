require 'sinatra/base'
require 'slim'
require 'coffee-script'
require 'sass'
require 'dalli'
require 'rack-cache'
require 'oj'
require 'emoji_data'

require_relative 'lib/config'
require_relative 'benchmark_app'
require_relative 'web_kiosk_app'


class WebApp < Sinatra::Base
  use WebBenchmarkApp
  use WebKioskApp

  configure :production do
    require 'newrelic_rpm'
  end

  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['AUTH_USER'], ENV['AUTH_PASS']]
    end
  end

  set :public_folder, 'public'
  set :static_cache_control, [:public, max_age: 60000] # 1000 mins.

  get '/' do
    cache_control :public, max_age: 600  # 10 mins. #disable until password is gone
    # protected! if ENV['RACK_ENV'] == 'production'
    @kiosk_mode = false
    @benchmark_mode = false
    slim :index
  end

  get '/benchmark' do
    @kiosk_mode = false
    @benchmark_mode = true
    slim :index
  end

  get '/d/:char' do
    cache_control :public, max_age: 60000  # 1000 mins.
    redirect "/details/#{params[:char]}"
  end

  get '/details/:char' do
    cache_control :public, max_age: 600  # 10 mins.

    @emoji_char = EmojiData.find_by_unified( params[:char] )
    @emoji_char_rank = REDIS.ZREVRANK('emojitrack_score', @emoji_char.unified).to_i + 1
    slim :details
  end

  get '/api/details/:char' do
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

  get '/data' do
    cache_control :public, max_age: 10  # this needs to be pretty fresh :-/

    raw_scores = REDIS.zrevrange('emojitrack_score', 0, -1, { withscores: true } )
    @scores = raw_scores.map do |score|
      emo_obj = EmojiData.find_by_unified(score[0])
      # yield "FUCK" if emo_obj.nil?
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

  get '/application.js' do
    cache_control :public, max_age: 600  # 10 mins.
    coffee :application
  end

  get '/assets/main.css' do
    cache_control :public, max_age: 600  # 10 mins.
    scss :main
  end

  # regex match for how sinatra sees unicode emoji chars in routing
  # humanized regex: block of 'percent sign followed by two word chars, exactly four in a row'
  # either exactly one or two of the above in a row (to get doublebyte)
  get %r{\A/((?:(?:\%\w{2}){4}){1,2})\z} do |char|
    cache_control :public, max_age: 6000  # 100 mins.
    unified_id = EmojiData.char_to_unified(char)
    redirect "/details/#{unified_id}"
  end
end