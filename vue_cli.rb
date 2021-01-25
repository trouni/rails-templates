run "if uname | grep -q 'Darwin'; then pgrep spring | xargs kill -9; fi"

# GEMFILE
########################################
inject_into_file 'Gemfile', before: 'group :development, :test do' do
  <<~RUBY
    gem 'devise'
  RUBY
end

inject_into_file 'Gemfile', after: 'group :development, :test do' do
  <<-RUBY
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'dotenv-rails'
  RUBY
end

gsub_file('Gemfile', /# gem 'redis'/, "gem 'redis'")

# Assets
########################################
run 'rm -rf app/assets/stylesheets'
run 'rm -rf vendor'
# run 'curl -L https://github.com/lewagon/stylesheets/archive/master.zip > stylesheets.zip'
# run 'unzip stylesheets.zip -d app/assets && rm stylesheets.zip && mv app/assets/rails-stylesheets-master app/assets/stylesheets'

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# README
########################################
markdown_file_content = <<-MARKDOWN
Rails app generated with [trouni/rails-templates](https://github.com/trouni/rails-templates), created by [Trouni Tiet](https://github.com/trouni).
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<~RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
    generate.test_framework :test_unit, fixture: false
  end
RUBY

environment generators

# Layout
########################################
gsub_file('app/views/layouts/application.html.erb', "<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>", "<%= javascript_packs_with_chunks_tag 'main', 'data-turbolinks-track': 'reload', defer: true %>")
style = <<~HTML
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <%= stylesheet_packs_with_chunks_tag 'main', media: 'all', 'data-turbolinks-track': 'reload' %>
HTML
gsub_file('app/views/layouts/application.html.erb', "<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>", style)

########################################
# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rails_command 'db:drop db:create db:migrate'
  # generate('simple_form:install', '--bootstrap')
  generate(:controller, 'pages', 'home', '--skip-routes', '--no-test-framework')

  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  append_file '.gitignore', <<~TXT
    # Ignore .env file containing credentials.
    .env*
    # Ignore Mac and Linux file system files
    *.swp
    .DS_Store
  TXT

  # Vue CLI
  ########################################
  run 'rm -rf node_modules/ package.json yarn.lock babel.config.js config/webpack app/javascript .browserslistrc postcss.config.js'
  run 'vue create frontend --no-git'
  run 'mv ./frontend/node_modules/ ./frontend/yarn.lock ./frontend/package.json ./frontend/babel.config.js .'
  run 'mv ./frontend ./app/frontend'
  run 'yarn add -D webpack-assets-manifest'

  gsub_file('config/webpacker.yml', 'source_path: app/javascript', 'source_path: app/frontend/src')
  gsub_file('config/webpacker.yml', 'source_entry_path: packs', "source_entry_path: ''")

  run 'rm bin/webpack'
  file 'bin/webpack', <<~RUBY
    #!/usr/bin/env ruby
    ENV["NODE_ENV"] ||= "development"

    Dir.chdir(File.expand_path("..", __dir__)) do
      Kernel.exec(ENV, "yarn build")
    end
  RUBY

  run 'curl -L https://raw.githubusercontent.com/trouni/rails-templates/master/vue.config.js > vue.config.js'

  # Devise install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
    #{  "protect_from_forgery with: :exception\n" if Rails.version < "5.2"}  before_action :authenticate_user!
    end
  RUBY

  # migrate + devise views
  ########################################
  rails_command 'db:migrate'
  generate('devise:views')

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<~RUBY
    class PagesController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :home ]

      def home
      end
    end
  RUBY

  # Pages#home View
  ########################################
  run 'rm app/views/pages/home.html.erb'
  file 'app/views/pages/home.html.erb', '<div id="app"></div>'

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Webpacker / Yarn
  ########################################
  # run 'yarn add popper.js jquery bootstrap'
  # append_file 'app/javascript/packs/application.js', <<~JS


  #   // ----------------------------------------------------
  #   // Note(lewagon): ABOVE IS RAILS DEFAULT CONFIGURATION
  #   // WRITE YOUR OWN JS STARTING FROM HERE 👇
  #   // ----------------------------------------------------

  #   // External imports
  #   import "bootstrap";

  #   // Internal imports, e.g:
  #   // import { initSelect2 } from '../components/init_select2';

  #   document.addEventListener('turbolinks:load', () => {
  #     // Call your functions here, e.g:
  #     // initSelect2();
  #   });
  # JS

  # inject_into_file 'config/webpack/environment.js', before: 'module.exports' do
  #   <<~JS
  #     const webpack = require('webpack');
  #     // Preventing Babel from transpiling NodeModules packages
  #     environment.loaders.delete('nodeModules');
  #     // Bootstrap 4 has a dependency over jQuery & Popper.js:
  #     environment.plugins.prepend('Provide',
  #       new webpack.ProvidePlugin({
  #         $: 'jquery',
  #         jQuery: 'jquery',
  #         Popper: ['popper.js', 'default']
  #       })
  #     );
  #   JS
  # end

  # Dotenv
  ########################################
  run 'touch .env'

  # Rubocop
  ########################################
  run 'curl -L https://raw.githubusercontent.com/lewagon/rails-templates/master/.rubocop.yml > .rubocop.yml'

  # Git
  ########################################
  git add: '.'
  git commit: "-m 'Initial commit with vue-cli template from https://github.com/trouni/rails-templates'"

  # Fix puma config
  gsub_file('config/puma.rb', 'pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }', '# pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }')
end
