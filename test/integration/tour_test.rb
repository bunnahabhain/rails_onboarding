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

  # The popup is appended to document.body, which is outside every controller
  # scope - so Stimulus silently never binds a data-action placed on it, and the
  # tour could not be advanced at all.
  test "popup controls are bound directly rather than by data-action" do
    refute_match(/data-action="click->tour#/, code,
      "a data-action on the popup is inert: it is built onto document.body, " \
      "outside the controller's scope")
    assert_match(/bindPopupActions\(\)/, code, "the buttons must be wired directly")

    bind = code[/    bindPopupActions\(\) \{.*?\n    \}/m]
    refute_nil bind, "bindPopupActions() should be defined"
    %w[tour-btn-next tour-btn-prev tour-btn-skip].each do |button|
      assert_match(/#{button}/, bind, "#{button} should be wired")
    end
  end

  # The overlay and a spotlight's box-shadow are each a full-viewport scrim, so painting
  # both darkened every pixel twice - ~0.92 at the default 0.7.
  test "the scrim is painted once, not layered twice" do
    apply = code[/    applyScrim\(step, targetElement\) \{.*?\n    \}/m]

    refute_nil apply, "applyScrim() should be defined"
    assert_match(/highlightStyle === 'spotlight'/, apply,
      "applyScrim should branch on whether this step draws its own scrim")
    assert_match(/'transparent'/, apply,
      "the overlay must not paint while a spotlight is already scrimming the viewport")
    assert_match(/rgba\(0, 0, 0, \$\{this\.overlayOpacityValue\}\)/, apply,
      "every other highlight style still needs the overlay to paint")

    create_highlight = code[/    createHighlight\(element, step\) \{.*?\n    \}/m]
    refute_match(/box-shadow: 0 0 0 9999px/, create_highlight,
      "the spotlight scrim belongs to tour.css via --onboarding-tour-scrim; an inline " \
      "box-shadow here would duplicate it")
  end

  # An animation on box-shadow overrides the inline value, which is what made
  # overlayOpacity do nothing for a spotlight.
  test "overlayOpacity actually reaches the spotlight scrim" do
    assert_match(/setProperty\(\s*'--onboarding-tour-scrim', this\.overlayOpacityValue/m, code,
      "the controller must publish its opacity for tour.css to consume")

    css = File.read(css_path)
    assert_match(/0 0 0 9999px rgba\(0, 0, 0, var\(--onboarding-tour-scrim/, css)
    refute_match(/spotlightPulse/, css,
      "animating the scrim overrides the inline value and pulses the whole page rather " \
      "than the highlight")
  end

  # The highlighted element is lifted above the overlay so a tour can say "click here
  # to continue". For an informational tour that is a trap: a link inside the spotlight
  # navigates away, and the tour is lost or restarted from step one.
  test "interaction with the highlighted element can be switched off" do
    assert_match(/allowInteraction: \{ type: Boolean, default: true \}/, code,
      "the default must stay true, so existing click-to-continue tours are unaffected")
    assert_match(/step\.allowInteraction \?\? this\.allowInteractionValue/, code,
      "a step should be able to override the controller-wide setting")

    create_highlight = code[/    createHighlight\(element, step\) \{.*?\n    \}/m]
    assert_match(/allowInteraction === false/, create_highlight)
    assert_match(/pointerEvents = 'none'/, create_highlight,
      "clicks should fall through to the overlay, which swallows them")

    remove_highlight = code[/    removeHighlight\(\) \{.*?\n    \}/m]
    assert_match(/pointerEvents = this\.previousElementPointerEvents/, remove_highlight,
      "whatever pointer-events the host had set must be put back")
  end

  # The overlay, spotlight and popup live on document.body, so Turbo caches them with
  # the page and a Back restores frozen copies under the live tour.
  test "injected elements are kept out of the Turbo page cache" do
    assert_match(/setAttribute\('data-turbo-cache', 'false'\)/, code)

    %w[createOverlay createHighlight createPopup].each do |method|
      body = code[/    #{method}\([^)]*\) \{.*?\n    \}/m]
      assert_match(/excludeFromSnapshot\(document\.createElement/, body,
        "#{method} appends to document.body, so its element must be excluded from the snapshot")
    end
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

  # Turbo renders a cached snapshot as a preview before the fresh response lands, and
  # every controller connects to both. Starting on the preview builds the tour, drops it
  # with the preview and builds it again - seen as the popup flashing in, out and in.
  test "an auto-started tour stands aside for a Turbo preview render" do
    connect = code[/    connect\(\) \{.*?\n    \}/m]

    refute_nil connect, "connect() should be defined"
    assert_match(/this\.autoStartTimer = setTimeout\(\(\) => this\.autoStart\(\), 1000\)/, connect,
      "connect should defer to autoStart, which decides whether this render is the real one")

    auto_start = code[/    autoStart\(\) \{.*?\n    \}/m]
    refute_nil auto_start, "autoStart() should be defined"
    assert_match(/data-turbo-preview/, auto_start,
      "a preview render must not start the tour - the render replacing it will")
    assert_match(/this\.element\.isConnected/, auto_start,
      "nor may a controller whose element has left the document: it no longer has the " \
      "handlers that would take the overlay and popup down again")
  end

  test "the auto-start timer is cancelled on disconnect" do
    disconnect = code[/    disconnect\(\) \{.*?\n    \}/m]

    refute_nil disconnect, "disconnect() should be defined"
    assert_match(/clearTimeout\(this\.autoStartTimer\)/, disconnect)
  end

  # A black scrim over a page that is already near-black moves the surround by a few
  # points of luminance, so the cutout has no visible boundary at all.
  test "the spotlight cutout can be given an edge for dark themes" do
    css = File.read(css_path)
    spotlight = css[/\.tour-spotlight-spotlight \{.*?\n\}/m]

    refute_nil spotlight, ".tour-spotlight-spotlight should be defined"
    assert_match(/var\(--onboarding-tour-spotlight-ring, transparent\)/, spotlight)
    assert_match(/var\(--onboarding-tour-spotlight-glow, transparent\)/, spotlight)

    ring = spotlight.index("--onboarding-tour-spotlight-ring")
    scrim = spotlight.index("--onboarding-tour-scrim")
    assert ring < scrim,
      "a box-shadow list paints in reverse, so the ring has to be listed before the " \
      "scrim to land on top of it rather than under it"
  end

  test "the spotlight edge is off by default and on in dark mode" do
    css = File.read(application_css_path)
    dark = css[/@media \(prefers-color-scheme: dark\) \{.*\z/m]

    refute_nil dark, "application.css should still carry the central dark block"
    assert_match(/--onboarding-tour-spotlight-ring: transparent/, css.sub(dark, ""),
      "the default must be transparent, so a light theme is untouched")
    assert_match(/--onboarding-tour-spotlight-ring: var\(--onboarding-primary\)/, dark,
      "dark mode has no luminance step to spare, so it draws the edge instead")
    assert_match(/--onboarding-tour-spotlight-glow: color-mix/, dark)
  end

  private

  # Comments - both block and line - are stripped so an assertion cannot be
  # satisfied, or defeated, by prose. Several of them deliberately quote the very
  # construct they warn against, which would otherwise match.
  def code
    @code ||= File.read(controller_path)
                  .gsub(%r{/\*.*?\*/}m, "")
                  .gsub(%r{^\s*//.*$}, "")
  end

  def controller_path
    Rails.root.join("..", "..", "app", "assets", "javascripts", "rails_onboarding", "tour_controller.js")
  end

  def css_path
    Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "tour.css")
  end

  def application_css_path
    Rails.root.join("..", "..", "app", "assets", "stylesheets", "rails_onboarding", "application.css")
  end
end
