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

  # The regressions fixed in 0.8.8. Each of these was a silent failure: the tour
  # looked configured and simply misbehaved at runtime.

  test "popup teardown closes over the node, not the instance property" do
    remove_popup = code[/    removePopup\(\) \{.*?\n    \}/m]

    refute_nil remove_popup, "removePopup() should be defined"
    assert_match(/const popup = this\.popup/, remove_popup,
      "removePopup must capture the node in a local - createPopup() assigns a new " \
      "this.popup straight after calling it, so a timeout reading the instance " \
      "property tears down the replacement and blanks the tour on every Next")
    refute_match(/setTimeout\(\(\) => \{[^}]*this\.popup/m, remove_popup,
      "the removal timeout must not read this.popup")
  end

  test "stylePopup sets no colours inline" do
    style_popup = code[/    stylePopup\(step\) \{.*?\n    \}/m]

    refute_nil style_popup, "stylePopup() should be defined"
    refute_match(/background/, style_popup,
      "an inline background beats tour.css and any host token override, which is " \
      "what made the popup white on a dark page")
    refute_match(/cssText/, style_popup, "stylePopup should not rewrite cssText wholesale")
  end

  test "highlight is restored by reference rather than a document sweep" do
    refute_match(/querySelectorAll\('\[style\*="z-index/, code,
      "sweeping the document for an inline z-index clears unrelated host elements")
    assert_match(/this\.highlightedElement = element/, code,
      "createHighlight should record the element it changed")
  end

  test "the tour does not lock body scroll" do
    create_overlay = code[/    createOverlay\(\) \{.*?\n    \}/m]

    refute_nil create_overlay, "createOverlay() should be defined"
    refute_match(/body\.style\.overflow/, create_overlay,
      "locking the body makes scrollToElement's window.scrollTo a no-op, so a step " \
      "below the fold is spotlit off-screen")
    assert_match(/repositionCurrentStep\(\)/, code,
      "the highlight must instead be repositioned as the viewport moves")
  end

  test "tour CSS is themed by tokens, not hardcoded colours" do
    content = File.read(css_path)

    refute_match(/#[0-9a-fA-F]{3,6}\b/, content,
      "tour.css should carry no hardcoded hex colours - a host redefining the " \
      "--onboarding-* tokens must be able to theme the tour")
    refute_match(/background:\s*white/, content, "the popup background must be a token")
    assert_match(/var\(--onboarding-surface-elevated\)/, content)
    assert_match(/var\(--onboarding-primary-fill\)/, content)
  end

  test "tour CSS defines no dark-mode block of its own" do
    content = File.read(css_path)

    refute_match(/prefers-color-scheme/, content,
      "application.css flips the --onboarding-* tokens centrally; a local dark block " \
      "fights both it and the host's overrides")
  end

  private

  # Comments are stripped so an assertion cannot be satisfied - or defeated - by
  # prose. Several of these comments deliberately quote the construct they warn
  # against, which would otherwise match.
  def code
    @code ||= File.read(controller_path).gsub(%r{^\s*//.*$}, "")
  end

  def controller_path
    Rails.root.join("..", "..", "app", "assets", "javascripts", "rails_onboarding", "tour_controller.js")
  end

  def css_path
    Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "tour.css")
  end
end
