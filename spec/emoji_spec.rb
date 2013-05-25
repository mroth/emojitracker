#encoding: UTF-8

require 'spec_helper'
require_relative '../lib/emoji'

describe Emoji do
  describe "#char_to_codepoint" do
    it "converts normal emoji to unified codepoint" do
      Emoji.char_to_codepoint("👾").should eq('1F47E')
      Emoji.char_to_codepoint("🚀").should eq('1F680')
    end
    it "converts double-byte emoji to proper codepoint" do
      Emoji.char_to_codepoint("🇺🇸").should eq('1F1FA-1F1F8')
      Emoji.char_to_codepoint("#⃣").should eq('0023-20E3')
    end
  end
  
  describe "#codepoint_to_char" do
    it "converts normal unified codepoints to unicode strings" do
      Emoji.codepoint_to_char('1F47E').should eq("👾")
      Emoji.codepoint_to_char('1F680').should eq("🚀")
    end
    it "converts doublebyte unified codepoints to unicode strings" do
      Emoji.codepoint_to_char('1F1FA-1F1F8').should eq("🇺🇸")
      Emoji.codepoint_to_char('0023-20E3').should eq("#⃣")
    end
  end
end