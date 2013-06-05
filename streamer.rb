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
MAX_TERMS = ENV["MAX_TERMS"] || nil
if MAX_TERMS
  TERMS = Emoji.chars.first(MAX_TERMS.to_i)
else
  TERMS = Emoji.chars
end

EM.run do
  puts "Setting up a stream to track #{TERMS.size} terms '#{TERMS}'..."
  @tracked,@skipped,@tracked_last,@skipped_last = 0,0,0,0

  @client = TweetStream::Client.new
  @client.on_error do |message|
    # Log your error message somewhere
    puts "ERROR: #{message}"
  end
  @client.on_limit do |skip_count|
    @skipped = skip_count
    # puts "RATE LIMITED LOL"
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

  @stats_refresh_rate = 5
  EM::PeriodicTimer.new(@stats_refresh_rate = 5) do
    tracked_period = @tracked-@tracked_last
    tracked_period_rate = tracked_period / @stats_refresh_rate
    puts "Terms tracked: #{@tracked} (\u2191#{tracked_period}, +#{tracked_period_rate}/sec.), rate limited: #{@skipped} (+#{@skipped-@skipped_last})"
    @tracked_last = @tracked
    @skipped_last = @skipped
  end
end