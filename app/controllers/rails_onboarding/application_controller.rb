module RailsOnboarding
  class ApplicationController < ApplicationController
    # Inherits from the host app's ApplicationController
    # This gives us access to:
    # - current_user method
    # - authentication filters
    # - any other helpers defined in the host app
  end
end
