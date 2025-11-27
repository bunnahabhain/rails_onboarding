class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.integer :user_id
      t.string :event_type
      t.text :event_data

      t.timestamps
    end
  end
end
