class SleepRecordsSerializer
  include MySerializer

  attribute :id
  attribute :clock_in_time do |record|
    strftime(record.clock_in_time, "%Y-%m-%d %H:%M:%S")
  end
  attribute :clock_out_time do |record|
    strftime(record.clock_out_time, "%Y-%m-%d %H:%M:%S")
  end
  attribute :duration

end
