RailsOnboarding.configure do |config|
  # User model configuration
  config.user_class_name = 'User'

  # Redirects
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :dashboard_path

  # Features
  config.enable_tooltips = true
  config.enable_milestones = true

  # Who needs onboarding?
  # Options: :new_users, :all_users, or a Proc
  config.onboarding_required_for = :new_users

  # Customize onboarding steps for your app
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome to <%= Rails.application.class.module_parent_name %>',
      icon: '🎉',
      skippable: true
    },
    {
      name: :profile,
      title: 'Complete Your Profile',
      icon: '👤',
      skippable: false
    },
    {
      name: :first_action,
      title: 'Take Your First Action',
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

  # Feature tooltips
  config.feature_tooltips = {
    'getting_started' => {
      text: 'Click here to get started!',
      delay: 2000,
      position: 'bottom'
    }
    # Add more tooltips as needed
  }
end
