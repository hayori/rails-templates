@after_bundler = []
def after_bundler(&handler_block) @after_bundler << handler_block; end

@app_name = app_name

@enable_guard = yes?("y -> Guard, n -> Watchr? ") ? true : false
@enable_secret = yes?("enable dynamic secret? ") ? true : false

gem 'therubyracer', platforms: :ruby

gem_group :development do
  # 高機能エラー画面
  gem 'better_errors'

  # 画面下にデバッグ情報を表示
  gem 'rails-footnotes'

  # 多機能コンソール (binding.pryでデバッグ)
  gem 'pry-rails'

  # pryのシンタックスハイライト
  gem 'pry-coolline'

  # pryにstep, next, continueを追加
  gem 'pry-debugger'

  # pryでのSQL結果を綺麗に表示
  gem 'hirb'
  gem 'hirb-unicode'

end

gem_group :development, :test do

  # sporkの代わり & 色々高速化
  gem 'spring'

  gem 'rspec-rails'
  gem 'factory_girl_rails'

  if @enable_guard
    gem 'guard-rspec'
  else
    gem 'watchr'
  end
end

after_bundler do
  generate 'rspec:install'
end

# spec_helper.rb ====================================================
spec_helper_rb = <<-'EOS'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'factory_girl'

Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = false
  config.order = 'random'
  config.include FactoryGirl::Syntax::Methods

  config.before(:all) do
    FactoryGirl.reload
  end
end
EOS

# Guard ====================================================
guardfile = <<-'EOS'
guard :rspec, spring: true do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { 'spec' }

  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml)$})                 { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^spec/factories/(.+)\.rb$})                { 'spec/factories_spec.rb' }
  watch(%r{^spec/support/(.+)\.rb$})                  { 'spec' }
  watch('config/routes.rb')                           { 'spec/routing' }
  watch('app/controllers/application_controller.rb')  { 'spec/controllers' }
end
EOS

# .watchr ====================================================
dot_watchr = <<-'EOS'
def run_spec(file)
  unless File.exist?(file)
    puts "#{file} does not exist"
    return
  end

  puts "Running #{file}"
  system "bundle exec spring rspec #{file}"
  puts
end

watch("spec/.*/*_spec.rb") do |match|
  run_spec match[0]
end

watch("app/(.*/.*).rb") do |match|
  run_spec %{spec/#{match[1]}_spec.rb}
end
EOS


# watchr.rake ====================================================
watchr_rake = <<-'EOS'
desc "Run watchr"
task :watchr do
  sh %{bundle exec watchr .watchr}
end
EOS


# secret_token.rb ====================================================
secret_token_rb = <<-"EOS"
require 'securerandom'

def secure_token
  token_file = Rails.root.join('.secret')
  if File.exist?(token_file)
    # Use the existing token.
    File.read(token_file).chomp
  else
    # Generate a new token and store it in token_file.
    token = SecureRandom.hex(64)
    File.write(token_file, token)
    token
  end
end

#{app_name}::Application.config.secret_key_base = secure_token
EOS


# footnotes.rb ====================================================
footnotes_rb = <<-'EOS'
if defined?(Footnotes) && Rails.env.development?
  Footnotes.run! # first of all

  # ... other init code
end
EOS

# .gitignore ====================================================
dot_gitignore = <<-'EOS'
# Ignore bundler config.
/.bundle

# Ignore the default SQLite database.
/db/*.sqlite3
/db/*.sqlite3-journal

# Ignore all logfiles and tempfiles.
/log/*.log
/tmp

# Ignore other unneeded files.
doc/
*.swp
*~
.project
.DS_Store
.idea
.secret
/coverage/
/public/system/*
/spec/tmp/*
rerun.txt
.rbenv-gemsets
config/settings.local.yml
config/settings/*.local.yml
config/environments/*.local.yml
/public/assets
EOS


# Setup ====================================================
run 'bundle install'
@after_bundler.each do |h| 
  h.call; 
end

# Enable rbenv local
# (ignored if rbenv is not installed.)
rbenv_ruby = `rbenv version | cut -d' ' -f1`
rbenv_ruby = DEFAULT_RUBY_VERSION unless $? == 0
create_file '.rbenv-version', rbenv_ruby

remove_file 'spec/spec_helper.rb'
create_file 'spec/spec_helper.rb', spec_helper_rb

if @enable_guard
  create_file 'Guardfile', guardfile
else
  create_file '.watchr', dot_watchr
  create_file 'lib/tasks/watchr.rake', watchr_rake
end

if @enable_secret
  remove_file 'config/initializers/secret_token.rb'
  create_file 'config/initializers/secret_token.rb', secret_token_rb
end

create_file 'config/initializers/footnotes.rb', footnotes_rb

remove_file '.gitignore'
create_file '.gitignore', dot_gitignore

# Git ======================================================
git :init
git :add => '.'
git :commit => '-am "Initial commit"'

# if @deploy_via_remote && @remote_repo
#   git :remote => "add origin #@remote_repo"
# end

