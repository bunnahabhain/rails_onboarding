class AddMilestoneTrackingToUsers < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def up
    add_column :users, :milestones_achieved, :text, default: "[]"
    add_column :users, :milestone_points, :integer, default: 0
    add_column :users, :last_milestone_at, :datetime

    add_index :users, :milestone_points
    add_index :users, :last_milestone_at
  end

  def down
    remove_index :users, :last_milestone_at if index_exists?(:users, :last_milestone_at)
    remove_index :users, :milestone_points if index_exists?(:users, :milestone_points)

    remove_column :users, :last_milestone_at if column_exists?(:users, :last_milestone_at)
    remove_column :users, :milestone_points if column_exists?(:users, :milestone_points)
    remove_column :users, :milestones_achieved if column_exists?(:users, :milestones_achieved)
  end
end
