class AddContextToCccuxRoleAbilities < ActiveRecord::Migration[8.0]
  def change
    add_column :cccux_role_abilities, :context, :string, default: 'global', null: false
    
    # Add index for better query performance
    add_index :cccux_role_abilities, [:role_id, :ability_permission_id, :context], 
              name: 'index_role_abilities_on_role_permission_context'
  end
end
