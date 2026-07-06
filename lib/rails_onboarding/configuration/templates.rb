module RailsOnboarding
  class Configuration
    # Pre-built onboarding step templates for common app types.
    module Templates
      attr_accessor :onboarding_templates

      # Get an onboarding template by key
      #
      # @param template_key [Symbol, String] The template key
      # @return [Hash, nil] The template configuration or nil
      def template(template_key)
        onboarding_templates[template_key.to_sym]
      end

      # Apply a template to the current configuration
      #
      # @param template_key [Symbol, String] The template key to apply
      # @return [Boolean] True if template was applied successfully
      def apply_template(template_key)
        template = onboarding_templates[template_key.to_sym]
        return false unless template

        @steps = template[:steps]
        true
      end

      private

      def initialize_templates
        @onboarding_templates = {
          saas: {
            name: "SaaS Application",
            steps: [
              { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
              { name: :account_setup, title: "Account Setup", icon: "👤", skippable: false },
              { name: :team_invite, title: "Invite Team", icon: "👥", skippable: true },
              { name: :first_project, title: "Create Project", icon: "📁", skippable: false },
              { name: :integration, title: "Connect Tools", icon: "🔌", skippable: true }
            ]
          },
          ecommerce: {
            name: "E-commerce Platform",
            steps: [
              { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
              { name: :store_setup, title: "Setup Store", icon: "🏪", skippable: false },
              { name: :first_product, title: "Add Product", icon: "📦", skippable: false },
              { name: :payment_setup, title: "Payment Setup", icon: "💳", skippable: false },
              { name: :launch, title: "Launch Store", icon: "🚀", skippable: false }
            ]
          },
          marketplace: {
            name: "Marketplace",
            steps: [
              { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
              { name: :profile_setup, title: "Create Profile", icon: "👤", skippable: false },
              { name: :verification, title: "Verify Account", icon: "✅", skippable: false },
              { name: :first_listing, title: "Create Listing", icon: "📝", skippable: false },
              { name: :explore, title: "Explore", icon: "🔍", skippable: true }
            ]
          },
          community: {
            name: "Community Platform",
            steps: [
              { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
              { name: :profile, title: "Setup Profile", icon: "👤", skippable: false },
              { name: :interests, title: "Choose Interests", icon: "❤️", skippable: true },
              { name: :first_post, title: "Create Post", icon: "✍️", skippable: false },
              { name: :connect, title: "Connect", icon: "🤝", skippable: true }
            ]
          },
          education: {
            name: "Educational Platform",
            steps: [
              { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
              { name: :student_setup, title: "Student Info", icon: "🎓", skippable: false },
              { name: :course_selection, title: "Choose Courses", icon: "📚", skippable: false },
              { name: :first_lesson, title: "First Lesson", icon: "📖", skippable: false },
              { name: :study_plan, title: "Study Plan", icon: "📅", skippable: true }
            ]
          }
        }
      end
    end
  end
end
