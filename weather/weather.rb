#!/usr/bin/ruby

require 'weatherb'
require 'time'
require 'pp'

class Weather
  def initialize(apikey:, latitude:, longitude:, logger:)
    @logger = logger
    @lat = latitude
    @lon = longitude
    @required_fields = %w{temp feels_like wind_speed wind_gust precipitation precipitation_type surface_shortwave_radiation humidity weather_code sunset sunrise}
    @weatherb = Weatherb::API.new(apikey)
  end

  def minutely
    begin
      Forecast.new resolution: :minute, data: @weatherb.nowcast(lat: @lat, lon: @lon, fields: @required_fields)
    rescue
      sleep 60
      retry
    end
  end
  
  def hourly
    begin
      Forecast.new resolution: :hour, data: @weatherb.hourly(lat: @lat, lon: @lon, fields: @required_fields)
    rescue
      sleep 60
      retry
    end
  end

  def now
    begin
      ForecastEntry.new resolution: :now, data: @weatherb.realtime(lat: @lat, lon: @lon, fields: @required_fields)
    rescue
      sleep 60
      retry
    end
  end

  def next_precip(reverse: false)
    # see if there's any precipitation in the 6h minutely forecast
    forecast = self.minutely
    forecast.each do |entry|
      break if entry.time > Time.end_of_tomorrow
      if(entry.is_precipitating? ^ reverse) then
        #puts "Returning minutely entry that is #{entry.time - Time.now} secs away"
        return entry
      end
    end

    # nothing in the 6h minutely forecast, try the longer hourly one
    forecast = self.hourly
    forecast.each do |entry|
      # skip any data that's in the past
      next if entry.time < Time.now
      # skip any data that's within 6 hours of now
      # TODO: base this time on the last entry that the minutely forecast gave us instead
      #if(entry.time - Time.now < 60*60*6) then
        #puts "Skipping hourly forecast for #{entry.time.to_s} as it is within 6h of now"
      #else
        #puts "Looking at hourly forecast for #{entry.time.to_s} as it is more than 6h away (#{entry.time - Time.now} secs away)"
      #end
      next if entry.time - Time.now < 60*60*6
      # only look up until the end of tomorrow
      break if entry.time > Time.end_of_tomorrow

      if(entry.is_precipitating? ^ reverse) then
        #puts "Returning hourly entry that is #{entry.time - Time.now} secs away"
        return entry
      end
    end
    
    #puts "no precip!"    
    # no precipitation in the next while!
    nil
  end

  class Forecast
    attr_reader :resolution, :entries

    def initialize(resolution:, data:)
      @resolution = resolution
      @entries = {}
      data.each do |datum|
        entry = ForecastEntry.new(resolution: resolution, data: datum)
        @entries[entry.time] = entry
      end
    end

    def [](idx)
      if(idx.class == Integer) then
        return @entries[@entries.keys[idx]]
      elsif(idx.class == Time) then
        return @entries[idx]
      end
      
      nil
    end

    def each
      @entries.each do |key, entry|
        yield entry
      end
    end
  end

  class ForecastEntry
    attr_reader :time, :temperature, :feels_like, :humidity, :wind_speed, :wind_gust, :precipitation, :uv, :weather_type, :day_night, :resolution

    def initialize(resolution:, data:)
      @time = Time.parse(data['observation_time']['value']).localtime
      @temperature = data['temp']['value']
      @feels_like = data['feels_like']['value']
      @humidity = data['humidity']['value']
      @wind_speed = data['wind_speed']['value']
      @wind_gust = data['wind_gust']['value']
      @precipitation = {type: data['precipitation_type']['value'], amount: data['precipitation']['value']}
      @uv = data['surface_shortwave_radiation']['value']
      @weather_type = data['weather_code']['value'].to_sym
      @sunset = Time.parse(data['sunset']['value']).localtime
      @sunrise = Time.parse(data['sunrise']['value']).localtime
      @day_night = (@time.time_only.between?(@sunrise.time_only, @sunset.time_only)) ? :day : :night
      @resolution = resolution
    end

    def is_precipitating?
      @precipitation[:value] and @precipitation[:value] > 0
    end
  end
end

