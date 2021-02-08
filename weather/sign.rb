#!/usr/bin/ruby

require 'syncsign'
require './weather-icons.rb'

class Sign
  def initialize(logger:)
    @logger = logger
    @last_items = []
    @last_data = {
      now_type: :unknown,
      now_temp: -999,
      now_humidity: 999,
      later_type: :unknown,
      later_time: Time.now,
      refresh_time: Time.now - REFRESH_SECS*2
    }
    @signintf = SignInterface.new(type: :weather)
  end

  def update(now_type:, now_temp:, now_feelslike:, now_humidity:, now_daynight:, later_type: nil, later_temp: nil, later_feelslike: nil, later_humidity: nil, later_time: nil, later_daynight: nil, later_resolution: nil, updates_today:)
    now_temp_type = :real
    now_temp_display = now_temp
    if(now_feelslike < now_temp - WINDCHILL_DIFF and now_temp < WINDCHILL_MAX_TEMP) then
      now_temp_type = :wind_chill
      now_temp_display = now_feelslike
    end
    items = gen_sign_items(
      base_x: 4,
      title: "Now",
      type: now_type,
      temp: now_temp_display,
      temp_type: now_temp_type,
      humidity: now_humidity,
      day_night: now_daynight
    )

    later_time_str = later_time.strftime("%d-%m-%Y %H:%M")
    approx = later_resolution == :hour
    
    if(later_time.is_today?) then
      later_time_str = "Today at #{approx ? "~" : ""}#{later_time.strftime("%H:%M")}"
    elsif(later_time.is_tomorrow?) then
      later_time_str = "Tomorrow at #{approx ? "~" : ""}#{later_time.strftime("%H:%M")}"
    end
    
    later_temp_type = :real
    later_temp_display = later_temp
    if(later_feelslike < later_temp - WINDCHILL_DIFF and later_temp < WINDCHILL_MAX_TEMP) then
      later_temp_type = :wind_chill
      later_temp_display = later_feelslike
    end

    later_items = gen_sign_items(
      base_x: 156,
      title: "Later",
      type: later_type,
      temp: later_temp_display,
      temp_type: later_temp_type,
      humidity: later_humidity,
      day_night: later_daynight
    )
    later_items.push SyncSign::Widget::Textbox.new(
      x: 152, y: 104, width: 144, height: 26,
      align: :center,
      font: :ddin,
      size: 16,
      text: later_time_str
    )
    items.push(later_items)
    items.flatten!
    
    # add the divider between now and later
    items.push(SyncSign::Widget::Line.new(x0: 148, y0: 0, x1: 148, y1: 128))

    return :identical if items == @last_items
    update_reasons = is_update_required?(now_type: now_type, now_temp: now_temp_display, now_humidity: now_humidity, later_type: later_type, later_time: later_time)
    return :stale_data_ok if !update_reasons
        
    status_string = "#{Time.now.strftime("%H:%M")} #{updates_today} #{update_reasons.join(" ")}"
    
    @last_items = items.clone
    @last_data = {
      now_type: now_type,
      now_temp: now_temp,
      now_humidity: now_humidity,
      later_type: later_type,
      later_time: later_time,
      refresh_time: Time.now
    }
    
    items.push(SyncSign::Widget::Textbox.new(
        x: 8, y: 112, width: 136, height: 10,
        align: :left,
        font: :charriot,
        size: 10,
        text: status_string
    ))

    tmpl = SyncSign::Template.new(items: items)
    @signintf.update(template: tmpl)

    :updated
  end
  
  private

  def gen_sign_items(base_x:, title:, type:, temp:, humidity:, day_night:, temp_type: :real)
    # generate a group of items for half the weather display
    icon = WEATHER_ICON_MAPPING[day_night][type]
    icon_colour = is_weather_bad?(type) ? :red : :black
    temp_colour = is_temperature_bad?(temp) ? :red : :black
    humidity_colour = is_humidity_bad?(humidity) ? :red : :black

    items = [
      SyncSign::Widget::Textbox.new(
        x: (base_x+40), y: 0, width: 64, height: 26,
        align: :center,
        font: :roboto_slab,
        size: 24,
        text: title
      ),
      # Icon
      SyncSign::Widget::Symbolbox.new(
        x: base_x, y: 32, width: 72, height: 72,
        type: :weather,
        colour: icon_colour,
        symbols: [icon]
      ),
      # Temperature
      SyncSign::Widget::Textbox.new(
        x: (base_x+66), y: 36, width: 40, height: 32,
        align: :right,
        font: :ddin_condensed,
        size: 32,
        colour: temp_colour,
        text: temp.round.to_s
      ),
      # Humidity
      SyncSign::Widget::Textbox.new(
        x: (base_x+74), y: 68, width: 32, height: 32,
        align: :right,
        font: :ddin_condensed,
        size: 32,
        colour: humidity_colour,
        text: humidity.round.to_s
      ),
      SyncSign::Widget::Textbox.new(
        x: (base_x+109), y: 68, width: 24, height: 32,
        align: :right,
        font: :ddin_condensed,
        size: 32,
        colour: humidity_colour,
        text: "%"
      ),
    ]
    case temp_type
      when :real
        items << SyncSign::Widget::Symbolbox.new(
          x: (base_x+106), y: 21, width: 32, height: 48,
          type: :weather,
          colour: temp_colour,
          symbols: [:celsius]
        )
      when :wind_chill
        items << SyncSign::Widget::Textbox.new(
          x: (base_x+106), y: 40, width: 32, height: 24,
          align: :right,
          font: :ddin_condensed,
          size: 24,
          colour: temp_colour,
          text: "WC"
        )
    end

    items 
  end

  def is_weather_bad?(conditions)
    if([:fog, :fog_light, :cloudy, :mostly_cloudy, :partly_cloudy, :mostly_clear, :clear].include?(conditions)) then
      return false
    else
      return true
    end
  end

  def is_temperature_bad?(temp)
    !temp.between?(-10, +26)
  end

  def is_humidity_bad?(humidity)
    humidity > 70
  end

  def is_update_required?(now_type:, now_temp:, now_humidity:, later_type:, later_time:)
    update_required = false
    update_reasons = []
    update_reasons_short = []
    min_stale_temp = @last_data[:now_temp] - REFRESH_TEMP_CHG/2
    max_stale_temp = @last_data[:now_temp] + REFRESH_TEMP_CHG/2
    min_stale_humidity = @last_data[:now_humidity] - REFRESH_HUMID_CHG/2
    max_stale_humidity = @last_data[:now_humidity] + REFRESH_HUMID_CHG/2

    
    if(is_weather_bad?(@last_data[:now_type]) != is_weather_bad?(now_type)) then
      # 'now' weather changed from good to bad or vice versa
      update_required = true
      update_reasons.push :now_weather_changed
      update_reasons_short.push 'W'
    end
    if(is_weather_bad?(@last_data[:later_type]) != is_weather_bad?(later_type)) then
      # 'later' weather changed from good to bad or vice versa
      update_required = true
      update_reasons.push :later_weather_changed
      update_reasons_short.push 'w'
    end
    if(!@last_data[:later_time].within_of(REFRESH_LATER_TIME_SECS_CHG, later_time)) then
      # Time of 'later' weather changed by at least the threshold
      update_required = true
      update_reasons.push :later_time_changed
      update_reasons_short.push '@'
    end
    if(later_time - Time.now < REFRESH_SECS && !@last_data[:later_time].within_of(REFRESH_LATER_TIME_SECS_CHG_CLOSE, later_time)) then
      puts "Close weather is #{later_time - Time.now} seconds away (<#{REFRESH_SECS}) and #{later_time.to_s} is within #{REFRESH_LATER_TIME_SECS_CHG_CLOSE} seconds of #{Time.now.to_s}."
      # Time of 'later' weather changed by the 'close' threshold and the
      # later weather time is within the normal refresh time
      update_required = true
      update_reasons.push :later_time_changed_close
      update_reasons_short.push '@!'
    end
    if(!now_temp.between?(min_stale_temp, max_stale_temp)) then
      # 'now' temperature changed by more than the 'stale data okay' threshold
      update_required = true
      update_reasons.push :now_temp_changed
      update_reasons_short.push 'T'
    end
    if(!now_humidity.between?(min_stale_humidity, max_stale_humidity)) then
      # 'now' humidity changed by more than the 'stale data okay' threshold
      update_required = true
      update_reasons.push :now_humidity_changed
      update_reasons_short.push 'H'
    end
    if(Time.now - @last_data[:refresh_time] > REFRESH_SECS) then
      # haven't refreshed in REFRESH_SECS
      update_required = true
      update_reasons.push :min_refresh_interval
      update_reasons_short.push 'R'
    end

    @logger.debug "Reasons for display update: #{update_reasons.join(", ")}" if update_required
    return false unless update_required
    update_reasons_short
  end
end

