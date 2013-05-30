source 'https://rubygems.org'
ruby '1.9.3'

group :web, :streamer do
  gem 'redis', '~> 3.0.4'
  gem 'hiredis', '~> 0.4.5'
  gem 'oj', '~> 2.0.13'
end

group :web do
  gem 'sinatra'
  gem 'slim'
  gem 'coffee-script'
  gem 'sass', :require => 'sass'
  gem 'thin'
  gem 'dalli'
  gem 'rack-cache'
end

group :streamer do
  gem 'tweetstream', "~> 2.5.0"
  gem 'colored'
end

group :development do
  gem 'foreman'
  gem 'rspec'
end

# group :production do
#   gem 'newrelic_rpm'
# end