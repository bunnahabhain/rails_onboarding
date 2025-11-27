# Configure RailsOnboarding for test environment
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'
  config.redirect_after_completion = :root_path
  config.redirect_after_skip = :root_path
  config.enable_tooltips = true
  config.enable_milestones = true
  config.onboarding_required_for = :new_users

  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '👋', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'First Action', icon: '🚀', skippable: false },
    { name: :explore, title: 'Explore Features', icon: '🔍', skippable: true }
  ]
end
