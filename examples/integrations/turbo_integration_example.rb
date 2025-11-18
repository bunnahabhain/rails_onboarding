# frozen_string_literal: true

# Turbo & Stimulus Integration Example
# This file demonstrates how to use RailsOnboarding with Turbo and Stimulus

# 1. Configure Turbo Integration
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable Turbo Streams (enabled by default)
  config.turbo_streams_enabled = true

  # Enable Turbo Morphing (for Turbo 8+)
  config.turbo_morphing_enabled = false
end

# 2. Include TurboCompatibility in your controller
class ApplicationController < ActionController::Base
  include RailsOnboarding::TurboCompatibility
end

# 3. Use Turbo Frames in views
# app/views/onboarding/show.html.erb
class OnboardingView
  def turbo_frame_example
    <<~ERB
      <%= turbo_frame_tag_for_onboarding "onboarding-container" do %>
        <div class="onboarding-step">
          <%= render partial: "step", locals: { step: @current_step } %>
        </div>
      <% end %>
    ERB
  end
end

# 4. Use Turbo Streams for step updates
class OnboardingController < ApplicationController
  include RailsOnboarding::TurboCompatibility

  def next
    if current_user.advance_to_next_step
      respond_with_turbo(
        replace: "onboarding-container",
        partial: "rails_onboarding/onboarding/step",
        locals: { step: current_user.current_onboarding_step }
      )
    end
  end

  def complete_step
    step_name = params[:step]

    respond_to do |format|
      format.html { redirect_to onboarding_path }
      format.turbo_stream do
        if current_user.complete_step(step_name)
          render turbo_stream: [
            turbo_stream.replace("onboarding-container",
              partial: "step",
              locals: { step: current_user.current_onboarding_step }
            ),
            turbo_stream.replace("progress-bar",
              partial: "progress",
              locals: { progress: current_user.onboarding_progress_percentage }
            )
          ]
        end
      end
    end
  end
end

# 5. Broadcast onboarding updates
class OnboardingController < ApplicationController
  include RailsOnboarding::TurboCompatibility

  def complete
    if current_user.complete_onboarding!
      # Broadcast completion to user's stream
      broadcast_onboarding_update(current_user, :completed, {
        completed_at: current_user.onboarding_completed_at
      })

      redirect_to dashboard_path
    end
  end
end

# 6. Stimulus controller data attributes
class OnboardingHelper
  def stimulus_example
    <<~ERB
      <div <%= stimulus_controller_data('onboarding', {
        step: 'welcome',
        progress: 0,
        total_steps: 4
      }).map { |k, v| "data-#{k}='#{v}'" }.join(' ').html_safe %>>

        <button <%= stimulus_action('click', 'onboarding', 'nextStep').map { |k, v| "data-#{k}='#{v}'" }.join(' ').html_safe %>>
          Next Step
        </button>
      </div>
    ERB
  end
end

# 7. Stimulus controllers
# app/javascript/controllers/onboarding_controller.js
class StimulusOnboardingController
  def example_js
    <<~JS
      import { Controller } from "@hotwired/stimulus"

      export default class extends Controller {
        static values = {
          step: String,
          progress: Number,
          totalSteps: Number
        }

        connect() {
          console.log(`Connected to step: ${this.stepValue}`)
          this.updateProgress()
        }

        nextStep(event) {
          event.preventDefault()

          fetch(this.element.dataset.nextUrl, {
            method: 'POST',
            headers: {
              'Accept': 'text/vnd.turbo-stream.html',
              'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            }
          })
        }

        updateProgress() {
          const progressBar = document.querySelector('[data-progress-target="bar"]')
          if (progressBar) {
            progressBar.style.width = `${this.progressValue}%`
          }
        }
      }
    JS
  end
end

# 8. Turbo helpers in views
class TurboHelpers
  def turbo_helpers_example
    <<~ERB
      <!-- Disable Turbo for skip link -->
      <%= link_to "Skip Onboarding", skip_path, **disable_turbo %>

      <!-- Add confirmation dialog -->
      <%= link_to "Skip", skip_path, **turbo_confirm("Are you sure?") %>

      <!-- Use POST method -->
      <%= link_to "Complete", complete_path, **turbo_method(:post) %>

      <!-- Permanent element (survives page navigation) -->
      <div <%= turbo_permanent.map { |k, v| "#{k}='#{v}'" }.join(' ').html_safe %>>
        <div id="user-avatar">
          <%= image_tag current_user.avatar_url %>
        </div>
      </div>
    ERB
  end
end

# 9. Turbo Native detection
class OnboardingController < ApplicationController
  include RailsOnboarding::TurboCompatibility

  def show
    if turbo_native_app?
      # Render native-optimized view
      render template: "onboarding/native_show"
    else
      # Render web view
      render :show
    end
  end
end

# 10. Testing Turbo integration
RSpec.describe "Turbo Integration" do
  it "responds with turbo stream" do
    sign_in user

    post next_onboarding_path, headers: {
      "Accept" => "text/vnd.turbo-stream.html"
    }

    expect(response.content_type).to include("text/vnd.turbo-stream.html")
    expect(response.body).to include('turbo-stream')
  end

  it "detects turbo frame requests" do
    sign_in user

    get onboarding_path, headers: {
      "Turbo-Frame" => "onboarding-container"
    }

    expect(controller.turbo_frame_request?).to be true
    expect(response).to render_template(layout: false)
  end
end
