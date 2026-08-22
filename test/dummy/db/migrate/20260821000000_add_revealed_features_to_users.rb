class AddRevealedFeaturesToUsers < ActiveRecord::Migration[8.0]
  def up
    return if column_exists?(:users, :revealed_features)

    add_column :users, :revealed_features, :text
  end

  def down
    remove_column :users, :revealed_features if column_exists?(:users, :revealed_features)
  end
end
