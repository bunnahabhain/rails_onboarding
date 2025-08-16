require "test_helper"

class MilestoneServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    # Disable analytics for milestone service tests to avoid Rails 8 polymorphic association issues
    @original_analytics_setting = RailsOnboarding.configuration.enable_analytics
    RailsOnboarding.configuration.enable_analytics = false
  end

  def teardown
    RailsOnboarding.configuration.enable_analytics = @original_analytics_setting
  end

  test "check_onboarding_step_milestones awards appropriate milestone" do
    awarded = RailsOnboarding::MilestoneService.check_onboarding_step_milestones(@user, :welcome)

    assert_equal 1, awarded.length
    assert_equal :welcome_completed, awarded.first[:key]
    assert @user.milestone_achieved?(:welcome_completed)
    assert_equal 10, @user.total_milestone_points
  end

  test "check_onboarding_completion_milestones awards completion milestone" do
    awarded = RailsOnboarding::MilestoneService.check_onboarding_completion_milestones(@user)

    assert_equal 1, awarded.length
    assert_equal :onboarding_completed, awarded.first[:key]
    assert @user.milestone_achieved?(:onboarding_completed)
    assert_equal 50, @user.total_milestone_points
  end

  test "check_early_adopter_milestone awards for recent users" do
    # User created within the last hour
    @user.created_at = 30.minutes.ago

    awarded = RailsOnboarding::MilestoneService.check_early_adopter_milestone(@user)

    assert_equal 1, awarded.length
    assert_equal :early_adopter, awarded.first[:key]
    assert @user.milestone_achieved?(:early_adopter)
    assert_equal 100, @user.total_milestone_points
  end

  test "check_early_adopter_milestone does not award for old users" do
    # User created more than an hour ago
    @user.created_at = 2.hours.ago

    awarded = RailsOnboarding::MilestoneService.check_early_adopter_milestone(@user)

    assert_equal 0, awarded.length
    refute @user.milestone_achieved?(:early_adopter)
    assert_equal 0, @user.total_milestone_points
  end

  test "check_and_award_milestones with custom trigger and conditions" do
    awarded = RailsOnboarding::MilestoneService.check_and_award_milestones(
      @user,
      :onboarding_step_completed,
      { step: :profile }
    )

    assert_equal 1, awarded.length
    assert_equal :profile_completed, awarded.first[:key]
    assert_equal 25, @user.total_milestone_points
  end

  test "does not award milestone if conditions don't match" do
    awarded = RailsOnboarding::MilestoneService.check_and_award_milestones(
      @user,
      :onboarding_step_completed,
      { step: :nonexistent_step }
    )

    assert_equal 0, awarded.length
    assert_equal 0, @user.total_milestone_points
  end

  test "does not award if milestones are disabled" do
    # Temporarily disable milestones
    original_setting = RailsOnboarding.configuration.enable_milestones
    RailsOnboarding.configuration.enable_milestones = false

    awarded = RailsOnboarding::MilestoneService.check_onboarding_step_milestones(@user, :welcome)

    assert_equal 0, awarded.length
    assert_equal 0, @user.total_milestone_points

    # Restore original setting
    RailsOnboarding.configuration.enable_milestones = original_setting
  end

  test "does not award already achieved milestones" do
    # Achieve milestone first
    @user.achieve_milestone!(:welcome_completed)
    initial_points = @user.total_milestone_points

    # Try to award same milestone again
    awarded = RailsOnboarding::MilestoneService.check_onboarding_step_milestones(@user, :welcome)

    assert_equal 0, awarded.length
    assert_equal initial_points, @user.total_milestone_points
  end

  test "handles nil user gracefully" do
    awarded = RailsOnboarding::MilestoneService.check_onboarding_step_milestones(nil, :welcome)
    assert_equal 0, awarded.length
  end

  private

  def create_test_user
    # Create a proper test user class instead of using deprecated OpenStruct
    test_user_class = Class.new do
      # Mock columns_hash for serialize to work (must be defined before include)
      def self.columns_hash
        {}
      end

      include RailsOnboarding::Onboardable

      attr_accessor :milestones_achieved, :milestone_points, :last_milestone_at, :created_at,
                    :onboarding_completed, :onboarding_completed_at, :onboarding_current_step,
                    :onboarding_skipped, :feature_tooltips_shown

      def initialize
        @milestones_achieved = []
        @milestone_points = 0
        @last_milestone_at = nil
        @created_at = Time.current
        @onboarding_completed = false
        @onboarding_completed_at = nil
        @onboarding_current_step = nil
        @onboarding_skipped = false
        @feature_tooltips_shown = {}
      end

      def save!
        true
      end

      def update!(attributes)
        attributes.each do |key, value|
          send("#{key}=", value)
        end
      end

      def reload
        self
      end
    end

    test_user_class.new
  end
end
