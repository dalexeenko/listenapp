source 'https://rubygems.org'
ruby '2.0.0'

gem 'rails', '4.0.0'
gem 'bootstrap-sass', '2.3.2.0'
gem 'bcrypt-ruby', '3.0.1'
gem 'faker', '1.1.2'
gem 'will_paginate', '3.0.4'
gem 'bootstrap-will_paginate', '0.0.9'
gem 'whenever', :require => false
gem "feedzirra"
gem "s3", "~> 0.3.11"
gem "proxies", "~> 0.2.1"
gem "htmlentities", "~> 4.3.1"
gem "stanford-core-nlp", "~> 0.5.1"
gem "addressable", "~> 2.3.4"
gem "amatch", "~> 0.2.11"
gem 'protected_attributes'

group :development, :test do
  gem 'sqlite3', '1.3.7'
  gem 'rspec-rails', '2.13.1'
end

group :development do
  gem 'annotate', '2.5.0'
  gem 'taps', :require => false
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', '4.0.0'
  gem 'coffee-rails', '4.0.0'
  gem 'uglifier', '2.1.1'
end

gem 'jquery-rails', '2.2.1'

group :test do
  gem 'capybara', '2.1.0'
  gem 'factory_girl_rails', '4.2.0'
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
end