class CreateSleepRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :sleep_records do |t|
      t.references :user
      t.datetime :clock_in_time, null: false
      t.datetime :clock_out_time
      t.timestamps
    end

    add_index :sleep_records, [:user_id, :created_at]
    add_index :sleep_records, :clock_in_time
    add_index :sleep_records, :created_at
    add_index :sleep_records, [:clock_in_time, :clock_out_time], name: 'index_sleep_records_on_duration'

  end
end
