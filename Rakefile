require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :stats do
  require_relative 'lib/config'
  raw_scores = REDIS.zrevrange('emojitrack_score', 0, -1, { withscores: true } )
  puts "Total score:", raw_scores.map { |s| s[1] }.inject(:+).to_i
end
