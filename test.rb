#!/usr/bin/env ruby

require_relative 'lib/emoji'

# emoji_chars.each { |e| puts [e.hex].pack("U") }
print Emoji.new.chars
