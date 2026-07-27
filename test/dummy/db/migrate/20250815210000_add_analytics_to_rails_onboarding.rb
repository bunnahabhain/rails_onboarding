class AddAnalyticsToRailsOnboarding < ActiveRecord::Migration[8.0]
  def change
    create_table :rails_onboarding_analytics_events do |t|
      t.references :user, polymorphic: true, null: true
      t.string :event_type, null: false
      t.text :properties
      t.string :session_id
      t.datetime :occurred_at, null: false

      t.timestamps

      # Indexes for common queries
      t.index :event_type
      t.index :occurred_at
      t.index [ :user_type, :user_id, :event_type ]
      t.index :session_id
    end
  end
end
