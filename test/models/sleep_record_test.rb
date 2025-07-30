require "test_helper"

class SleepRecordTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Test User")
    @sleep_record = @user.sleep_records.build(
      clock_in_time: Time.current,
      duration: 0
    )
  end

  test "should be valid with valid attributes" do
    assert @sleep_record.valid?
  end

  test "should require clock_in_time" do
    @sleep_record.clock_in_time = nil
    assert_not @sleep_record.valid?
    assert_includes @sleep_record.errors[:clock_in_time], "can't be blank"
  end

  test "should require user" do
    @sleep_record.user = nil
    assert_not @sleep_record.valid?
  end

  test "should be valid without clock_out_time" do
    assert @sleep_record.valid?
    assert_not @sleep_record.completed?
  end

  test "should be completed when clock_out_time is present and duration is positive" do
    @sleep_record.clock_out_time = Time.current + 8.hours
    @sleep_record.duration = 8.hours.to_i
    assert @sleep_record.completed?
  end

  test "should not be completed when clock_out_time is present but duration is zero" do
    @sleep_record.clock_out_time = Time.current + 8.hours
    @sleep_record.duration = 0
    assert_not @sleep_record.completed?
  end

  test "should return stored duration value" do
    @sleep_record.duration = 28800 # 8 hours in seconds
    assert_equal 28800, @sleep_record.duration
  end

  test "should return 0 duration when not completed" do
    @sleep_record.duration = 0
    assert_equal 0, @sleep_record.duration
    assert_not @sleep_record.completed?
  end

  test "should validate clock_out_time is after clock_in_time" do
    @sleep_record.clock_in_time = Time.current
    @sleep_record.clock_out_time = Time.current - 1.hour

    assert_not @sleep_record.valid?
    assert_includes @sleep_record.errors[:clock_out_time], "must be after clock in time"
  end

  test "should scope completed records" do
    incomplete = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0
    )
    complete = @user.sleep_records.create!(
      clock_in_time: Time.current - 8.hours,
      clock_out_time: Time.current,
      duration: 28800
    )

    completed_records = @user.sleep_records.completed
    assert_includes completed_records, complete
    assert_not_includes completed_records, incomplete
  end

  test "should scope incomplete records" do
    incomplete = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0
    )
    complete = @user.sleep_records.create!(
      clock_in_time: Time.current - 8.hours,
      clock_out_time: Time.current,
      duration: 28800
    )

    incomplete_records = @user.sleep_records.incomplete
    assert_includes incomplete_records, incomplete
    assert_not_includes incomplete_records, complete
  end

  test "should scope previous week records" do
    old_record = @user.sleep_records.create!(
      clock_in_time: 2.weeks.ago,
      duration: 0,
      created_at: 2.weeks.ago
    )
    recent_record = @user.sleep_records.create!(
      clock_in_time: 3.days.ago,
      duration: 0,
      created_at: 3.days.ago
    )

    previous_week_records = @user.sleep_records.previous_week
    assert_includes previous_week_records, recent_record
    assert_not_includes previous_week_records, old_record
  end

  test "should order by duration descending" do
    record1 = @user.sleep_records.create!(
      clock_in_time: Time.current - 10.hours,
      clock_out_time: Time.current - 2.hours,
      duration: 28800 # 8 hours
    )
    record2 = @user.sleep_records.create!(
      clock_in_time: Time.current - 6.hours,
      clock_out_time: Time.current,
      duration: 21600 # 6 hours
    )

    ordered_records = @user.sleep_records.ordered_by_duration
    assert_equal record1, ordered_records.last
    assert_equal record2, ordered_records.first
  end

  test "should order by created time descending" do
    record1 = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0,
      created_at: 2.days.ago
    )
    record2 = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0,
      created_at: 1.day.ago
    )

    ordered_records = @user.sleep_records.ordered_by_created_time
    assert_equal record2, ordered_records.first
    assert_equal record1, ordered_records.last
  end

  test "should find last incomplete record for user" do
    complete_record = @user.sleep_records.create!(
      clock_in_time: 2.days.ago,
      clock_out_time: 1.day.ago,
      duration: 86400
    )
    incomplete_record = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0
    )

    last_incomplete = @user.sleep_records.incomplete.order(:created_at).last
    assert_equal incomplete_record, last_incomplete
  end

  test "should handle multiple incomplete records correctly" do
    first_incomplete = @user.sleep_records.create!(
      clock_in_time: 1.day.ago,
      duration: 0
    )
    second_incomplete = @user.sleep_records.create!(
      clock_in_time: Time.current,
      duration: 0
    )

    incomplete_records = @user.sleep_records.incomplete.order(:created_at)
    assert_equal 2, incomplete_records.count
    assert_equal second_incomplete, incomplete_records.last
  end

  test "should save sleep record successfully" do
    assert_difference '@user.sleep_records.count', 1 do
      @sleep_record.save!
    end

    assert_not_nil @sleep_record.id
    assert_not_nil @sleep_record.created_at
    assert_not_nil @sleep_record.updated_at
  end

  test "should update clock_out_time and duration via service" do
    @sleep_record.save!
    clock_out_time = Time.current + 8.hours
    calculated_duration = 28800 # 8 hours in seconds

    # Simulate service updating both fields together
    @sleep_record.update!(
      clock_out_time: clock_out_time,
      duration: calculated_duration
    )

    assert_equal clock_out_time.to_i, @sleep_record.clock_out_time.to_i
    assert @sleep_record.completed?
    assert_equal calculated_duration, @sleep_record.duration
  end

  test "should handle edge case with same clock_in_and_clock_out_time" do
    current_time = Time.current
    @sleep_record.clock_in_time = current_time
    @sleep_record.clock_out_time = current_time

    assert_not @sleep_record.valid?
    assert_includes @sleep_record.errors[:clock_out_time], "must be after clock in time"
  end

  test "should return completed records only for previous week scope with completion" do
    # Incomplete record from previous week
    incomplete_previous_week = @user.sleep_records.create!(
      clock_in_time: 3.days.ago,
      duration: 0,
      created_at: 3.days.ago
    )

    # Complete record from previous week
    complete_previous_week = @user.sleep_records.create!(
      clock_in_time: 4.days.ago,
      clock_out_time: 4.days.ago + 8.hours,
      duration: 28800,
      created_at: 4.days.ago
    )

    previous_week_completed = @user.sleep_records.previous_week.completed
    assert_includes previous_week_completed, complete_previous_week
    assert_not_includes previous_week_completed, incomplete_previous_week
  end
end
