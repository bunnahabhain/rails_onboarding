# RailsOnboarding configuration
#
# See https://github.com/bunnahabhain/rails_onboarding for the full option
# reference, and docs/MILESTONES_GUIDE.md / docs/ANALYTICS_GUIDE.md for the
# features configured below.
RailsOnboarding.configure do |config|
  # The class name of your application's user model. Change this if your
  # app uses a different name (e.g. "Account", "Member").
  config.user_class_name = "User"

  # Where to send users after they finish or skip onboarding. Accepts a
  # route helper name (as a symbol) or a Proc that receives the user and
  # returns a path.
  config.redirect_after_completion = :root_path
  config.redirect_after_skip = :root_path

  # Asset name of a stylesheet loaded last on onboarding pages, for matching
  # the flow to your own design. This generator wrote a starter file to
  # app/assets/stylesheets/rails_onboarding_custom.css - nothing loads it
  # until you uncomment the line below. Retheme by redefining the
  # --onboarding-* tokens in that file rather than overriding rules.
  # config.custom_css_path = "rails_onboarding_custom"

  # Feature toggles
  config.enable_tooltips = true
  config.enable_milestones = true
  config.enable_analytics = true

  # Analytics event retention/session settings. Only relevant when
  # enable_analytics is true. See docs/ANALYTICS_GUIDE.md.
  config.analytics_data_retention_days = 365 # how long to keep analytics events
  config.analytics_session_timeout_minutes = 30 # inactivity gap that starts a new session

  # Who should be sent through onboarding?
  # :new_users - only users created after the gem was installed (default)
  # :all_users - every user, regardless of when their account was created
  # a Proc     - receives the user and returns true/false, e.g.:
  #              config.onboarding_required_for = ->(user) { !user.admin? }
  config.onboarding_required_for = :new_users

  # The steps a user walks through, in order. Each step needs a unique
  # `name` (used internally for progress tracking) and a `title` shown in
  # the UI. Set `skippable: true` to let users jump past a step.
  #
  # Customize this list to match your app's onboarding flow - add, remove,
  # or reorder steps as needed. If you add a step, you'll also need a
  # matching view under app/views/rails_onboarding/onboarding/<name>.html.erb
  # (see the generated views for examples).
  config.steps = [
    {
      name: :welcome,
      title: "Welcome",
      icon: "🎉",
      skippable: true
    },
    {
      name: :profile,
      title: "Setup Profile",
      icon: "👤",
      skippable: false
    },
    {
      name: :explore,
      title: "Explore Features",
      icon: "🔍",
      skippable: true
    }
  ]

  # Contextual tooltips shown to highlight specific UI elements. The key
  # is the tooltip's identifier (referenced from your views/helpers), and
  # each entry configures the text, delay (ms) before it appears, and
  # position relative to its target element ("top", "bottom", "left",
  # "right"). Only relevant when enable_tooltips is true.
  config.feature_tooltips = {
    "getting_started" => {
      text: "Click here to get started!",
      delay: 1000,
      position: "bottom"
    }
  }
end
