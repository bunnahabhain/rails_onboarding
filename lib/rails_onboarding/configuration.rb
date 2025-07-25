module RailsOnboarding
  class Configuration
    attr_accessor :user_class_name,
                  :redirect_after_completion,
                  :redirect_after_skip,
                  :steps,
                  :feature_tooltips,
                  :enable_tooltips,
                  :enable_milestones,
                  :onboarding_required_for,
                  :custom_css_path,
                  :custom_js_path

    def initialize
      @user_class_name = 'User'
      @redirect_after_completion = :root_path
      @redirect_after_skip = :root_path
      @enable_tooltips = true
      @enable_milestones = true
      @onboarding_required_for = :new_users # :new_users, :all_users, or a Proc

      # Default steps - can be customized
      @steps = [
        {
          name: :welcome,
          title: 'Welcome',
          icon: '🎉',
          skippable: true
        },
        {
          name: :profile,
          title: 'Setup Profile',
          icon: '👤',
          skippable: false
        },
        {
          name: :first_action,
          title: 'First Action',
          icon: '🚀',
          skippable: false
        },
        {
          name: :explore,
          title: 'Explore Features',
          icon: '🔍',
          skippable: true
        }
      ]

      @feature_tooltips = {
        'getting_started' => {
          text: 'Click here to get started!',
          delay: 1000,
          position: 'bottom'
        }
      }
    end

    def user_class
      @user_class_name.constantize
    end

    def total_steps
      steps.size
    end

    def step_by_name(name)
      steps.find { |s| s[:name].to_sym == name.to_sym }
    end

    def step_index(name)
      steps.find_index { |s| s[:name].to_sym == name.to_sym }
    end
  end
end
