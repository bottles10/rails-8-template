# ======================
# Gems
# ======================
gem 'devise'

# Development-only gems
gem_group :development do
  gem 'bullet'
  gem 'traceroute'
  gem 'better_errors'
  gem 'binding_of_caller'
end

after_bundle do
  # ======================
  # Devise Setup
  # ======================
  generate 'devise:install'

  # ======================
  # Generate Devise Model
  # ======================
  # Ask for model name
  user_model = ask("What would you like to name your Devise model? [User]")
  user_model = "User" if user_model.blank?
  
  generate "devise", user_model

  # ======================
  # Add extra columns (e.g., username)
  # ======================
  extra_columns = ask("Add extra columns to #{user_model} (comma-separated, e.g., username: string)?")
  unless extra_columns.blank?
    generate "migration", "AddExtraColumnsTo#{user_model.pluralize} #{extra_columns}"
    rails_command "db:migrate"
  end

  # ======================
  # Devise Views
  # ======================
  generate "devise:views"

  # Replace Devise views with your custom styling
  # Assume you have your custom views in 'lib/templates/devise'
  say "Copying custom Devise views..."
  custom_devise_views_path = File.expand_path("lib/templates/devise", __dir__)
  if Dir.exist?(custom_devise_views_path)
    directory custom_devise_views_path, "app/views/devise", force: true
  else
    say "No custom views found at #{custom_devise_views_path}, skipping..."
  end

  # ======================
  # Bullet setup
  # ======================
  say "✅ Running Bullet installer..."
  generate 'bullet:install'


  # ======================
  # Traceroute setup
  # ======================
  traceroute_yaml_content = <<~YAML
    ignore_unreachable_actions:
      - ^active_storage\\/
      - ^devise\\/
    ignore_unused_routes:
      # - ^users#index
      - ^active_storage\\/
      - ^rails/health#show
      - ^devise\\/
  YAML

  create_file ".traceroute.yaml", traceroute_yaml_content
  say "✅ .traceroute.yaml created with default settings"


  # ======================
  # Nav & Flash Partials (inside layouts/shared)
  # ======================
  shared_path = "app/views/layouts/shared"

  # Make the folder if it doesn't exist
  empty_directory shared_path

  # replace shared folder from lib to layouts/shared
  say "----- Copying shared folder files -----"
  custom_shared_folder_path = File.expand_path("lib/shared", __dir__)
  if Dir.exist?(custom_shared_folder_path)
    directory custom_shared_folder_path, "app/views/layouts/shared", force: true
  else
    say "No shared folder found at #{custom_shared_folder_path}, skipping..."
  end


  # ======================
  # Add Nav & Flash Partials
  # ======================

  # ======================
  # Update Application Layout
  # ======================
  inject_into_file "app/views/layouts/application.html.erb", after: "<body>\n" do
    <<~HTML
      <header class="sticky top-0 h-20">
        <%= render 'layouts/shared/nav' %>
        <div id="flashes">
          <%= render 'layouts/shared/flash_messages' %>
        </div>
      </header>
    HTML
  end

  # ======================
  # Add stimulus controller flash
  # ======================
  say "--- Generating stimulus controller for flash ----"
  generate "stimulus flash"

  flash_controller_content = <<~JAVASCRIPT
    import { Controller } from "@hotwired/stimulus"

    // Connects to data-controller="flash"
    export default class extends Controller {
      static targets = ["alert"]
      connect() {
        console.log("Flash Connected")

        setTimeout(() => {
            this.alertTarget.classList.add("animate-pulse", "ease-in-out")
        }, 3000)

        setTimeout(() => {
          this.alertTarget.classList.add("transform", "scale-75", "transition-all", "duration-300")
        },4500)

        setTimeout(() => {
          this.alertTarget.remove()
        }, 5000)
      }
    }

  JAVASCRIPT
  js_controllers = "app/javascript/controllers"
  create_file "#{js_controllers}/flash_controller.js", flash_controller_content, force: true
  say "✅  flash_controller.js created with flash message animations"

  # ======================
  # Devise Strong Parameters (username example)
  # ======================
  inject_into_file "app/controllers/application_controller.rb", after: "stale_when_importmap_changes\n" do
    <<~RUBY
      before_action :configure_permitted_parameters, if: :devise_controller?

      protected

      def configure_permitted_parameters
        devise_parameter_sanitizer.permit(:sign_up, keys: [ :username, :email ])
        devise_parameter_sanitizer.permit(:account_update, keys: [ :username, :email ])
        devise_parameter_sanitizer.permit(:sign_in, keys: [ :username ])
      end
    RUBY
  end

  # ======================
  # Add Current Attribute for user
  # ======================
  models_folder = "app/models"
  create_file "#{models_folder}/current.rb", <<~RUBY
    class Current < ActiveSupport::CurrentAttributes
      attribute :user
    end
  RUBY

  # Set Current user attribute in application controller
  inject_into_file "app/controllers/application_controller.rb", 
    after: "before_action :configure_permitted_parameters, if: :devise_controller?\n" do
      <<~RUBY
          before_action :set_current_user, if: :user_signed_in?
      RUBY
    end
  inject_into_file "app/controllers/application_controller.rb", before: "protected\n" do
    <<~RUBY
      private

      def set_current_user
        Current.user = current_user
      end
    RUBY
  end

  # ======================
  # Helper to render turbo flash messages
  # ======================
  say "---- Adding turbo flash messages helper ----"
  inject_into_file "app/helpers/application_helper.rb", after: "module ApplicationHelper\n" do
    <<~RUBY
      def render_turbo_stream_flash_messages
        turbo_stream.prepend "flashes", partial: "layouts/shared/flash_messages"
      end
    RUBY
  end

  # ======================
  # Tailwind classes setup
  # ======================
  say "--- Copy tailwind custom classes ---"
  custom_tailwind_class_path = File.expand_path("lib/tailwind", __dir__)
  if Dir.exist?(custom_tailwind_class_path)
    directory custom_tailwind_class_path, "app/assets/tailwind", force: true
  else
    say "No custom tailwild folder found at #{custom_tailwind_class_path}, skipping..."
  end


  say "✅ Devise setup complete!"

  say "⚠️ Read the below instructions carefully!"
  say "======================================"
  say "Uncomment or Add the following to devise initilizer" 
  say "if you want to use eg: username for authentication"
  say ""
  say "1️⃣  config.authentication_keys = [ :username ]"
  say "2️⃣  config.case_insensitive_keys = [ :email, :username ]"
  say "3️⃣  config.strip_whitespace_keys = [ :email, :username ]"
  say ""
  say "======================================"

end
