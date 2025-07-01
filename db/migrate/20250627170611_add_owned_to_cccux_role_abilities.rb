class AddOwnedToCccuxRoleAbilities < ActiveRecord::Migration[7.1]
  def change
    add_column :cccux_role_abilities, :owned, :boolean, default: false, null: false
    
    # Add index for better query performance
    add_index :cccux_role_abilities, [:role_id, :ability_permission_id, :owned], 
              name: 'index_role_abilities_on_role_permission_owned'
  end
end
