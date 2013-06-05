#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/emoji'

require 'colored'

# my options
VERBOSE = ENV["VERBOSE"] || false
puts "...starting in verbose mode!" if VERBOSE
$stdout.sync = true

# TODO: check for development mode with remote redis server, if so refuse to run

# SETUP
# 400 terms is the max twitter will allow with a normal dev account
# set that if you are on a normal key otherwise the stream will not return anything to you
MAX_TERMS = ENV["MAX_TERMS"].to_i || nil
if MAX_TERMS
  TERMS = Emoji.chars.first(MAX_TERMS)
else
  TERMS = Emoji.chars
end

puts "Setting up a stream to track #{TERMS.size} terms '#{TERMS}'..."
@tracked = 0
@client = TweetStream::Client.new
@client.on_error do |message|
  # Log your error message somewhere
  puts "ERROR: #{message}"
end
@client.on_limit do |skip_count|
  # do something
  puts "RATE LIMITED LOL - skipped #{skip_count}, tracked #{@tracked}"
end
@client.track(TERMS) do |status|
  @tracked += 1
  puts " ** @#{status.user.screen_name}: ".green + status.text.white if VERBOSE
  is_retweet = status.text.start_with? "RT"
  next if is_retweet

  status_small = {
    'id' => status.id.to_s,
    'text' => status.text,
    'username' => status.user.screen_name
  }
  status_json = Oj.dump(status_small)

  matches = Emoji.chars.select { |c| status.text.include? c  }
  matches.each do |matched_emoji_char|
    cp = Emoji.char_to_codepoint(matched_emoji_char)
    REDIS.pipelined do
      # increment the score in a sorted set
      REDIS.ZINCRBY 'emojitrack_score', 1, cp

      # stream the fact that the score was updated
      REDIS.PUBLISH 'stream.score_updates', cp

      # for each emoji char, store the most recent 10 tweets in a list
      REDIS.LPUSH "emojitrack_tweets_#{cp}", status_json
      REDIS.LTRIM "emojitrack_tweets_#{cp}",0,9

      # also stream all tweet updates to named streams by char
      REDIS.PUBLISH "stream.tweet_updates.#{cp}", status_json
    end
  end
end