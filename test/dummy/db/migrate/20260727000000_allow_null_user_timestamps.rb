# Host applications that installed RailsOnboarding on top of an existing users
# table routinely have rows with NULL created_at/updated_at - imported data, or
# timestamp columns added long after the table was created. The dummy app
# mirrors that so the engine's nil-timestamp handling is actually exercised.
class AllowNullUserTimestamps < ActiveRecord::Migration[8.1]
  def up
    change_column_null :users, :created_at, true
    change_column_null :users, :updated_at, true
  end

  def down
    change_column_null :users, :created_at, false
    change_column_null :users, :updated_at, false
  end
end
