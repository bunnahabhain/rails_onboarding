require "test_helper"

# --onboarding-primary was doing two jobs: colouring text, borders and focus
# outlines, and filling surfaces that carry a label. A light theme can serve
# both with one value; a dark theme cannot, because the luminance a fill needs
# to sit behind a light label and the luminance text needs to be legible on a
# dark page do not overlap at WCAG AA. --onboarding-primary-fill and
# --onboarding-on-primary split the roles so a host can set both.
#
# The defaults have to keep pointing at --onboarding-primary: hosts that never
# set them must see byte-identical output. Nothing in a Ruby test suite renders
# CSS, so assert on the stylesheets themselves.
module RailsOnboarding
  class PrimaryFillTokenTest < ActiveSupport::TestCase
    STYLESHEETS = Dir[RailsOnboarding::Engine.root.join(
      "app", "assets", "stylesheets", "rails_onboarding", "*.css"
    )].freeze

    # admin.css styles the host's admin console rather than the onboarding flow,
    # and is not part of the themable surface.
    THEMED = STYLESHEETS.reject { |p| File.basename(p) == "admin.css" }.freeze

    setup do
      @sources = THEMED.to_h { |p| [ File.basename(p), strip_comments(File.read(p)) ] }
      @tokens  = @sources.fetch("application.css")
    end

    test "the split tokens default back to the primary colour" do
      assert_match(/--onboarding-primary-fill:\s*var\(--onboarding-primary\)\s*;/, @tokens,
        "the fill must default to --onboarding-primary or existing themes shift")
      assert_match(/--onboarding-primary-fill-hover:\s*var\(--onboarding-primary-hover\)\s*;/, @tokens,
        "the fill's hover must default to --onboarding-primary-hover")
      assert_match(/--onboarding-on-primary:\s*#ffffff\s*;/i, @tokens,
        "the label colour must default to the white it replaced")
    end

    # The regression itself: a background painted straight from
    # --onboarding-primary is a surface a host cannot retheme independently.
    test "no rule fills a background from the brand colour directly" do
      offenders = each_declaration.select do |file, line, decl|
        decl.match?(/\Abackground(-color)?\s*:/) &&
          decl.match?(/var\(--onboarding-primary(-hover)?\)/)
      end

      assert_empty offenders.map { |f, l, d| "#{f}:#{l} #{d}" },
        "these should use --onboarding-primary-fill / -fill-hover so a host can " \
        "darken fills without darkening brand text with them"
    end

    # A hardcoded white label on a themable fill is the other half of the trap:
    # the host darkens the fill and the label stays put, or lightens it and the
    # label vanishes.
    test "labels on brand-filled surfaces come from the token" do
      offenders = each_rule.select do |file, line, _sel, body|
        body.match?(/background[^;]*var\(--onboarding-primary-fill\)/) &&
          body.match?(/color\s*:\s*(white|#fff(fff)?)\s*[;}]/i)
      end

      assert_empty offenders.map { |f, l, sel, _| "#{f}:#{l} #{sel}" },
        "these fill from the brand colour but hardcode their label; use " \
        "--onboarding-on-primary"
    end

    test "foreground uses of the brand colour are left alone" do
      text_uses = each_declaration.count do |_f, _l, decl|
        decl.match?(/\A(color|outline|border(-[a-z]+)?)\s*:/) &&
          decl.include?("var(--onboarding-primary)")
      end

      assert_operator text_uses, :>, 0,
        "the split should not have swept up text, borders and focus outlines"
    end

    private

    def strip_comments(css) = css.gsub(%r{/\*.*?\*/}m, "")

    def each_rule
      @sources.flat_map do |file, css|
        css.to_enum(:scan, /([^{}]+)\{([^{}]*)\}/).map do
          m = Regexp.last_match
          [ file, css[0...m.begin(0)].count("\n") + 1, m[1].strip.lines.last.to_s.strip, m[2] ]
        end
      end
    end

    def each_declaration
      each_rule.flat_map do |file, line, _sel, body|
        body.split(";").map { |d| [ file, line, "#{d.strip};" ] }
      end
    end
  end
end
