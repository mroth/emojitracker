################################################
# tweet object mixin
#
# handles common methods for dealing with tweet status we get back from tweetstream
################################################
require 'emoji_data'

module WrappedTweet

  # what? it's a perfectly cromulent word.
  def ensmallen
    {
      'id'          => self.id.to_s,
      'text'        => self.text,
      'screen_name' => self.user.screen_name,
      'name'        => self.user.name
      #'avatar' => status.user.profile_image_url
    }
  end

  # return all the emoji chars contained in the tweet
  def emoji_chars
    @emoji_chars ||= EmojiData.chars.select { |c| self.text.include? c  }
  end

  # return all the emoji chars contained in the tweet, as EmojiData::EmojiChar objects
  # def emojis
  #   @emojis ||= self.emoji_chars.map { |char| EmojiData.find_by_str(char) }
  # end

end
