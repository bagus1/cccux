class CreateCccuxRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_roles do |t|
      t.string :name
      t.text :description
      t.boolean :active
      t.integer :priority

      t.timestamps
    end
    add_index :cccux_roles, :name, unique: true
  end
end
