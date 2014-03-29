source 'https://rubygems.org'
ruby '2.0.0'

group :web, :feeder do
  gem 'redis', '~> 3.0.6'
  gem 'hiredis', '~> 0.4.5'
  gem 'oj', '~> 2.2.3'
  gem 'emoji_data', '~> 0.0.2'
end

group :web do
  gem 'sinatra', '~> 1.4.4'
  gem 'slim', '~> 2.0.2'
  gem 'coffee-script', '~> 2.2.0'
  gem 'sass', '~> 3.2.12', :require => 'sass'
  gem 'thin', '~> 1.6.1'
  gem 'dalli', '~> 2.6.4'
  gem 'rack-cache', '~> 1.2'
  gem 'memcachier', '~> 0.0.2'
end

group :feeder do
  gem 'tweetstream', '~> 2.6.0'
  gem 'twitter', '~> 4.8.1'
  gem 'colored', '~> 1.2'
end

group :development do
  gem 'foreman', '~> 0.63.0'
  gem 'rspec', '~> 2.13.0'
end

group :production do
  gem 'newrelic_rpm'
end
