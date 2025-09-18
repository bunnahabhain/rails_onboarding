require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    # Disable analytics for milestone tests to avoid Rails 8 polymorphic association issues
    @original_analytics_setting = RailsOnboarding.configuration.enable_analytics
    RailsOnboarding.configuration.enable_analytics = false
  end

  def teardown
    RailsOnboarding.configuration.enable_analytics = @original_analytics_setting
  end

  test "user starts with no milestones" do
    assert_equal [], @user.achieved_milestones
    assert_equal 0, @user.total_milestone_points
    refute @user.milestone_achieved?(:welcome_completed)
  end

  test "achieve_milestone! adds milestone and points" do
    milestone_config = @user.achieve_milestone!(:welcome_completed)

    assert milestone_config
    assert_equal "Welcome Aboard!", milestone_config[:title]
    assert @user.milestone_achieved?(:welcome_completed)
    assert_equal 10, @user.total_milestone_points
    assert_includes @user.achieved_milestones, "welcome_completed"
  end

  test "achieve_milestone! returns false for invalid milestone" do
    result = @user.achieve_milestone!(:invalid_milestone)
    assert_equal false, result
    assert_equal 0, @user.total_milestone_points
  end

  test "achieve_milestone! prevents duplicate achievements" do
    # Achieve milestone first time
    first_result = @user.achieve_milestone!(:welcome_completed)
    assert first_result
    assert_equal 10, @user.total_milestone_points

    # Try to achieve same milestone again
    second_result = @user.achieve_milestone!(:welcome_completed)
    assert_equal false, second_result
    assert_equal 10, @user.total_milestone_points # Points unchanged
  end

  test "milestones_available returns unachieved milestones" do
    available = @user.milestones_available

    # All milestones should be available initially
    assert_equal 3, available.length
    assert available.any? { |m| m[:key] == :welcome_completed }

    # After achieving one, it should no longer be available
    @user.achieve_milestone!(:welcome_completed)
    available_after = @user.milestones_available

    assert_equal 2, available_after.length
    refute available_after.any? { |m| m[:key] == :welcome_completed }
  end

  test "recent_milestones returns recently achieved milestones" do
    # Achieve multiple milestones from the default configuration
    @user.achieve_milestone!(:welcome_completed)
    @user.achieve_milestone!(:onboarding_completed)

    recent = @user.recent_milestones(limit: 2)

    assert_equal 2, recent.length
    assert_equal :onboarding_completed, recent.last[:key]
    assert_equal :welcome_completed, recent.first[:key]
  end

  test "milestone serialization handles JSON properly" do
    @user.achieve_milestone!(:welcome_completed)
    @user.achieve_milestone!(:onboarding_completed)

    @user.reload

    assert_equal 2, @user.achieved_milestones.length
    assert_includes @user.achieved_milestones, "welcome_completed"
    assert_includes @user.achieved_milestones, "onboarding_completed"
    assert_equal 60, @user.total_milestone_points # 10 + 50
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
