template_path = "#{File.dirname(__FILE__)}/templates/"

@after_bundler = []
def after_bundler(&handler_block) @after_bundler << handler_block; end

@app_name = app_name

@enable_secret = yes?("Do you use dynamic secret? ") ? true : false

# =========================
# Gems
# =========================
gem 'therubyracer', platforms: :ruby
gem "haml"
gem "kaminari"

gem_group :development do
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
  gem 'capybara'
  gem 'factory_girl_rails'

  gem 'guard-rspec'
end

after_bundler do
  generate 'rspec:install'
  remove_file "Guard"
  run "bundle exec guard init rspec"
end


# =========================
# bundle install
# =========================
run 'bundle install'
@after_bundler.each do |h|
  h.call;
end


# =========================
# rbenv local
# =========================
# (ignored if rbenv is not installed.)
rbenv_ruby = `rbenv version | cut -d' ' -f1`
rbenv_ruby = DEFAULT_RUBY_VERSION unless $? == 0
create_file '.rbenv-version', rbenv_ruby


# =========================
# Config files
# =========================

# spec_helper.rb を置き換え
remove_file "spec/spec_helper.rb"
create_file "spec/spec_helper.rb", File.read(template_path + "spec_helper.rb")

# .gitignore を置き換え
remove_file '.gitignore'
create_file '.gitignore', File.read(template_path + "gitignore")


# =========================
# secret_token.rb
# =========================
secret_token_rb = <<-"RUBY"
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

#{app_name.capitalize}::Application.config.secret_key_base = secure_token
RUBY

if @enable_secret
  # token自動生成スクリプを追加
  remove_file 'config/initializers/secret_token.rb'
  initializer "secret_token.rb", secret_token_rb
end


# =========================
# application.rb
# =========================
# application メソッドに複数行の文字列渡すとインデントがおかしくなるので調整
def application_multiline(data, options = {})
  indent = options[:env] ? "  " : "    "
  application data.gsub("\n", "\n#{indent}"), options
end

# rails g scaffold で使用する generator を指定
# helper / css / js は生成しない
application_multiline <<-RUBY
config.generators do |g|
  g.template_engine :haml
  g.test_framework :rspec
  g.controller_specs false
  g.helper_specs false
  g.view_specs false
  g.helper false
  g.stylesheets false
  g.javascripts false
end
RUBY


# =========================
# Git
# =========================
git :init
git :add => '.'
git :commit => '-am "Initial commit"'

# if @deploy_via_remote && @remote_repo
#   git :remote => "add origin #@remote_repo"
# end

