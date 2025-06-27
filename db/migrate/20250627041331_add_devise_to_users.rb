class AddDeviseToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :cccux_users, :encrypted_password, :string, null: false, default: ""
    add_column :cccux_users, :reset_password_token, :string
    add_column :cccux_users, :reset_password_sent_at, :datetime
    add_column :cccux_users, :remember_created_at, :datetime
    
    add_index :cccux_users, :reset_password_token, unique: true
  end
end
