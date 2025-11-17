require "test_helper"
require "webmock/minitest"

module RailsOnboarding
  class WebhooksTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @webhook_url = "https://example.com/webhook"

      RailsOnboarding.configure do |config|
        config.webhook_url = @webhook_url
        config.webhook_events = [ :onboarding_completed, :step_completed ]
      end
    end

    test "sends webhook on onboarding_completed event" do
      stub_request(:post, @webhook_url)
        .with(
          body: hash_including(
            event: "onboarding_completed",
            user_id: @user.id
          )
        )
        .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_requested :post, @webhook_url
    end

    test "sends webhook on step_completed event" do
      stub_request(:post, @webhook_url)
        .with(
          body: hash_including(
            event: "step_completed",
            user_id: @user.id
          )
        )
        .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:step_completed, @user, step: "welcome")

      assert_requested :post, @webhook_url
    end

    test "does not send webhook for unconfigured events" do
      stub_request(:post, @webhook_url)

      RailsOnboarding::Webhooks.trigger(:unknown_event, @user)

      assert_not_requested :post, @webhook_url
    end

    test "handles webhook failures gracefully" do
      stub_request(:post, @webhook_url)
        .to_return(status: 500)

      assert_nothing_raised do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    end

    test "includes custom data in webhook payload" do
      stub_request(:post, @webhook_url)
        .with(
          body: hash_including(
            custom_field: "custom_value"
          )
        )
        .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(
        :onboarding_completed,
        @user,
        custom_field: "custom_value"
      )

      assert_requested :post, @webhook_url
    end
  end
end
