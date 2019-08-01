class CreateInitialDatabase < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string     :session_user_id

      t.integer    :billing_status,        null: false, default: 0 # 0 = trialing, 1 = active, 2 = active_until_period_end, 3 = cancelled, 4 = past_due
      t.datetime   :trial_over_at,         null: false,
                                           default: -> { "(datetime('now', '+14 days'))" }
      t.string     :billing_email
      t.string     :stripe_customer_id
      t.string     :card_last_four
      t.string     :card_brand
      t.datetime   :card_expires_at

      t.timestamps
    end

    add_index :users, :session_user_id, unique: true
    add_index :users, :stripe_customer_id, unique: true

    create_table :stripe_events do |t|
      t.string     :stripe_id,             null: false
      t.string     :stripe_type,           null: false

      t.timestamps
    end

    add_index :stripe_events, :stripe_id, unique: true
    add_index :stripe_events, :stripe_type
  end
end
