module RailsOnboarding
  class AnalyticsEvent < ApplicationRecord
    self.table_name = "rails_onboarding_analytics_events"

    belongs_to :user, polymorphic: true, optional: true
    
    # Rails 8 compatibility: Handle polymorphic associations gracefully
    def user=(user_instance)
      if user_instance
        klass = user_instance.class
        unless klass.respond_to?(:has_query_constraints?)
          klass.define_singleton_method(:has_query_constraints?) { false }
        end
        unless klass.respond_to?(:composite_primary_key?)
          klass.define_singleton_method(:composite_primary_key?) { false }
        end
      end
      super(user_instance)
    end

    validates :event_type, presence: true
    validates :occurred_at, presence: true

    serialize :properties, coder: JSON

    scope :by_event_type, ->(type) { where(event_type: type) }
    scope :by_user, ->(user) { where(user: user) }
    scope :by_date_range, ->(start_date, end_date) { where(occurred_at: start_date..end_date) }
    scope :recent, ->(limit = 100) { order(occurred_at: :desc).limit(limit) }
    scope :with_user, -> { includes(:user) } # Eager load users to prevent N+1 queries
    scope :ordered, -> { order(occurred_at: :asc) } # Consistent ordering for pagination

    # Event types
    ONBOARDING_STARTED = 'onboarding_started'.freeze
    ONBOARDING_STEP_COMPLETED = 'onboarding_step_completed'.freeze  
    ONBOARDING_STEP_SKIPPED = 'onboarding_step_skipped'.freeze
    ONBOARDING_COMPLETED = 'onboarding_completed'.freeze
    ONBOARDING_SKIPPED = 'onboarding_skipped'.freeze
    TOOLTIP_SHOWN = 'tooltip_shown'.freeze
    TOOLTIP_DISMISSED = 'tooltip_dismissed'.freeze
    TOOLTIP_CLICKED = 'tooltip_clicked'.freeze
    MILESTONE_ACHIEVED = 'milestone_achieved'.freeze

    def self.track_event(user:, event_type:, properties: {}, session_id: nil)
      return unless RailsOnboarding.configuration.enable_analytics
      return unless table_exists?

      create!(
        user: user,
        event_type: event_type,
        properties: properties,
        session_id: session_id,
        occurred_at: Time.current
      )
    rescue ActiveRecord::StatementInvalid => e
      # Gracefully handle missing table - analytics is optional
      Rails.logger.warn "RailsOnboarding Analytics: #{e.message}" if defined?(Rails)
      nil
    end

    def self.track_onboarding_started(user:, session_id: nil)
      track_event(
        user: user,
        event_type: ONBOARDING_STARTED,
        properties: {
          user_created_at: user.created_at,
          total_steps: RailsOnboarding.configuration.total_steps
        },
        session_id: session_id
      )
    end

    def self.track_step_completed(user:, step_name:, step_index:, time_spent: nil, session_id: nil)
      track_event(
        user: user,
        event_type: ONBOARDING_STEP_COMPLETED,
        properties: {
          step_name: step_name,
          step_index: step_index,
          time_spent_seconds: time_spent,
          progress_percentage: user.onboarding_progress
        },
        session_id: session_id
      )
    end

    def self.track_step_skipped(user:, step_name:, step_index:, session_id: nil)
      track_event(
        user: user,
        event_type: ONBOARDING_STEP_SKIPPED,
        properties: {
          step_name: step_name,
          step_index: step_index,
          progress_percentage: user.onboarding_progress
        },
        session_id: session_id
      )
    end

    def self.track_onboarding_completed(user:, completion_time: nil, was_skipped: false, session_id: nil)
      track_event(
        user: user,
        event_type: was_skipped ? ONBOARDING_SKIPPED : ONBOARDING_COMPLETED,
        properties: {
          completion_time_seconds: completion_time,
          was_skipped: was_skipped,
          total_steps: RailsOnboarding.configuration.total_steps
        },
        session_id: session_id
      )
    end

    def self.track_tooltip_interaction(user:, tooltip_feature:, action:, session_id: nil)
      event_type = case action.to_s
                   when 'shown' then TOOLTIP_SHOWN
                   when 'dismissed' then TOOLTIP_DISMISSED  
                   when 'clicked' then TOOLTIP_CLICKED
                   else 'tooltip_interaction'
                   end

      track_event(
        user: user,
        event_type: event_type,
        properties: {
          tooltip_feature: tooltip_feature,
          action: action
        },
        session_id: session_id
      )
    end

    def self.track_milestone_achieved(user:, milestone_key:, points_earned:, session_id: nil)
      track_event(
        user: user,
        event_type: MILESTONE_ACHIEVED,
        properties: {
          milestone_key: milestone_key,
          points_earned: points_earned,
          total_points: user.total_milestone_points
        },
        session_id: session_id
      )
    end
  end
end