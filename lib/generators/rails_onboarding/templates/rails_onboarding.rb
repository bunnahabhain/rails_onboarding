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
      title: 'Welcome to LOLOL',
      icon: '🎉',
      skippable: true
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
      text: 'Click here to get started with LOLOL!',
      delay: 2000,
      position: 'bottom'
    },
    'quick_actions' => {
      text: 'Quick shortcuts to your most-used features',
      delay: 1500,
      position: 'top'
    },
    'bulk_actions' => {
      text: 'Select multiple todos to perform bulk operations',
      delay: 2000,
      position: 'top'
    }
  }
end
