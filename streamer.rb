#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/emoji'

require 'colored'

# my options
VERBOSE = ENV["VERBOSE"] || false
puts "...starting in verbose mode!" if VERBOSE
$stdout.sync = true

#setup
TERMS = Emoji.chars.first(400) #TODO: need to raise me with twitter....

puts "Setting up a stream to track terms '#{TERMS}'..."
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
  # status_small = {
  #   'id' => status.id.to_s,
  #   'text' => status.text,
  #   'username' => status.user.screen_name
  # }
  # status_json = Oj.dump(status_small)

  matches = Emoji.chars.select { |c| status.text.include? c  }
  matches.each do |matched_emoji_char|
    cp = Emoji.char_to_codepoint(matched_emoji_char)
    REDIS.pipelined do
      REDIS.ZINCRBY 'emojitrack_score', 1, cp
      REDIS.PUBLISH 'stream.score_updates', cp
    end
  end
end