#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/emoji'

require 'colored'

# my options
VERBOSE = ENV["VERBOSE"] || false
puts "...starting in verbose mode!" if VERBOSE
$stdout.sync = true if VERBOSE

#setup
TERMS = Emoji.chars.first(200) #TODO: need to raise me with twitter....

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

  matches = Emoji.chars.select { |c| status.text.include? c  }
  matches.each do |matched_emoji_char|
    # puts matched_emoji_char, emoji.char_to_codepoint(matched_emoji_char), "+1"
    REDIS.ZINCRBY 'emojitrack_score', 1, Emoji.char_to_codepoint(matched_emoji_char)
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