class AddDurationToSleepRecords < ActiveRecord::Migration[8.0]
  def up
    # Rename the existing index to avoid conflict
    rename_index :sleep_records, 'index_sleep_records_on_duration', 'index_sleep_records_on_clock_in_and_clock_out'

    add_column :sleep_records, :duration, :integer, null: false, default: 0

    # Add index for duration to optimize queries
    add_index :sleep_records, :duration
  end

  def down
    remove_index :sleep_records, :duration
    remove_column :sleep_records, :duration

    # Rename the index back to its original name
    rename_index :sleep_records, 'index_sleep_records_on_clock_in_and_clock_out', 'index_sleep_records_on_duration'
  end
end
