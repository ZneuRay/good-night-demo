class SleepRecordsSerializer
  include MySerializer

  attribute :id
  attribute :clock_in_time do |record|
    record.clock_in_time.strftime("%Y-%m-%d %H:%M:%S")
  end
  attribute :clock_out_time do |record|
    record.clock_out_time.strftime("%Y-%m-%d %H:%M:%S")
  end
  attribute :duration

end
