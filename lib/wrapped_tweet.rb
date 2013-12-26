################################################
# tweet object mixin
#
# handles common methods for dealing with tweet status we get back from tweetstream
################################################
require 'emoji_data'
require 'oj'

module WrappedTweet

  # return a hash of the tweet with absolutely everything we dont to broadcast need ripped out
  # (what? it's a perfectly cromulent word.)
  def ensmallen
    {
      'id'          => self.id.to_s,
      'raw_text'    => self.text,
      'text'        => self.expanded_links_text,
      'screen_name' => self.user.screen_name,
      'name'        => self.safe_user_name()
      #'avatar' => status.user.profile_image_url
    }
  end

  # memoized cache of ensmallenified json
  def tiny_json
    @small_json ||= Oj.dump(self.ensmallen)
  end

  # return all the emoji chars contained in the tweet
  def emoji_chars
    @emoji_chars ||= self.emojis.map { |e| e.char }
  end

  # return all the emoji chars contained in the tweet, as EmojiData::EmojiChar objects
  def emojis
    @emojis ||= EmojiData.find_by_str(self.text)
  end

  # try to make Twitter Inc. happy by using display URLs
  # this is going to return HTML instead of raw text, sigh...
  def expanded_links_text
    return self.text if (self.urls.length < 1 && self.media.length < 1)
    expanded_text = self.text.dup()

    (self.urls + self.media).each do |link|
      url_start, url_stop = link.indices
      expanded_text[url_start..url_stop]= self.html_link(link.display_url, link.url)
    end

    return expanded_text
  end

  protected
  # twitter seems to have a bug where user names can get null bytes set in their string
  # this strips them out so we dont cause string parse errors
  def safe_user_name
    @safe_name ||= self.user.name.gsub(/\0/, '')
  end

  def html_link(text, url)
    "<a href='#{url}' target='_blank'>#{text}</a>"
  end

end
