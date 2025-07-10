source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in cccux.gemspec.
gemspec

# Add ostruct to silence warning about it being removed from default gems
gem 'ostruct'

gem "puma"

gem "byebug"
gem "sqlite3"

gem "sprockets-rails"

# Add Devise for authentication in dummy app
gem "devise"

group :test do
  gem 'minitest-reporters'
end

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

group :development, :test do
  gem 'factory_bot_rails'
end
