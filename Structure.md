#!/bin/bash

# Create the Rails engine
rails plugin new rails_onboarding --mountable

# Directory structure for the engine
cd rails_onboarding

# The generated structure will be:
# rails_onboarding/
# ├── Gemfile
# ├── MIT-LICENSE
# ├── README.md
# ├── Rakefile
# ├── rails_onboarding.gemspec
# ├── app/
# │   ├── assets/
# │   │   ├── javascripts/
# │   │   │   └── rails_onboarding/
# │   │   │       └── application.js
# │   │   └── stylesheets/
# │   │       └── rails_onboarding/
# │   │           └── application.css
# │   ├── controllers/
# │   │   └── rails_onboarding/
# │   │       ├── application_controller.rb
# │   │       └── onboarding_controller.rb
# │   ├── helpers/
# │   │   └── rails_onboarding/
# │   │       └── application_helper.rb
# │   ├── models/
# │   │   └── rails_onboarding/
# │   │       └── application_record.rb
# │   └── views/
# │       └── rails_onboarding/
# │           └── onboarding/
# ├── config/
# │   └── routes.rb
# ├── db/
# │   └── migrate/
# ├── lib/
# │   ├── rails_onboarding/
# │   │   ├── configuration.rb
# │   │   ├── engine.rb
# │   │   └── version.rb
# │   ├── rails_onboarding.rb
# │   └── tasks/
# │       └── rails_onboarding_tasks.rake
# └── test/
