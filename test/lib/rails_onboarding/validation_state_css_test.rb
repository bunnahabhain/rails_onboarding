require "test_helper"

# The validation-state rules in accessibility.css colour a field's border by its
# :valid / :invalid state. Written as a bare `input`, the :valid rule also
# matched buttons - a submit button is permanently :valid and, having no
# placeholder, permanently :not(:placeholder-shown) - so every primary action in
# the flow rendered with the success border instead of the primary one
# .primary-action asks for. Nothing in a Ruby test suite renders CSS, so assert
# on the selectors themselves.
module RailsOnboarding
  class ValidationStateCssTest < ActiveSupport::TestCase
    STYLESHEET = RailsOnboarding::Engine.root.join(
      "app", "assets", "stylesheets", "rails_onboarding", "accessibility.css"
    )

    # Types that are never typed into. Buttons are the ones that actually
    # regressed; the rest render no border of their own, so validity styling on
    # them is invisible at best.
    NON_TEXT_INPUT_TYPES = %w[submit button reset image checkbox radio file range color].freeze

    setup do
      # Comments have to go first, or the prose explaining this rule is itself
      # scanned as a selector - it mentions both `input` and :valid.
      @css = File.read(STYLESHEET).gsub(%r{/\*.*?\*/}m, "")
      @validation_selectors = @css.scan(/[^{};]*:(?:valid|invalid)[^{};]*(?=\{)/m)
    end

    test "the validation-state rules are present" do
      assert_equal 2, @validation_selectors.length,
        "expected a :valid and an :invalid rule; selector scan found #{@validation_selectors.length}"
    end

    test "validation-state rules exclude every non-text input type" do
      input_selectors = individual_selectors.grep(/\binput\b/)
      assert input_selectors.any?, "expected the validation rules to target inputs at all"

      input_selectors.each do |selector|
        NON_TEXT_INPUT_TYPES.each do |type|
          assert_includes selector, %([type="#{type}"]),
            "#{selector.strip} would style type=#{type}; a submit button is always :valid, " \
            "so a bare `input` here repaints every button in the flow"
        end
      end
    end

    # The exclusion belongs on the input selector itself. Sitting on the select
    # or textarea half instead would parse fine and do nothing.
    test "the exclusion is attached to the input selectors, not their neighbours" do
      individual_selectors.each do |selector|
        next unless selector.include?(%([type="submit"]))

        assert_match(/\binput\b.*\[type="submit"\]/, selector,
          "#{selector.strip} carries the exclusion but does not apply it to an input")
      end
    end

    private

    # Split the rules into their individual selectors on top-level commas only.
    # A plain String#split(",") would tear `:not([type="submit"], [type="button"])`
    # into fragments and make an exclusion list look like a missing one.
    def individual_selectors
      @validation_selectors.flat_map do |rule|
        parts = [ +"" ]
        depth = 0

        rule.each_char do |char|
          case char
          when "(" then depth += 1; parts.last << char
          when ")" then depth -= 1; parts.last << char
          when "," then depth.zero? ? parts << +"" : parts.last << char
          else parts.last << char
          end
        end

        parts
      end
    end
  end
end
