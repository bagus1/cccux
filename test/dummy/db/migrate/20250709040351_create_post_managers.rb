class CreatePostManagers < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:post_managers)
      create_table :post_managers do |t|
        t.references :user, null: false, foreign_key: true
        t.references :post, null: false, foreign_key: true

        t.timestamps
      end
    end
  end
end
