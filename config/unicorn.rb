worker_processes Integer(ENV["WEB_CONCURRENCY"] || 4)
timeout 15
preload_app true

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  # *** Rediscloud documentation claims we don't need to do anything special...
  #  "No special setup is required when using Redis Cloud with a Unicorn server.
  # Users running Rails apps on Unicorn should follow the instructions in the
  # Configuring Redis from Rails section and users running Sinatra apps on
  # Unicorn should follow the instructions in the Configuring Redis on Sinatra
  # section."
  # - https://devcenter.heroku.com/articles/rediscloud#configuring-redis-on-sinatra

  # # If you are using Redis but not Resque, change this
  # if defined?(Resque)
  #   Resque.redis.quit
  #   Rails.logger.info('Disconnected from Redis')
  # end
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  # # If you are using Redis but not Resque, change this
  # if defined?(Resque)
  #   Resque.redis = ENV['<REDIS_URI>']
  #   Rails.logger.info('Connected to Redis')
  # end
end
