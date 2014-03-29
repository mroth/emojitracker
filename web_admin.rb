require 'sinatra/base'
require 'oj'
require_relative 'lib/config'

class WebAdmin < Sinatra::Base

  module AdminUtils
    # these constants are also defined in web_stream.rb for now
    # but are duplicated here since streaming goal is to move to
    # different platform
    STREAM_STATUS_REDIS_KEY = 'admin_stream_status'
    STREAM_STATUS_UPDATE_RATE = 5

    def self.rollup_stream_status(filter=true)
      #get vals from redis
      nodes = REDIS.HVALS STREAM_STATUS_REDIS_KEY

      #deserialize from JSON
      nodes.map! {|n| Oj.load(n)}

      #consider values stale if greater than 10x report period
      nodes.reject! {|n| Time.now.to_i - n['reported_at'] > STREAM_STATUS_UPDATE_RATE*10 } if filter
      #TODO: potentially clear these from REDIS entirely when we detect?

      return nodes
    end
  end

  helpers AdminUtils

  get '/?' do
    slim :stream_admin
  end

  get '/streamers/status.json' do
    content_type :json
    Oj.dump AdminUtils.rollup_stream_status
  end


end
