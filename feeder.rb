#!/usr/bin/env ruby

require_relative 'lib/config'
require 'emoji_data'
require 'oj'
require 'colored'
require 'socket'

# my options
VERBOSE = ENV["VERBOSE"] || false
puts "...starting in verbose mode!" if VERBOSE
$stdout.sync = true

def is_production?
  ENV["RACK_ENV"] == 'production'
end

# check for development mode with remote redis server, if so refuse to run
if (REDIS_URI.to_s.match(/redistogo/) && !is_production?)
  Kernel::abort "You shouldn't be using the production redis server with a local version of feeder! Quitting..."
end

# configure logging to graphite in production
@hostedgraphite_apikey = ENV['HOSTEDGRAPHITE_APIKEY']
def graphite_log(metric, count)
  if is_production?
    sock = UDPSocket.new
    # sock.send hostedgraphite_apikey + ".feeder.terms.tracked 1444\n", 0, "carbon.hostedgraphite.com", 2003
    sock.send @hostedgraphite_apikey + ".#{metric} #{count}\n", 0, "carbon.hostedgraphite.com", 2003
  end
end

# SETUP
# 400 terms is the max twitter will allow with a normal dev account
# set that if you are on a normal key otherwise the stream will not return anything to you
MAX_TERMS = ENV["MAX_TERMS"] || nil
if MAX_TERMS
  TERMS = EmojiData.chars.first(MAX_TERMS.to_i)
else
  TERMS = EmojiData.chars
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
      'screen_name' => status.user.screen_name,
      'name' => status.user.name
      #'avatar' => status.user.profile_image_url
    }
    status_json = Oj.dump(status_small)

    matches = EmojiData.chars.select { |c| status.text.include? c  }
    matches.each do |matched_emoji_char|
      cp = EmojiData.char_to_unified(matched_emoji_char)
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

  @stats_refresh_rate = 10
  EM::PeriodicTimer.new(@stats_refresh_rate) do
    tracked_period = @tracked-@tracked_last
    tracked_period_rate = tracked_period / @stats_refresh_rate

    puts "Terms tracked: #{@tracked} (\u2191#{tracked_period}, +#{tracked_period_rate}/sec.), rate limited: #{@skipped} (+#{@skipped-@skipped_last})"
    graphite_log('feeder.updates.rate_per_second', tracked_period_rate)

    @tracked_last = @tracked
    @skipped_last = @skipped
  end

  @redis_check_refresh_rate = 60
  EM::PeriodicTimer.new(@redis_check_refresh_rate) do
    info = REDIS.info
    puts "REDIS - used memory: #{info['used_memory_human']}, iops: #{info['instantaneous_ops_per_sec']}"
    graphite_log('feeder.redis.used_memory', info['used_memory'])
    graphite_log('feeder.redis.iops', info['instantaneous_ops_per_sec'])
  end
end