require_relative 'config'
require_relative 'wrapped_tweet'
require 'oj'
require 'twitter'

module KioskInteraction

  # configure twitter instance
  KIOSK_TWITTER_CLIENT = Twitter::Client.new(
    :consumer_key       => ENV['KIOSK_CONSUMER_KEY'],
    :consumer_secret    => ENV['KIOSK_CONSUMER_SECRET'],
    :oauth_token        => ENV['KIOSK_OAUTH_TOKEN'],
    :oauth_token_secret => ENV['KIOSK_OAUTH_TOKEN_SECRET']
  )

  class InteractionRequest
    def initialize(status)
      @request_status = status
      @requester = status.user
      @target = status.emojis.first
    end

    def handle
      if @target.nil?
        puts "INTERACTION: user #{@requester.screen_name} is talking to us but we don't see a valid target."
        return false
      else
        puts "INTERACTION: user #{@requester.screen_name} requesting info on #{@target} (#{@target.unified})"
        self.publish()
        self.post_reply()
      end
    end

    protected
    def publish
      REDIS.PUBLISH "stream.interaction.request", Oj.dump(
        {
          'char' => @target.unified,
          'requester' => @requester.screen_name
        }
      )
    end

    def post_reply
      response = KIOSK_TWITTER_CLIENT.update( format_response(), :in_reply_to_status_id => @request_status.id )

      puts self.format_response
      puts " -> ".red + "posted as http://twitter.com/#{response.user.screen_name}/status/#{response.id.to_s}"
    end

    def format_response
      "@#{@requester.screen_name} okay, putting #{@target.name} up on the BIG SCREEN at \#emojishow!"
    end
  end

end