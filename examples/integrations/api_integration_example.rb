# frozen_string_literal: true

# API Mode Integration Example
# This file demonstrates how to use RailsOnboarding as a headless API

# 1. Configure API Mode
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable API mode
  config.api_mode_enabled = true

  # Configure authentication method
  config.api_authentication_method = :token # or :bearer
end

# 2. User model with API token
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  # Generate secure API token
  has_secure_token :api_token

  # Find user by API token
  def self.find_by_api_token(token)
    find_by(api_token: token)
  end

  # Regenerate API token
  def regenerate_api_token
    regenerate_api_token
  end
end

# 3. Migration for API token
class AddApiTokenToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :api_token, :string
    add_index :users, :api_token, unique: true
  end
end

# 4. Using the API endpoints
class ApiClientExample
  def initialize(api_token)
    @api_token = api_token
    @base_url = "https://example.com"
  end

  # Get onboarding status
  def get_status
    response = HTTP
      .auth("Bearer #{@api_token}")
      .get("#{@base_url}/rails_onboarding/api/v1/onboarding/status")

    JSON.parse(response.body)
  end

  # Complete a step
  def complete_step(step_name)
    response = HTTP
      .auth("Bearer #{@api_token}")
      .post("#{@base_url}/rails_onboarding/api/v1/onboarding/steps/#{step_name}/complete")

    JSON.parse(response.body)
  end

  # Skip a step
  def skip_step(step_name)
    response = HTTP
      .auth("Bearer #{@api_token}")
      .post("#{@base_url}/rails_onboarding/api/v1/onboarding/steps/#{step_name}/skip")

    JSON.parse(response.body)
  end

  # Complete onboarding
  def complete_onboarding
    response = HTTP
      .auth("Bearer #{@api_token}")
      .post("#{@base_url}/rails_onboarding/api/v1/onboarding/complete")

    JSON.parse(response.body)
  end

  # Get tooltips
  def get_tooltips
    response = HTTP
      .auth("Bearer #{@api_token}")
      .get("#{@base_url}/rails_onboarding/api/v1/tooltips")

    JSON.parse(response.body)
  end

  # Dismiss a tooltip
  def dismiss_tooltip(tooltip_id)
    response = HTTP
      .auth("Bearer #{@api_token}")
      .post("#{@base_url}/rails_onboarding/api/v1/tooltips/#{tooltip_id}/dismiss")

    JSON.parse(response.body)
  end
end

# 5. React Native / Mobile App Integration
class MobileAppIntegration
  def example_javascript
    <<~JS
      // React Native example
      import AsyncStorage from '@react-native-async-storage/async-storage';

      class OnboardingAPI {
        constructor(baseURL, apiToken) {
          this.baseURL = baseURL;
          this.apiToken = apiToken;
        }

        async getStatus() {
          const response = await fetch(`${this.baseURL}/api/v1/onboarding/status`, {
            method: 'GET',
            headers: {
              'Authorization': `Bearer ${this.apiToken}`,
              'Content-Type': 'application/json'
            }
          });

          return await response.json();
        }

        async completeStep(stepName) {
          const response = await fetch(
            `${this.baseURL}/api/v1/onboarding/steps/${stepName}/complete`,
            {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${this.apiToken}`,
                'Content-Type': 'application/json'
              }
            }
          );

          return await response.json();
        }

        async completeOnboarding() {
          const response = await fetch(`${this.baseURL}/api/v1/onboarding/complete`, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${this.apiToken}`,
              'Content-Type': 'application/json'
            }
          });

          const data = await response.json();

          // Cache completion status
          await AsyncStorage.setItem('onboarding_completed', 'true');

          return data;
        }
      }

      // Usage in React Native component
      import React, { useState, useEffect } from 'react';
      import { View, Text, Button } from 'react-native';

      const OnboardingScreen = ({ apiToken }) => {
        const [status, setStatus] = useState(null);
        const api = new OnboardingAPI('https://example.com', apiToken);

        useEffect(() => {
          loadStatus();
        }, []);

        const loadStatus = async () => {
          const data = await api.getStatus();
          if (data.success) {
            setStatus(data.data);
          }
        };

        const handleCompleteStep = async (stepName) => {
          const result = await api.completeStep(stepName);
          if (result.success) {
            await loadStatus(); // Refresh status
          }
        };

        return (
          <View>
            <Text>Progress: {status?.progress_percentage}%</Text>
            <Text>Current Step: {status?.current_step}</Text>
            <Button
              title="Complete Step"
              onPress={() => handleCompleteStep(status.current_step)}
            />
          </View>
        );
      };
    JS
  end
end

# 6. Custom API controller with additional endpoints
module Api
  module V1
    class CustomOnboardingController < RailsOnboarding::Api::V1::OnboardingController
      # Add custom endpoint
      def user_onboarding_data
        render_api_success({
          user: {
            id: current_user.id,
            email: current_user.email,
            onboarding_completed: current_user.onboarding_completed?,
            onboarding_progress: current_user.onboarding_progress_percentage,
            current_step: current_user.onboarding_current_step,
            steps_completed: current_user.completed_steps,
            milestones_achieved: current_user.achieved_milestones
          }
        })
      end
    end
  end
end

# 7. API error handling
class ApplicationController < ActionController::API
  include RailsOnboarding::ApiMode

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render_api_error("Resource not found", status: :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |exception|
    render_api_error(
      "Validation failed",
      status: :unprocessable_entity,
      errors: exception.record.errors.full_messages
    )
  end

  rescue_from StandardError do |exception|
    Rails.logger.error("API Error: #{exception.message}")
    render_api_error(
      "An error occurred",
      status: :internal_server_error
    )
  end
end

# 8. Testing the API
RSpec.describe "API Integration" do
  let(:user) { create(:user) }
  let(:token) { user.api_token }

  describe "GET /api/v1/onboarding/status" do
    it "returns onboarding status" do
      get "/rails_onboarding/api/v1/onboarding/status",
          headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]).to have_key("onboarding_completed")
      expect(json["data"]).to have_key("current_step")
      expect(json["data"]).to have_key("progress_percentage")
    end
  end

  describe "POST /api/v1/onboarding/steps/:step_name/complete" do
    it "completes a step" do
      post "/rails_onboarding/api/v1/onboarding/steps/welcome/complete",
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]["message"]).to include("completed successfully")
    end
  end

  describe "POST /api/v1/onboarding/complete" do
    it "completes onboarding" do
      user.update(onboarding_current_step: 'explore')

      post "/rails_onboarding/api/v1/onboarding/complete",
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      user.reload
      expect(user.onboarding_completed?).to be true
    end
  end
end
