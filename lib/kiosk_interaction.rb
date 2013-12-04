require_relative 'config'
require_relative 'wrapped_tweet'
require 'oj'

module KioskInteraction

  class InteractionRequest
    def initialize(status)
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
      end
    end

    private
    def publish
      REDIS.PUBLISH "stream.interaction.request", Oj.dump(
        {
          'char' => @target.unified,
          'requester' => @requester.screen_name
        }
      )
    end

  end

end