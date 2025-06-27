class AddScopingToAbilityPermissions < ActiveRecord::Migration[8.0]
  def change
    add_column :cccux_ability_permissions, :scoping_conditions, :text
  end
end
