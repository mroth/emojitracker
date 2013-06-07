source 'https://rubygems.org'
ruby '1.9.3'

group :web, :feeder do
  gem 'redis', '~> 3.0.4'
  gem 'hiredis', '~> 0.4.5'
  gem 'oj', '~> 2.0.14'
end

group :web do
  gem 'sinatra', '~> 1.4.2'
  gem 'slim', '~> 2.0.0'
  gem 'coffee-script'
  gem 'sass', :require => 'sass'
  gem 'thin', '~> 1.5'
  gem 'dalli', '~> 2.6'
  gem 'rack-cache'
  gem 'memcachier'
end

group :feeder do
  gem 'tweetstream', '~> 2.5.0'
  gem 'colored'
end

group :development do
  gem 'foreman'
  gem 'rspec', '~> 2.13.0'
end

group :production do
  gem 'newrelic_rpm'
end 