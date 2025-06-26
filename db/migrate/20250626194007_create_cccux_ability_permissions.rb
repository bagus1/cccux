class CreateCccuxAbilityPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_ability_permissions do |t|
      t.string :action
      t.string :subject
      t.text :description
      t.boolean :active

      t.timestamps
    end
  end
end
