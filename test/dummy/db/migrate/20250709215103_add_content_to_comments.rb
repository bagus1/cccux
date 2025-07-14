class AddContentToComments < ActiveRecord::Migration[7.2]
  def change
    add_column :comments, :content, :text
  end
end
