################################################
# tweet object mixin
#
# handles common methods for dealing with tweet status we get back from tweetstream
################################################

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

end