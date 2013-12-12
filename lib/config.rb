require 'tweetstream'
require 'redis'
require 'uri'

# verbose mode or no
VERBOSE = ENV["VERBOSE"] || false

# configure tweetstream instance
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
  config.auth_method = :oauth
end

# db setup
REDIS_URI = URI.parse(ENV["REDISCLOUD_URL"] || ENV["REDISTOGO_URL"] || ENV["BOXEN_REDIS_URL"] || "redis://localhost:6379")
REDIS = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password, :driver => :hiredis)

# environment checks
def is_production?
  ENV["RACK_ENV"] == 'production'
end

def is_development?
  ENV["RACK_ENV"] == 'development'
end

# configure logging to graphite in production
def graphite_log(metric, count)
  @hostedgraphite_apikey = ENV['HOSTEDGRAPHITE_APIKEY']
  # puts "Graphite log - #{metric}: #{count}" if VERBOSE
  if is_production?
    sock = UDPSocket.new
    sock.send @hostedgraphite_apikey + ".#{metric} #{count}\n", 0, "carbon.hostedgraphite.com", 2003
  end
end

# same as above but include heroku dyno hostname
def graphite_dyno_log(metric,count)
  dyno = ENV['DYNO'] || 'unknown-host'
  metric_name = "#{dyno}.#{metric}"
  graphite_log metric_name, count
end

#convenience method for reading booleans from env vars
def to_boolean(s)
  s and !!s.match(/^(true|t|yes|y|1)$/i)
end
