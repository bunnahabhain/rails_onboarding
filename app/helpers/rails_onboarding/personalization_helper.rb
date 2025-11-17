# frozen_string_literal: true

module RailsOnboarding
  # Helper methods for personalization features in views
  module PersonalizationHelper
    # Render content only for specific user types
    #
    # @param user_types [Array<Symbol>, Symbol] User type(s) to show content for
    # @param user [Object] User object (defaults to current_user)
    # @yield Block to render if user type matches
    #
    # @example
    #   <%= for_user_types(:business, :enterprise) do %>
    #     <p>This is only shown to business and enterprise users</p>
    #   <% end %>
    def for_user_types(*user_types, user: nil)
      user ||= current_user if respond_to?(:current_user)
      return unless user

      return unless user.respond_to?(:personalization_type)

      user_type = user.personalization_type
      return unless user_types.map(&:to_sym).include?(user_type.to_sym)

      yield if block_given?
    end

    # Render different content based on user type
    #
    # @param user [Object] User object (defaults to current_user)
    # @yield [user_type] Block that receives the user type
    #
    # @example
    #   <%= personalized_content do |type| %>
    #     <% if type == :business %>
    #       <p>Welcome, business user!</p>
    #     <% else %>
    #       <p>Welcome!</p>
    #     <% end %>
    #   <% end %>
    def personalized_content(user: nil, &block)
      user ||= current_user if respond_to?(:current_user)
      return unless user

      return unless user.respond_to?(:personalization_type)

      user_type = user.personalization_type
      yield(user_type) if block_given?
    end

    # Get a personalized message based on user type
    #
    # @param messages [Hash] Hash of user_type => message
    # @param default [String] Default message if user type not found
    # @param user [Object] User object (defaults to current_user)
    # @return [String] The personalized message
    #
    # @example
    #   <%= personalized_message(
    #     { business: "Welcome to your business dashboard",
    #       individual: "Welcome to your personal dashboard" },
    #     default: "Welcome"
    #   ) %>
    def personalized_message(messages, default: "Welcome", user: nil)
      user ||= current_user if respond_to?(:current_user)
      return default unless user

      return default unless user.respond_to?(:personalization_type)

      user_type = user.personalization_type
      messages[user_type.to_sym] || default
    end

    # Get personalized steps for the current user
    #
    # @param user [Object] User object (defaults to current_user)
    # @return [Array<Hash>] Array of step configurations
    def personalized_steps(user: nil)
      user ||= current_user if respond_to?(:current_user)
      return RailsOnboarding.configuration.steps unless user

      return RailsOnboarding.configuration.steps unless user.respond_to?(:personalized_steps)

      user.personalized_steps
    end

    # Render a personalized progress indicator
    #
    # @param user [Object] User object (defaults to current_user)
    # @return [String] HTML for progress indicator
    def personalized_progress_indicator(user: nil)
      user ||= current_user if respond_to?(:current_user)
      return "" unless user

      return "" unless user.respond_to?(:personalized_progress_percentage)

      percentage = user.personalized_progress_percentage
      total_steps = user.respond_to?(:personalized_total_steps) ? user.personalized_total_steps : 0

      content_tag :div, class: "personalized-progress" do
        concat(content_tag(:div, class: "progress-bar") do
          content_tag(:div, "", class: "progress-fill", style: "width: #{percentage}%")
        end)
        concat(content_tag(:div, "#{percentage}% complete (Step #{user.personalized_step_index(user.onboarding_current_step) + 1} of #{total_steps})", class: "progress-text"))
      end
    end

    # Check if a feature should be shown based on personalization
    #
    # @param feature_name [Symbol, String] Feature name
    # @param user [Object] User object (defaults to current_user)
    # @return [Boolean] True if feature should be shown
    def show_personalized_feature?(feature_name, user: nil)
      user ||= current_user if respond_to?(:current_user)
      return true unless user

      return true unless user.respond_to?(:show_personalized_feature?)

      user.show_personalized_feature?(feature_name)
    end

    # Get personalized CTA (Call To Action) text
    #
    # @param action [Symbol, String] Action type (:next, :complete, :skip, etc.)
    # @param user [Object] User object (defaults to current_user)
    # @return [String] Personalized CTA text
    def personalized_cta(action, user: nil)
      user ||= current_user if respond_to?(:current_user)

      user_type = user&.respond_to?(:personalization_type) ? user.personalization_type : nil

      cta_map = {
        next: {
          business: "Continue to Business Setup",
          enterprise: "Proceed to Enterprise Configuration",
          individual: "Next Step",
          default: "Continue"
        },
        complete: {
          business: "Launch Your Business Account",
          enterprise: "Activate Enterprise Features",
          individual: "Get Started",
          default: "Complete Setup"
        },
        skip: {
          business: "Skip for Now (You can complete this later in Settings)",
          enterprise: "Configure Later",
          individual: "Skip This Step",
          default: "Skip"
        }
      }

      action_map = cta_map[action.to_sym] || {}
      action_map[user_type&.to_sym] || action_map[:default] || action.to_s.titleize
    end

    # Render personalized recommendations
    #
    # @param user [Object] User object (defaults to current_user)
    # @return [String] HTML for recommendations
    def personalized_recommendations(user: nil)
      user ||= current_user if respond_to?(:current_user)
      return "" unless user

      return "" unless user.respond_to?(:personalized_recommendations)

      recommendations = user.personalized_recommendations
      return "" if recommendations.empty?

      content_tag :div, class: "personalized-recommendations" do
        concat(content_tag(:h3, "Recommended for You"))
        concat(content_tag(:div, class: "recommendations-list") do
          recommendations.each do |rec|
            concat(content_tag(:div, class: "recommendation-card") do
              concat(content_tag(:h4, rec[:title]))
              concat(content_tag(:p, rec[:description]))
              concat(link_to(rec[:cta] || "Get Started", rec[:url], class: "btn btn-primary")) if rec[:url]
            end)
          end
        end)
      end
    end
  end
end
