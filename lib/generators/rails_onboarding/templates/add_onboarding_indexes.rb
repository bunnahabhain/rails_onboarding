# frozen_string_literal: true

class AddOnboardingIndexes < ActiveRecord::Migration[<%= Rails::VERSION::MAJOR %>.<%= Rails::VERSION::MINOR %>]
  def change
    # Add indexes for frequently queried columns
    # Skip if index already exists
    unless index_exists?(:users, :onboarding_completed)
      add_index :users, :onboarding_completed
    end

    unless index_exists?(:users, :onboarding_current_step)
      add_index :users, :onboarding_current_step
    end

    unless index_exists?(:users, :onboarding_skipped)
      add_index :users, :onboarding_skipped
    end

    unless index_exists?(:users, [:onboarding_completed, :created_at])
      # Composite index for finding users who need onboarding
      add_index :users, [:onboarding_completed, :created_at],
                name: 'index_users_on_onboarding_status_and_created'
    end

    unless index_exists?(:users, :onboarding_completed_at)
      # Index for analytics queries on completion time
      add_index :users, :onboarding_completed_at
    end

    unless index_exists?(:users, :last_milestone_at)
      # Index for milestone queries
      add_index :users, :last_milestone_at
    end

    # Add indexes to analytics_events table if it exists
    if table_exists?(:analytics_events)
      unless index_exists?(:analytics_events, [:user_id, :event_type])
        add_index :analytics_events, [:user_id, :event_type],
                  name: 'index_analytics_events_on_user_and_type'
      end

      unless index_exists?(:analytics_events, [:event_type, :created_at])
        add_index :analytics_events, [:event_type, :created_at],
                  name: 'index_analytics_events_on_type_and_date'
      end

      unless index_exists?(:analytics_events, :session_id)
        add_index :analytics_events, :session_id
      end

      unless index_exists?(:analytics_events, [:user_id, :session_id])
        add_index :analytics_events, [:user_id, :session_id],
                  name: 'index_analytics_events_on_user_and_session'
      end
    end
  end
end
