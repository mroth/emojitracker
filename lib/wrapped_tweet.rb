################################################
# tweet object mixin
#
# handles common methods for dealing with tweet status we get back from tweetstream
################################################
require 'emoji_data'
require 'oj'
require 'time'

module WrappedTweet

  # return a hash of the tweet with absolutely everything we dont to broadcast need ripped out
  # (what? it's a perfectly cromulent word.)
  def ensmallen
    {
      'id'                  => self.id.to_s,
      'text'                => self.text,
      'screen_name'         => self.user.screen_name,
      'name'                => self.safe_user_name(),
      'links'               => self.ensmallen_links(),
      'profile_image_url'   => self.user.profile_image_url,
      'created_at'          => self.created_at.iso8601
    }
  end

  # combine URL and Media entities, and return only minimum we need
  # this means we pass none of the media object junk beyond the url stuff
  def ensmallen_links
    links = []
    (self.urls + self.media).each do |link|
      links << {'url' => link.url, 'display_url' => link.display_url, 'expanded_url' => link.expanded_url, 'indices' => link.indices}
    end

    #always sort results, so clients can easily reverse to loop and s//
    links.sort { |x,y| x['indices'][0] <=> y['indices'][0] }
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
