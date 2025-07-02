class CreateCccuxAbilityPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_ability_permissions do |t|
      t.string :action
      t.string :subject
      t.text :description
      t.boolean :active

      t.timestamps
    end
    
    # Add indexes for better query performance
    add_index :cccux_ability_permissions, :action
    add_index :cccux_ability_permissions, :subject
    add_index :cccux_ability_permissions, :active
    add_index :cccux_ability_permissions, [:action, :subject], unique: true
  end
end
