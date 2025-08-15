class AddMilestoneTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :milestones_achieved, :text, default: "[]"
    add_column :users, :milestone_points, :integer, default: 0
    add_column :users, :last_milestone_at, :datetime

    add_index :users, :milestone_points
    add_index :users, :last_milestone_at
  end
end
