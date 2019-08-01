# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_07_31_211228) do

  create_table "stripe_events", force: :cascade do |t|
    t.string "stripe_id", null: false
    t.string "stripe_type", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["stripe_id"], name: "index_stripe_events_on_stripe_id", unique: true
    t.index ["stripe_type"], name: "index_stripe_events_on_stripe_type"
  end

  create_table "users", force: :cascade do |t|
    t.string "session_user_id"
    t.integer "billing_status", default: 0, null: false
    t.datetime "trial_over_at", null: false
    t.string "billing_email"
    t.string "stripe_customer_id"
    t.string "card_last_four"
    t.string "card_brand"
    t.datetime "card_expires_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["session_user_id"], name: "index_users_on_session_user_id", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

end
