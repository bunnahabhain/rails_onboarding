require "test_helper"

class TourTest < ActionDispatch::IntegrationTest
  test "tour controller file exists" do
    controller_path = Rails.root.join("..", "..", "app", "assets", "javascripts", "rails_onboarding", "tour_controller.js")
    assert File.exist?(controller_path), "Tour controller file should exist"
  end

  test "tour controller has proper Stimulus structure" do
    controller_path = Rails.root.join("..", "..", "app", "assets", "javascripts", "rails_onboarding", "tour_controller.js")
    content = File.read(controller_path)

    # Check for Stimulus controller definition
    assert_match(/import.*Controller.*from.*@hotwired\/stimulus/, content, "Should import Stimulus Controller")
    assert_match(/export default class extends Controller/, content, "Should export Stimulus controller class")

    # Check for essential methods
    assert_match(/connect\(\)/, content, "Should have connect() method")
    assert_match(/start\(\)/, content, "Should have start() method")
    assert_match(/stop\(\)/, content, "Should have stop() method")
    assert_match(/next\(\)/, content, "Should have next() method")
    assert_match(/previous\(\)/, content, "Should have previous() method")
    assert_match(/showStep\(/, content, "Should have showStep() method")

    # Check for overlay/modal creation
    assert_match(/createOverlay/, content, "Should have createOverlay method")
    assert_match(/createPopup/, content, "Should have createPopup method")
    assert_match(/createHighlight/, content, "Should have createHighlight method")
  end

  test "tour CSS file exists" do
    css_path = Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "tour.css")
    assert File.exist?(css_path), "Tour CSS file should exist"
  end

  test "tour CSS has proper styles" do
    css_path = Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "tour.css")
    content = File.read(css_path)

    # Check for essential CSS classes
    assert_match(/\.tour-overlay/, content, "Should define tour-overlay class")
    assert_match(/\.tour-spotlight/, content, "Should define tour-spotlight class")
    assert_match(/\.tour-popup/, content, "Should define tour-popup class")
    assert_match(/\.tour-btn/, content, "Should define tour button classes")
    assert_match(/\.tour-progress/, content, "Should define progress indicator classes")
  end

  test "tour CSS is included in application stylesheet" do
    app_css_path = Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "application.css")
    content = File.read(app_css_path)

    assert_match(/require.*rails_onboarding\/tour/, content, "Tour CSS should be required in application.css")
  end
end
