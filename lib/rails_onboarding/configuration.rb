module RailsOnboarding
  class Configuration
    attr_accessor :user_class_name,
                  :include_host_styles,
                  :redirect_after_completion,
                  :redirect_after_skip,
                  :steps,
                  :feature_tooltips,
                  :enable_tooltips,
                  :enable_milestones,
                  :milestones,
                  :onboarding_required_for,
                  :custom_css_path,
                  :custom_js_path,
                  :enable_analytics,
                  :analytics_data_retention_days,
                  :analytics_session_timeout_minutes,
                  :welcome_heading,
                  :welcome_subheading,
                  :welcome_features

    def initialize
      @user_class_name = "User"
      @include_host_styles = true  # Default to including host app css
      @redirect_after_completion = :root_path
      @redirect_after_skip = :root_path
      @enable_tooltips = true
      @enable_milestones = true
      @enable_analytics = true
      @analytics_data_retention_days = 365 # Keep analytics data for 1 year
      @analytics_session_timeout_minutes = 30 # Consider session ended after 30 minutes of inactivity
      @onboarding_required_for = :new_users # :new_users, :all_users, or a Proc
      @welcome_heading = "We're excited to have you here!"
      @welcome_subheading = "Now, let's take a few moments to get you set up and familiar with a few things you need to know to get started."
      @welcome_features = [
        { icon: "👤", text: "Set up your profile" },
        { icon: "📝", text: "Create your first item" },
        { icon: "🔍", text: "Explore key features" }
      ]

      # Default steps - can be customized
      @steps = [
        {
          name: :welcome,
          title: "Welcome",
          icon: "🎉",
          skippable: true
        }
      ]

      @feature_tooltips = {
        "getting_started" => {
          text: "Click here to get started!",
          delay: 1000,
          position: "bottom"
        }
      }

      # Default milestones - can be customized
      @milestones = [
        {
          key: :welcome_completed,
          title: "Welcome Aboard!",
          description: "You completed the welcome step",
          icon: "🎉",
          points: 10,
          trigger: :onboarding_step_completed,
          conditions: { step: :welcome }
        },
        {
          key: :onboarding_completed,
          title: "Onboarding Champion",
          description: "You completed the entire onboarding flow",
          icon: "🏆",
          points: 50,
          trigger: :onboarding_completed
        },
        {
          key: :early_adopter,
          title: "Early Adopter",
          description: "You joined within the first hour",
          icon: "⚡",
          points: 100,
          trigger: :custom,
          conditions: { early_adopter: true }
        }
      ]
    end

    def user_class
      @user_class_name.constantize
    end

    def total_steps
      steps.size
    end

    def step_by_name(name)
      return nil if name.nil?

      steps.find { |s| s[:name].to_sym == name.to_sym }
    end

    def step_index(name)
      return nil if name.nil?

      steps.find_index { |s| s[:name].to_sym == name.to_sym }
    end

    def milestone_by_key(key)
      return nil if key.nil?

      milestones.find { |m| m[:key].to_sym == key.to_sym }
    end

    def milestones_for_trigger(trigger, conditions = {})
      milestones.select do |milestone|
        # Match on trigger
        next false unless milestone[:trigger] == trigger.to_sym

        # If no conditions are provided, match all milestones with this trigger
        next true if conditions.empty?

        # If milestone has no conditions, but we're providing conditions, don't match
        next false if milestone[:conditions].nil?

        # Both have conditions, check if they match
        conditions_match?(milestone[:conditions], conditions)
      end
    end

    private

    def conditions_match?(milestone_conditions, trigger_conditions)
      return true if milestone_conditions.nil?

      milestone_conditions.all? do |key, value|
        trigger_conditions[key] == value || trigger_conditions[key.to_s] == value ||
        trigger_conditions[key.to_sym] == value
      end
    end
  end
end
