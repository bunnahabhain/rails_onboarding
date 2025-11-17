# frozen_string_literal: true

module RailsOnboarding
  # Helper methods for working with onboarding templates
  module TemplatesHelper
    # Get all available templates
    #
    # @return [Hash] Hash of template_key => template_config
    def available_templates
      RailsOnboarding.configuration.onboarding_templates || {}
    end

    # Get a specific template
    #
    # @param template_key [Symbol, String] Template identifier
    # @return [Hash, nil] Template configuration or nil
    def get_template(template_key)
      RailsOnboarding.configuration.template(template_key)
    end

    # Apply a template to configuration
    #
    # @param template_key [Symbol, String] Template identifier
    # @return [Boolean] Success status
    def apply_template(template_key)
      RailsOnboarding.configuration.apply_template(template_key)
    end

    # Get recommended template based on context
    #
    # @param context [Hash] Context information (industry, user_count, etc.)
    # @return [Symbol, nil] Recommended template key or nil
    #
    # @example
    #   recommended_template(industry: :ecommerce, user_count: 1)
    #   # => :ecommerce
    def recommended_template(context = {})
      templates = available_templates

      # Recommend based on industry if provided
      if context[:industry]
        return context[:industry].to_sym if templates[context[:industry].to_sym]
      end

      # Recommend based on user type
      if context[:user_type]
        case context[:user_type].to_sym
        when :student, :learner
          return :education if templates[:education]
        when :seller, :merchant
          return :marketplace if templates[:marketplace]
        when :business, :company
          return :saas if templates[:saas]
        end
      end

      # Recommend based on team size
      if context[:team_size]
        if context[:team_size] > 10
          return :saas if templates[:saas]
        elsif context[:team_size] == 1
          return :community if templates[:community]
        end
      end

      # Default to first available template
      templates.keys.first
    end

    # Render template selection UI
    #
    # @param options [Hash] Display options
    # @return [String] HTML for template selector
    def template_selector(options = {})
      templates = available_templates
      current_template = options[:current] || detect_current_template

      content_tag :div, class: 'template-selector' do
        concat(content_tag(:h3, options[:title] || 'Choose a Template'))

        concat(content_tag(:div, class: 'template-options') do
          templates.each do |key, template|
            concat(template_option(key, template, key == current_template))
          end
        end)
      end
    end

    # Render a single template option
    #
    # @param key [Symbol] Template key
    # @param template [Hash] Template configuration
    # @param selected [Boolean] Whether this template is selected
    # @return [String] HTML for template option
    def template_option(key, template, selected = false)
      content_tag :div, class: "template-option #{selected ? 'selected' : ''}", data: { template: key } do
        concat(content_tag(:div, class: 'template-icon') do
          template[:icon] || '📋'
        end)
        concat(content_tag(:div, class: 'template-info') do
          concat(content_tag(:h4, template[:name]))
          concat(content_tag(:p, template[:description] || "#{key.to_s.titleize} onboarding"))
          concat(content_tag(:span, "#{template[:steps]&.size || 0} steps", class: 'step-count'))
        end)
      end
    end

    # Detect which template matches current configuration
    #
    # @return [Symbol, nil] Matched template key or nil
    def detect_current_template
      current_steps = RailsOnboarding.configuration.steps
      return nil if current_steps.empty?

      available_templates.find do |key, template|
        template[:steps] == current_steps
      end&.first
    end

    # Compare templates
    #
    # @param template_keys [Array<Symbol>] Template keys to compare
    # @return [Hash] Comparison data
    def compare_templates(*template_keys)
      comparison = {}

      template_keys.each do |key|
        template = get_template(key)
        next unless template

        comparison[key] = {
          name: template[:name],
          total_steps: template[:steps]&.size || 0,
          required_steps: template[:steps]&.count { |s| !s[:skippable] } || 0,
          optional_steps: template[:steps]&.count { |s| s[:skippable] } || 0,
          steps: template[:steps]
        }
      end

      comparison
    end

    # Render template comparison table
    #
    # @param template_keys [Array<Symbol>] Templates to compare
    # @return [String] HTML table comparing templates
    def render_template_comparison(*template_keys)
      comparison = compare_templates(*template_keys)
      return '' if comparison.empty?

      content_tag :table, class: 'template-comparison' do
        concat(content_tag(:thead) do
          content_tag(:tr) do
            concat(content_tag(:th, 'Feature'))
            comparison.each_key do |key|
              concat(content_tag(:th, comparison[key][:name]))
            end
          end
        end)

        concat(content_tag(:tbody) do
          # Total steps row
          concat(content_tag(:tr) do
            concat(content_tag(:td, 'Total Steps'))
            comparison.each_value do |data|
              concat(content_tag(:td, data[:total_steps]))
            end
          end)

          # Required steps row
          concat(content_tag(:tr) do
            concat(content_tag(:td, 'Required Steps'))
            comparison.each_value do |data|
              concat(content_tag(:td, data[:required_steps]))
            end
          end)

          # Optional steps row
          concat(content_tag(:tr) do
            concat(content_tag(:td, 'Optional Steps'))
            comparison.each_value do |data|
              concat(content_tag(:td, data[:optional_steps]))
            end
          end)
        end)
      end
    end

    # Get template metadata
    #
    # @param template_key [Symbol, String] Template identifier
    # @return [Hash] Metadata about the template
    def template_metadata(template_key)
      template = get_template(template_key)
      return {} unless template

      {
        name: template[:name],
        total_steps: template[:steps]&.size || 0,
        estimated_time: estimate_template_time(template),
        difficulty: template_difficulty(template),
        categories: template_categories(template)
      }
    end

    # Estimate completion time for a template
    #
    # @param template [Hash] Template configuration
    # @return [String] Estimated time (e.g., "5-10 minutes")
    def estimate_template_time(template)
      steps_count = template[:steps]&.size || 0
      min_time = steps_count * 1 # 1 minute per step minimum
      max_time = steps_count * 3 # 3 minutes per step maximum

      "#{min_time}-#{max_time} minutes"
    end

    # Determine template difficulty
    #
    # @param template [Hash] Template configuration
    # @return [Symbol] :easy, :medium, or :hard
    def template_difficulty(template)
      total_steps = template[:steps]&.size || 0
      required_steps = template[:steps]&.count { |s| !s[:skippable] } || 0

      if total_steps <= 3 && required_steps <= 2
        :easy
      elsif total_steps <= 5 && required_steps <= 3
        :medium
      else
        :hard
      end
    end

    # Get categories/tags for a template
    #
    # @param template [Hash] Template configuration
    # @return [Array<Symbol>] Categories
    def template_categories(template)
      categories = []

      step_names = template[:steps]&.map { |s| s[:name].to_s } || []

      categories << :profile if step_names.any? { |n| n.include?('profile') }
      categories << :team if step_names.any? { |n| n.include?('team') || n.include?('invite') }
      categories << :payment if step_names.any? { |n| n.include?('payment') || n.include?('billing') }
      categories << :content if step_names.any? { |n| n.include?('post') || n.include?('product') }
      categories << :social if step_names.any? { |n| n.include?('connect') || n.include?('friends') }

      categories
    end
  end
end
