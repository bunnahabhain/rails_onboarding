# Pin Rails Onboarding JavaScript modules for Importmap
# These pins allow the engine's JavaScript to be loaded via importmap in the host application

# Main application bundle
pin "rails_onboarding/application", to: "rails_onboarding/application.js"

# Core onboarding controllers
pin "rails_onboarding/onboarding_controller", to: "rails_onboarding/onboarding_controller.js"
pin "rails_onboarding/progress_controller", to: "rails_onboarding/progress_controller.js"
pin "rails_onboarding/navigation_controller", to: "rails_onboarding/navigation_controller.js"

# Tooltip system controllers
pin "rails_onboarding/tooltip_controller", to: "rails_onboarding/tooltip_controller.js"
pin "rails_onboarding/tooltip_scheduler_controller", to: "rails_onboarding/tooltip_scheduler_controller.js"

# Tour and progressive disclosure
pin "rails_onboarding/tour_controller", to: "rails_onboarding/tour_controller.js"
pin "rails_onboarding/progressive_disclosure_controller", to: "rails_onboarding/progressive_disclosure_controller.js"

# Milestone system controllers
pin "rails_onboarding/milestone_celebration_controller", to: "rails_onboarding/milestone_celebration_controller.js"
pin "rails_onboarding/milestone_dashboard_controller", to: "rails_onboarding/milestone_dashboard_controller.js"
pin "rails_onboarding/milestone_detail_controller", to: "rails_onboarding/milestone_detail_controller.js"

# Admin controllers
pin "rails_onboarding/admin/chart_controller", to: "rails_onboarding/admin/chart_controller.js"
pin "rails_onboarding/admin/filter_controller", to: "rails_onboarding/admin/filter_controller.js"
pin "rails_onboarding/admin/flash_controller", to: "rails_onboarding/admin/flash_controller.js"
pin "rails_onboarding/admin/flow_editor_controller", to: "rails_onboarding/admin/flow_editor_controller.js"

# External dependencies (if using Stimulus from importmap)
# Uncomment if your host app doesn't already pin these
# pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js"
