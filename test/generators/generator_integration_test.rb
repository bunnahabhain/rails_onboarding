require "test_helper"
require "generators/rails_onboarding/install_generator"

module RailsOnboarding
  class GeneratorIntegrationTest < ActiveSupport::TestCase
    def setup
      @generator_class = RailsOnboarding::Generators::InstallGenerator
      @template_dir = File.expand_path(
        File.join(
          File.dirname(__FILE__),
          "../../lib/generators/rails_onboarding/templates"
        )
      )
    end

    test "generator has correct source root" do
      assert_equal @template_dir, @generator_class.source_root
    end

    test "generator includes Rails::Generators::Migration" do
      assert @generator_class.included_modules.include?(Rails::Generators::Migration),
             "Generator should include Rails::Generators::Migration"
    end

    test "generator responds to next_migration_number" do
      assert_respond_to @generator_class, :next_migration_number
    end

    test "next_migration_number returns timestamp format" do
      timestamp = @generator_class.next_migration_number(nil)

      # Should be a timestamp in format YYYYMMDDHHMMSS
      assert_match(/^\d{14}$/, timestamp)

      # Should be a valid time
      year = timestamp[0..3].to_i
      month = timestamp[4..5].to_i
      day = timestamp[6..7].to_i

      assert year >= 2024, "Year should be current or future"
      assert month >= 1 && month <= 12, "Month should be valid"
      assert day >= 1 && day <= 31, "Day should be valid"
    end

    test "generator has all required public methods" do
      required_methods = %w[
        copy_migration
        copy_analytics_migration
        copy_flows_migration
        copy_milestone_tracking_migration
        copy_onboarding_indexes_migration
        copy_robustness_fields_migration
        copy_initializer
        add_route
        copy_stylesheets
        display_readme
        validate_environment
      ]

      instance_methods = @generator_class.instance_methods(false).map(&:to_s)

      required_methods.each do |method|
        assert_includes instance_methods, method,
                       "Generator should have #{method} method"
      end
    end

    test "generator has validation helper methods" do
      validation_methods = %w[
        validate_template_paths!
        validate_user_model!
      ]

      private_methods = @generator_class.private_instance_methods(false).map(&:to_s)

      validation_methods.each do |method|
        assert_includes private_methods, method,
                       "Generator should have private #{method} method"
      end
    end

    test "all required template files exist" do
      required_templates = [
        "add_onboarding_to_users.rb",
        "add_analytics_to_rails_onboarding.rb",
        "add_milestone_tracking_to_users.rb",
        "add_onboarding_indexes.rb",
        "add_robustness_fields_to_users.rb.tt",
        "rails_onboarding.rb",
        "onboarding.css",
        "README"
      ]

      required_templates.each do |template|
        path = File.join(@template_dir, template)
        assert File.exist?(path),
               "Required template #{template} should exist at #{path}"
      end
    end

    test "initializer template contains all required configuration options" do
      initializer_path = File.join(@template_dir, "rails_onboarding.rb")
      content = File.read(initializer_path)

      required_config = %w[
        user_class_name
        redirect_after_completion
        redirect_after_skip
        enable_tooltips
        enable_milestones
        onboarding_required_for
        steps
      ]

      required_config.each do |config|
        assert_match(/config\.#{config}/, content,
                    "Initializer should include #{config} configuration")
      end
    end

    test "initializer template includes example steps" do
      initializer_path = File.join(@template_dir, "rails_onboarding.rb")
      content = File.read(initializer_path)

      example_steps = %w[welcome explore]

      example_steps.each do |step|
        assert_match(/name: :#{step}/, content,
                    "Initializer should include example step: #{step}")
      end
    end

    test "README template exists and contains setup instructions" do
      readme_path = File.join(@template_dir, "README")
      assert File.exist?(readme_path), "README template should exist"

      content = File.read(readme_path)

      required_sections = [
        "rails_onboarding",
        "User",
        "model",
        "migration"
      ]

      required_sections.each do |section|
        assert_match(/#{section}/i, content,
                    "README should mention #{section}")
      end
    end

    test "stylesheet template exists" do
      css_path = File.join(@template_dir, "onboarding.css")
      assert File.exist?(css_path), "Stylesheet template should exist"

      content = File.read(css_path)
      # Should contain some CSS
      assert_match(/\{/, content, "Stylesheet should contain CSS rules")
    end

    test "generator handles ERB templates correctly" do
      # Check that .tt files are treated as templates
      erb_templates = Dir.glob(File.join(@template_dir, "*.tt"))

      assert erb_templates.any?, "Should have at least one ERB template"

      erb_templates.each do |template|
        content = File.read(template)
        # ERB templates should contain ERB tags
        assert_match(/<%=.*%>/, content,
                    "#{File.basename(template)} should contain ERB tags")
      end
    end

    test "migration templates use consistent formatting" do
      migration_files = Dir.glob(File.join(@template_dir, "*users*.rb*"))

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file)

        # Should have consistent indentation (2 spaces)
        lines = content.lines
        indented_lines = lines.select { |l| l.start_with?("  ") }

        assert indented_lines.any?, "#{basename} should have indented content"

        # Check for consistent method structure
        if content.include?("def up")
          assert_match(/def up\n.*?\n  end/m, content,
                      "#{basename} should have properly structured up method")
        end

        if content.include?("def down")
          assert_match(/def down\n.*?\n  end/m, content,
                      "#{basename} should have properly structured down method")
        end
      end
    end

    test "all migration templates are valid Ruby syntax" do
      migration_files = Dir.glob(File.join(@template_dir, "*.rb"))
        .reject { |f| f.end_with?("rails_onboarding.rb") }

      assert migration_files.any?, "Should have at least one migration template"

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file)

        # Remove ERB tags for syntax check
        ruby_content = content.gsub(/<%=.*?%>/, "7.0")

        # Check Ruby syntax
        begin
          compiled = RubyVM::InstructionSequence.compile(ruby_content)
          assert compiled, "#{basename} should compile successfully"
        rescue SyntaxError => e
          flunk "#{basename} has invalid Ruby syntax: #{e.message}"
        end
      end
    end

    test "generator templates follow Rails conventions" do
      # Check that migration class names follow Rails conventions
      migration_files = Dir.glob(File.join(@template_dir, "add_*.rb*"))

      migration_files.each do |file|
        content = File.read(file)
        # Remove all extensions (.rb.tt -> remove .tt then .rb)
        basename = File.basename(file)
        basename = basename.sub(/\.rb\.tt$/, "").sub(/\.rb$/, "")

        # Class name should be CamelCase version of file name
        expected_pattern = basename.split("_").map { |w| w.capitalize }.join
        assert_match(/class #{expected_pattern}/, content,
                    "Migration class name should follow Rails naming convention")
      end
    end

    test "generator provides helpful error messages" do
      # This is verified by checking the validate_user_model! method
      # which provides detailed error messages

      generator_code = File.read(File.join(
        File.dirname(__FILE__),
        "../../lib/generators/rails_onboarding/install_generator.rb"
      ))

      # Should provide helpful error messages
      assert_match(/User model not found/, generator_code,
                  "Should have helpful error for missing User model")
      assert_match(/Please create a User model/, generator_code,
                  "Should provide guidance on creating User model")
      assert_match(/rails generate model User/, generator_code,
                  "Should provide command to create User model")
    end

    test "generator validates before making changes" do
      generator_code = File.read(File.join(
        File.dirname(__FILE__),
        "../../lib/generators/rails_onboarding/install_generator.rb"
      ))

      # validate_environment should be called before other methods
      methods = generator_code.scan(/def (\w+)/).flatten

      assert_includes methods, "validate_environment",
                     "Generator should have validate_environment method"
    end
  end
end
