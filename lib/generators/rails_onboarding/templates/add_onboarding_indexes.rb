# frozen_string_literal: true

class AddOnboardingIndexes < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  disable_ddl_transaction!

  def up
    # Add indexes for frequently queried columns.
    # Skip if index already exists. On PostgreSQL, build concurrently so these
    # don't hold a write lock on a large, live users table; other adapters
    # don't support that algorithm, so fall back to a plain index there.
    unless index_exists?(:users, :onboarding_completed)
      add_index :users, :onboarding_completed, **concurrent_index_options
    end

    unless index_exists?(:users, :onboarding_current_step)
      add_index :users, :onboarding_current_step, **concurrent_index_options
    end

    unless index_exists?(:users, :onboarding_skipped)
      add_index :users, :onboarding_skipped, **concurrent_index_options
    end

    unless index_exists?(:users, [:onboarding_completed, :created_at])
      # Composite index for finding users who need onboarding
      add_index :users, [:onboarding_completed, :created_at],
                name: 'index_users_on_onboarding_status_and_created', **concurrent_index_options
    end

    unless index_exists?(:users, :onboarding_completed_at)
      # Index for analytics queries on completion time
      add_index :users, :onboarding_completed_at, **concurrent_index_options
    end

    unless index_exists?(:users, :last_milestone_at)
      # Index for milestone queries
      add_index :users, :last_milestone_at, **concurrent_index_options
    end

    # Add indexes to analytics_events table if it exists
    if table_exists?(:rails_onboarding_analytics_events)
      unless index_exists?(:rails_onboarding_analytics_events, [:user_id, :event_type])
        add_index :rails_onboarding_analytics_events, [:user_id, :event_type],
                  name: 'index_analytics_events_on_user_and_type', **concurrent_index_options
      end

      unless index_exists?(:rails_onboarding_analytics_events, [:event_type, :created_at])
        add_index :rails_onboarding_analytics_events, [:event_type, :created_at],
                  name: 'index_analytics_events_on_type_and_date', **concurrent_index_options
      end

      unless index_exists?(:rails_onboarding_analytics_events, :session_id)
        add_index :rails_onboarding_analytics_events, :session_id, **concurrent_index_options
      end

      unless index_exists?(:rails_onboarding_analytics_events, [:user_id, :session_id])
        add_index :rails_onboarding_analytics_events, [:user_id, :session_id],
                  name: 'index_analytics_events_on_user_and_session', **concurrent_index_options
      end
    end
  end

  def down
    # Remove indexes in reverse order
    if table_exists?(:rails_onboarding_analytics_events)
      remove_index :rails_onboarding_analytics_events, name: 'index_analytics_events_on_user_and_session' if index_exists?(:rails_onboarding_analytics_events, [:user_id, :session_id], name: 'index_analytics_events_on_user_and_session')
      remove_index :rails_onboarding_analytics_events, :session_id if index_exists?(:rails_onboarding_analytics_events, :session_id)
      remove_index :rails_onboarding_analytics_events, name: 'index_analytics_events_on_type_and_date' if index_exists?(:rails_onboarding_analytics_events, [:event_type, :created_at], name: 'index_analytics_events_on_type_and_date')
      remove_index :rails_onboarding_analytics_events, name: 'index_analytics_events_on_user_and_type' if index_exists?(:rails_onboarding_analytics_events, [:user_id, :event_type], name: 'index_analytics_events_on_user_and_type')
    end

    remove_index :users, :last_milestone_at if index_exists?(:users, :last_milestone_at)
    remove_index :users, :onboarding_completed_at if index_exists?(:users, :onboarding_completed_at)
    remove_index :users, name: 'index_users_on_onboarding_status_and_created' if index_exists?(:users, [:onboarding_completed, :created_at], name: 'index_users_on_onboarding_status_and_created')
    remove_index :users, :onboarding_skipped if index_exists?(:users, :onboarding_skipped)
    remove_index :users, :onboarding_current_step if index_exists?(:users, :onboarding_current_step)
    remove_index :users, :onboarding_completed if index_exists?(:users, :onboarding_completed)
  end

  private

  def concurrent_index_options
    postgresql? ? { algorithm: :concurrently } : {}
  end

  def postgresql?
    %w[postgresql postgis].include?(ActiveRecord::Base.connection.adapter_name.downcase)
  end
end
