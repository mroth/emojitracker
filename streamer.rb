require 'tweetstream'
require 'oj'
require 'colored'
require 'redis'
require 'uri'
require_relative 'lib/emoji'

# configure tweetstream instance
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
  config.auth_method = :oauth
end

# db setup
uri = URI.parse(ENV["BOXEN_REDIS_URL"] || ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

# my options
VERBOSE = ENV["VERBOSE"] || false
puts "...starting in verbose mode!" if VERBOSE
$stdout.sync = true if VERBOSE

#setup
emoji = Emoji.new
TERMS = emoji.chars.first(200) #TODO: need to raise me with twitter....

puts "Setting up a stream to track terms '#{TERMS}'..."
@client = TweetStream::Client.new
@client.on_error do |message|
  # Log your error message somewhere
  puts "ERROR: #{message}"
end
@client.on_limit do |skip_count|
  # do something
  puts "RATE LIMITED LOL"
end
@client.track(TERMS) do |status|
  puts " ** @#{status.user.screen_name}: ".green + status.text.white if VERBOSE
  status_small = {
    'id' => status.id.to_s,
    'text' => status.text,
    'username' => status.user.screen_name
  }
  status_json = Oj.dump(status_small)

  matches = emoji.chars.select { |c| status.text.include? c  }
  matches.each do |matched_emoji_char|
    # puts matched_emoji_char, emoji.char_to_codepoint(matched_emoji_char), "+1"
    REDIS.ZINCRBY 'emojitrack_score', 1, emoji.char_to_codepoint(matched_emoji_char)
  end
  # if status.text =~ /#{DOGTERMS.join('|')}/i
  #   puts "   ...doggie!" if VERBOSE
  #   REDIS.INCR 'dog_count'
  #   REDIS.PUBLISH 'stream.tweets.dog', status_json
  #   REDIS.LPUSH 'dog_tweets', status_json
  #   REDIS.LTRIM 'dog_tweets',0,9
  # end
  # if status.text =~ /#{CATTERMS.join('|')}/i
  #   puts "   ...kitty!" if VERBOSE
  #   REDIS.INCR 'cat_count'
  #   REDIS.PUBLISH 'stream.tweets.cat', status_json
  #   REDIS.LPUSH 'cat_tweets', status_json
  #   REDIS.LTRIM 'cat_tweets',0,9
  # end
end