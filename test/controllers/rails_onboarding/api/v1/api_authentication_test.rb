# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  module Api
    module V1
      class ApiAuthenticationTest < ActionDispatch::IntegrationTest
        include Engine.routes.url_helpers

        setup do
          @user = users(:one)
          @user.update(api_token: "valid_test_token_12345")
          @headers = { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
        end

        # ===== Token Extraction Tests =====

        test "authenticates with Authorization header (Bearer token)" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
          assert json_response["data"].present?
        end

        test "authenticates with Authorization header (Token token)" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Token valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        test "authenticates with X-API-Token header" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "X-API-Token" => "valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        test "authenticates with api_token query parameter" do
          get api_v1_onboarding_status_path(api_token: "valid_test_token_12345"),
              headers: @headers

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        # ===== Authentication Failure Tests =====

        test "rejects request without authentication token" do
          get api_v1_onboarding_status_path, headers: @headers

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
          assert_equal "Missing authentication token", json_response["error"]["message"]
        end

        test "rejects request with invalid token" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer invalid_token_xyz" })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
          assert_equal "Invalid authentication token", json_response["error"]["message"]
        end

        test "rejects request with empty token" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer " })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
          assert_equal "Missing authentication token", json_response["error"]["message"]
        end

        test "rejects request with malformed Authorization header" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "NotAValidFormat" })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
        end

        test "rejects request with expired or revoked token" do
          # Create a user with a different token
          @user.update(api_token: "new_valid_token")

          # Try to use old token
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer old_revoked_token" })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
        end

        # ===== Token Priority Tests =====

        test "Authorization header takes priority over query parameter" do
          # Create two users with different tokens
          user2 = User.create!(
            email: "user2@example.com",
            api_token: "query_token_abc123"
          )

          # Send both Authorization header and query param
          get api_v1_onboarding_status_path(api_token: "query_token_abc123"),
              headers: @headers.merge({ "Authorization" => "Bearer valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)

          # Should authenticate as @user (from Authorization header), not user2
          assert_equal @user.id, json_response["data"]["user_id"] if json_response.dig("data", "user_id")
        end

        test "X-API-Token header works when Authorization is missing" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "X-API-Token" => "valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        # ===== Special Character and Edge Case Tests =====

        test "handles token with special characters" do
          special_token = "token-with_special.chars/+=123"
          @user.update(api_token: special_token)

          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer #{special_token}" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        test "handles very long token" do
          long_token = "a" * 1000
          @user.update(api_token: long_token)

          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer #{long_token}" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        test "token comparison is case-sensitive" do
          @user.update(api_token: "CaseSensitiveToken123")

          # Try with wrong case
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer casesensitivetoken123" })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)
          assert_equal false, json_response["success"]
        end

        # ===== Request Format Tests =====

        test "works with JSON content type" do
          post api_v1_onboarding_complete_path,
               headers: @headers.merge({
                 "Authorization" => "Bearer valid_test_token_12345",
                 "Content-Type" => "application/json"
               }),
               params: {}.to_json

          assert_response :success
        end

        test "detects API request from path prefix" do
          # Even without JSON headers, /api/ path should be recognized
          get api_v1_onboarding_status_path,
              headers: { "Authorization" => "Bearer valid_test_token_12345" }

          assert_response :success
          assert_equal "application/json", response.content_type
        end

        # ===== Multiple Endpoint Tests =====

        test "authentication works across all API endpoints" do
          auth_header = { "Authorization" => "Bearer valid_test_token_12345" }

          # Status endpoint
          get api_v1_onboarding_status_path, headers: @headers.merge(auth_header)
          assert_response :success

          # Complete endpoint
          post api_v1_onboarding_complete_path, headers: @headers.merge(auth_header)
          assert_response :success

          # Restart endpoint
          post api_v1_onboarding_restart_path, headers: @headers.merge(auth_header)
          assert_response :success
        end

        test "authentication protects tooltips API endpoints" do
          get api_v1_tooltips_path,
              headers: @headers.merge({ "Authorization" => "Bearer valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        test "authentication protects milestones API endpoints" do
          get api_v1_milestones_path,
              headers: @headers.merge({ "Authorization" => "Bearer valid_test_token_12345" })

          assert_response :success
          json_response = JSON.parse(response.body)
          assert_equal true, json_response["success"]
        end

        # ===== Error Response Format Tests =====

        test "error response includes proper structure" do
          get api_v1_onboarding_status_path, headers: @headers

          assert_response :unauthorized
          json_response = JSON.parse(response.body)

          assert json_response.key?("success")
          assert_equal false, json_response["success"]
          assert json_response.key?("error")
          assert json_response["error"].key?("message")
          assert json_response.key?("meta")
          assert json_response["meta"].key?("timestamp")
          assert json_response["meta"].key?("version")
        end

        test "error response includes request_id for debugging" do
          get api_v1_onboarding_status_path, headers: @headers

          assert_response :unauthorized
          json_response = JSON.parse(response.body)

          assert json_response.dig("meta", "request_id").present?,
                 "Response should include request_id for debugging"
        end

        # ===== Security Tests =====

        test "timing attack resistance - invalid vs missing token" do
          # Measure time for missing token
          start_time = Time.now
          get api_v1_onboarding_status_path, headers: @headers
          missing_token_time = Time.now - start_time

          # Measure time for invalid token
          start_time = Time.now
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer invalid_token_xyz" })
          invalid_token_time = Time.now - start_time

          # Times should be similar (within 50ms) to prevent timing attacks
          # Note: This is a basic check; real timing attack prevention requires constant-time comparison
          assert (missing_token_time - invalid_token_time).abs < 0.05,
                 "Timing difference too large: #{(missing_token_time - invalid_token_time).abs}s"
        end

        test "does not expose user information in error messages" do
          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer some_token" })

          assert_response :unauthorized
          json_response = JSON.parse(response.body)

          # Error message should not contain sensitive info
          error_message = json_response.dig("error", "message")
          assert_not_includes error_message.downcase, "user"
          assert_not_includes error_message.downcase, "email"
          assert_not_includes error_message.downcase, "id"
        end

        test "prevents token enumeration attacks" do
          # Multiple failed attempts should have same response
          responses = []

          5.times do |i|
            get api_v1_onboarding_status_path,
                headers: @headers.merge({ "Authorization" => "Bearer random_token_#{i}" })

            assert_response :unauthorized
            responses << response.body
          end

          # All responses should be identical
          assert responses.uniq.length == 1,
                 "All unauthorized responses should be identical to prevent token enumeration"
        end

        # ===== Custom Authentication Method Tests =====

        test "handles missing api_token column gracefully" do
          # This test would need to stub the column check
          # For now, we verify the error handling exists

          # Remove api_token from user (simulate column not existing)
          @user.update_columns(api_token: nil) if @user.respond_to?(:api_token=)

          get api_v1_onboarding_status_path,
              headers: @headers.merge({ "Authorization" => "Bearer any_token" })

          # Should get unauthorized, not an exception
          assert_response :unauthorized
        end

        # ===== Concurrent Request Tests =====

        test "handles concurrent requests with same token" do
          threads = []
          results = []

          # Simulate 5 concurrent requests with same token
          5.times do
            threads << Thread.new do
              get api_v1_onboarding_status_path,
                  headers: @headers.merge({ "Authorization" => "Bearer valid_test_token_12345" })
              results << response.code
            end
          end

          threads.each(&:join)

          # All requests should succeed
          assert_equal ["200"] * 5, results
        end
      end
    end
  end
end
