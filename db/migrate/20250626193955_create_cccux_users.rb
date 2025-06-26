class CreateCccuxUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :cccux_users do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.boolean :active
      t.text :notes

      t.timestamps
    end
    add_index :cccux_users, :email, unique: true
  end
end
