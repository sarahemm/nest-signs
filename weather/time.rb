class Time
  def self.end_of_tomorrow
    tomorrow = Time.now + 60*60*24
    Time.new(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59, tomorrow.strftime('%:z'))
  end

  def self.today_at(hour:, minute: 0)
    now = Time.now
    Time.new(now.year, now.month, now.day, hour, minute, 00, now.strftime('%:z'))
  end
  
  def self.tomorrow_at(hour:, minute: 0)
    tomorrow = Time.now + 60*60*24
    Time.new(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute, 00, tomorrow.strftime('%:z'))
  end
  
  def is_today?
    now = Time.now
    self.year == now.year and self.month == now.month and self.day == now.day
  end
  
  def is_tomorrow?
    tomorrow = Time.now + 60*60*24
    self.year == tomorrow.year and self.month == tomorrow.month and self.day == tomorrow.day
  end

  def time_only
    Time.new(1970, 01, 01, self.hour, self.min, 00, self.strftime('%:z'))
  end

  def within_of(within, of)
    min_time = of - within
    max_time = of + within
    self.between?(min_time, max_time)
  end
end
