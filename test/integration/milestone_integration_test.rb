require "test_helper"

class MilestoneIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # This would be set up with proper test database and user model in a real implementation
    # For now, we'll test the routing and controller structure
  end

  test "milestone routes are properly configured" do
    # Test that milestone routes exist in the engine routes
    routes = RailsOnboarding::Engine.routes.routes.map(&:defaults)

    milestone_routes = routes.select { |r| r[:controller] == "rails_onboarding/milestones" }
    assert milestone_routes.any?, "Milestone routes should be configured"

    # Test that specific actions are configured
    index_route = milestone_routes.find { |r| r[:action] == "index" }
    assert index_route, "Index route should be configured"

    show_route = milestone_routes.find { |r| r[:action] == "show" }
    assert show_route, "Show route should be configured"
  end

  test "milestone configuration methods work correctly" do
    config = RailsOnboarding.configuration

    # First verify we have milestones at all
    assert config.milestones.any?, "Configuration should have milestones"
    assert_equal 5, config.milestones.length, "Should have 5 total milestones"

    # Test milestone_by_key
    welcome_milestone = config.milestone_by_key(:welcome_completed)
    assert welcome_milestone, "Should find welcome_completed milestone"
    assert_equal "Welcome Aboard!", welcome_milestone[:title]
    assert_equal 10, welcome_milestone[:points]

    # Debug: Check what triggers exist
    triggers = config.milestones.map { |m| m[:trigger] }.uniq
    assert_includes triggers, :onboarding_step_completed, "Should have onboarding_step_completed trigger"

    # Test milestones_for_trigger - for onboarding step completion (without conditions)
    step_milestones = config.milestones_for_trigger(:onboarding_step_completed)
    assert_equal 3, step_milestones.length, "Should have exactly 3 step completion milestones, got #{step_milestones.length}"
    assert step_milestones.any? { |m| m[:key] == :welcome_completed }, "Should include welcome milestone"

    # Test milestones_for_trigger with conditions
    welcome_milestones = config.milestones_for_trigger(:onboarding_step_completed, { step: :welcome })
    assert_equal 1, welcome_milestones.length
    assert_equal :welcome_completed, welcome_milestones.first[:key]
  end

  test "milestone CSS and JavaScript files exist" do
    # Test that milestone assets exist
    gem_root = File.expand_path("../../..", __FILE__)
    milestone_css = File.join(gem_root, "app/assets/stylesheets/rails_onboarding/milestones.css")
    assert File.exist?(milestone_css), "Milestone CSS file should exist"

    celebration_js = File.join(gem_root, "app/assets/javascripts/rails_onboarding/milestone_celebration_controller.js")
    assert File.exist?(celebration_js), "Milestone celebration JS controller should exist"

    dashboard_js = File.join(gem_root, "app/assets/javascripts/rails_onboarding/milestone_dashboard_controller.js")
    assert File.exist?(dashboard_js), "Milestone dashboard JS controller should exist"
  end

  test "milestone view templates exist" do
    # Test that milestone view templates exist
    gem_root = File.expand_path("../../..", __FILE__)
    index_view = File.join(gem_root, "app/views/rails_onboarding/milestones/index.html.erb")
    assert File.exist?(index_view), "Milestone index view should exist"

    show_view = File.join(gem_root, "app/views/rails_onboarding/milestones/show.html.erb")
    assert File.exist?(show_view), "Milestone show view should exist"

    celebration_partial = File.join(gem_root, "app/views/rails_onboarding/shared/_milestone_celebration.html.erb")
    assert File.exist?(celebration_partial), "Milestone celebration partial should exist"

    badge_partial = File.join(gem_root, "app/views/rails_onboarding/shared/_milestone_badge.html.erb")
    assert File.exist?(badge_partial), "Milestone badge partial should exist"
  end

  test "milestone service is properly namespaced" do
    assert defined?(RailsOnboarding::MilestoneService)
    assert RailsOnboarding::MilestoneService.respond_to?(:check_and_award_milestones)
    assert RailsOnboarding::MilestoneService.respond_to?(:check_onboarding_step_milestones)
    assert RailsOnboarding::MilestoneService.respond_to?(:check_onboarding_completion_milestones)
  end

  test "milestone controller is properly namespaced" do
    assert defined?(RailsOnboarding::MilestonesController)
    controller = RailsOnboarding::MilestonesController.new

    # Test that controller responds to expected actions
    assert controller.respond_to?(:index, true)
    assert controller.respond_to?(:show, true)
    assert controller.respond_to?(:achieve, true)
    assert controller.respond_to?(:recent, true)
  end

  test "milestone migration template exists" do
    gem_root = File.expand_path("../../..", __FILE__)
    migration_template = File.join(gem_root, "lib/generators/rails_onboarding/templates/add_milestone_tracking_to_users.rb")
    assert File.exist?(migration_template), "Milestone migration template should exist"

    # Check migration content has required fields
    migration_content = File.read(migration_template)
    assert_includes migration_content, "milestones_achieved"
    assert_includes migration_content, "milestone_points"
    assert_includes migration_content, "last_milestone_at"
  end
end
