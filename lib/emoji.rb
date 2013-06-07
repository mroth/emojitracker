require 'oj'

class EmojiChar
  attr_reader :name, :unified, :short_name

  def initialize(emoji_hash)
    @name = emoji_hash['name']
    @unified = emoji_hash['unified']
    @docomo = emoji_hash['docomo']
    @au = emoji_hash['au']
    @softbank = emoji_hash['softbank']
    @google = emoji_hash['google']
    @image = emoji_hash['image']
    @sheet_x = emoji_hash['sheet_x']
    @sheet_y = emoji_hash['sheet_y']
    @short_name = emoji_hash['short_name']
    @text = emoji_hash['text']
  end

  def to_char
    @char ||= @unified.split('-').map { |i| i.hex }.pack("U*")
  end

  def doublebyte?
    @unified.match(/-/)
  end

end

class Emoji

  EMOJI_MAP = Oj.load_file 'lib/vendor/emoji-data/emoji.json'
  EMOJI_CHARS = EMOJI_MAP.map { |em| EmojiChar.new(em) }

  def self.chars
    @chars ||= self.codepoints.map { |cp| Emoji.codepoint_to_char(cp) }
  end

  def self.codepoints
    @codepoints ||= EMOJI_MAP.map { |es| es['unified'] }
  end

  def self.char_to_codepoint(char)
    char.codepoints.to_a.map {|i| i.to_s(16).rjust(4,'0')}.join('-').upcase
  end

  def self.codepoint_to_char(cp)
    find_by_codepoint(cp).to_char
  end

  def self.find_by_codepoint(cp)
    EMOJI_CHARS.detect { |ec| ec.unified == cp }
  end

  def self.generate_css_map
    working_map = EMOJI_CHARS.reject { |c| c.doublebyte? } #get rid of doublebyte chars until we figure out how to represent in map (TODO:)
    distance_map = [0] + working_map.each_cons(2).collect {|i| (i[1].unified.hex - i[0].unified.hex) }
    combined_map = working_map.zip(distance_map)

    reduced_map = []
    combined_map.each do |char, distance|
      if distance == 1
        active_range = reduced_map.last
        active_range.finish = char.unified
        active_range.size += 1
      else
        reduced_map << CharRange.new(char.unified)
      end
    end
    reduced_map.join(',') + ";"
  end

  private
  class CharRange
    attr_reader :start
    attr_accessor :finish, :size

    def initialize(start)
      @start = start
      @finish = start
      @size = 1
    end

    def to_s
      return "U+#{@start}" if @size == 1
      "U+#{@start}-#{@finish}"
    end
  end

end
