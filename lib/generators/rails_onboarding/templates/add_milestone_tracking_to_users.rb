class AddMilestoneTrackingToUsers < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  disable_ddl_transaction!

  def up
    # No DB-level default: MySQL/MariaDB reject a literal DEFAULT on
    # TEXT/BLOB/JSON columns. Onboardable already treats a nil
    # milestones_achieved as an empty array in Ruby (see onboardable.rb),
    # so there's nothing to work around adapter-by-adapter here.
    add_column :users, :milestones_achieved, :text
    add_column :users, :milestone_points, :integer, default: 0
    add_column :users, :last_milestone_at, :datetime

    # On PostgreSQL, build concurrently so these don't hold a write lock on a
    # large, live users table; other adapters don't support that algorithm,
    # so fall back to a plain index there.
    add_index :users, :milestone_points, **concurrent_index_options
    add_index :users, :last_milestone_at, **concurrent_index_options
  end

  def down
    remove_index :users, :last_milestone_at if index_exists?(:users, :last_milestone_at)
    remove_index :users, :milestone_points if index_exists?(:users, :milestone_points)

    remove_column :users, :last_milestone_at if column_exists?(:users, :last_milestone_at)
    remove_column :users, :milestone_points if column_exists?(:users, :milestone_points)
    remove_column :users, :milestones_achieved if column_exists?(:users, :milestones_achieved)
  end

  private

  def concurrent_index_options
    postgresql? ? { algorithm: :concurrently } : {}
  end

  def postgresql?
    %w[postgresql postgis].include?(ActiveRecord::Base.connection.adapter_name.downcase)
  end
end
