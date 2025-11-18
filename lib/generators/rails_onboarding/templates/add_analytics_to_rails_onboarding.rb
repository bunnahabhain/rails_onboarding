class AddAnalyticsToRailsOnboarding < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
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
      t.index [:user_type, :user_id, :event_type]
      t.index :session_id
      t.index [:event_type, :occurred_at], name: 'index_analytics_events_on_type_and_date'
      t.index [:user_id, :session_id], name: 'index_analytics_events_on_user_and_session'
    end
  end
end