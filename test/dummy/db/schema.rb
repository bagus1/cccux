# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_05_193709) do
  create_table "cccux_ability_permissions", force: :cascade do |t|
    t.string "action"
    t.string "subject"
    t.text "description"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "scoping_conditions"
  end

  create_table "cccux_role_abilities", force: :cascade do |t|
    t.integer "role_id", null: false
    t.integer "ability_permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "owned", default: false, null: false
    t.string "context", default: "global", null: false
    t.index ["ability_permission_id"], name: "index_cccux_role_abilities_on_ability_permission_id"
    t.index ["role_id", "ability_permission_id", "context"], name: "index_role_abilities_on_role_permission_context"
    t.index ["role_id", "ability_permission_id", "owned"], name: "index_role_abilities_on_role_permission_owned"
    t.index ["role_id"], name: "index_cccux_role_abilities_on_role_id"
  end

  create_table "cccux_roles", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.boolean "active"
    t.integer "priority"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cccux_roles_on_name", unique: true
  end

  create_table "cccux_user_roles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_cccux_user_roles_on_role_id"
    t.index ["user_id"], name: "index_cccux_user_roles_on_user_id"
  end

  create_table "cccux_users", force: :cascade do |t|
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.boolean "active"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["email"], name: "index_cccux_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_cccux_users_on_reset_password_token", unique: true
  end

  add_foreign_key "cccux_role_abilities", "cccux_ability_permissions", column: "ability_permission_id"
  add_foreign_key "cccux_role_abilities", "cccux_roles", column: "role_id"
  add_foreign_key "cccux_user_roles", "cccux_roles", column: "role_id"
  add_foreign_key "cccux_user_roles", "cccux_users", column: "user_id"
end
