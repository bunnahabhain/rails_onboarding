# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  class ApiModeTest < ActiveSupport::TestCase
    # Minimal stand-in exposing just what extract_api_token touches. Including
    # ApiMode on a plain class exercises its `included` block, whose
    # ActionController-only setup is guarded and skipped here.
    class FakeRequest
      attr_reader :headers

      def initialize(headers)
        @headers = headers
      end
    end

    class FakeController
      include RailsOnboarding::ApiMode

      attr_reader :request, :params

      def initialize(headers: {}, params: {})
        @request = FakeRequest.new(headers)
        @params = params
      end
    end

    def token_for(headers: {}, params: {})
      FakeController.new(headers: headers, params: params).send(:extract_api_token)
    end

    test "reads a bearer token from the Authorization header" do
      assert_equal "secret-token", token_for(headers: { "Authorization" => "Bearer secret-token" })
    end

    test "reads a bare token from the Authorization header" do
      assert_equal "secret-token", token_for(headers: { "Authorization" => "secret-token" })
    end

    test "reads a token from the X-API-Token header" do
      assert_equal "header-token", token_for(headers: { "X-API-Token" => "header-token" })
    end

    test "ignores a token supplied as a query parameter" do
      # A token in the URL leaks into logs, browser history, and Referer
      # headers, so it must never be accepted from params.
      assert_nil token_for(params: { api_token: "leaky-token", "api_token" => "leaky-token" })
    end

    test "returns nil when no token is present" do
      assert_nil token_for
    end
  end
end
