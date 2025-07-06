class AddOwnershipConfigurationToRoleAbilities < ActiveRecord::Migration[8.0]
  def change
    add_column :cccux_role_abilities, :ownership_source, :string
    add_column :cccux_role_abilities, :ownership_conditions, :text
    
    # Add index for ownership_source lookups
    add_index :cccux_role_abilities, :ownership_source unless index_exists?(:cccux_role_abilities, :ownership_source)
    
    # Remove old unique index if it exists
    if index_exists?(:cccux_role_abilities, [:role_id, :ability_permission_id, :owned], name: 'index_role_abilities_on_role_permission_owned')
      remove_index :cccux_role_abilities, name: 'index_role_abilities_on_role_permission_owned'
    end
    
    # Add new unique index including ownership_source
    unless index_exists?(:cccux_role_abilities, [:role_id, :ability_permission_id, :owned, :context, :ownership_source], name: 'index_role_abilities_on_role_permission_owned_source')
      add_index :cccux_role_abilities, [:role_id, :ability_permission_id, :owned, :context, :ownership_source], 
                unique: true, 
                name: 'index_role_abilities_on_role_permission_owned_source'
    end
  end
end
