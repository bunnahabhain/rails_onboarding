class AddAnalyticsToRailsOnboarding < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    create_table :rails_onboarding_analytics_events do |t|
      t.references :user, polymorphic: true, null: true
      t.string :event_type, null: false
      t.text :properties
      t.string :session_id
      t.datetime :occurred_at, null: false

      t.timestamps

      # Indexes for common queries and performance optimization
      t.index :event_type
      t.index :occurred_at
      t.index :session_id

      # Polymorphic association indexes (optimized for queries on specific user types)
      t.index [:user_type, :user_id], name: 'index_analytics_events_on_user'
      t.index [:user_type, :user_id, :event_type], name: 'index_analytics_events_on_user_and_type'
      t.index [:user_type, :user_id, :occurred_at], name: 'index_analytics_events_on_user_and_date'

      # Composite indexes for common analytics queries
      t.index [:event_type, :occurred_at], name: 'index_analytics_events_on_type_and_date'
      t.index [:user_id, :session_id], name: 'index_analytics_events_on_user_and_session'
      t.index [:session_id, :occurred_at], name: 'index_analytics_events_on_session_and_date'
      t.index [:event_type, :session_id], name: 'index_analytics_events_on_type_and_session'
    end
  end

  def down
    drop_table :rails_onboarding_analytics_events if table_exists?(:rails_onboarding_analytics_events)
  end
end