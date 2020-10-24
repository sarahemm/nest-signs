#!/usr/bin/ruby

require 'syncsign'
require 'em/mqtt'

class SignManager
  attr_writer :button_callback

  def initialize
    @signintf = SignInterface.new(type: :calendar, render_direct: true)
    @last_events_string = ""
    @last_title = ""
    @button_callback = nil
  end

  def update(events: nil, title: nil, buttons: [], one_day: true)
    @current_buttons = buttons
    # turn e.g. :more_info into "More Info" for button labels
    button_labels = buttons.map { |a| 
      a.to_s.gsub("_", " ").gsub(/\w+/) { |str|
        str.capitalize
      }
    }

    events_string = ""
    if(one_day) then
      events_string = format_events(events: events)
    else
      events_string = format_events_multiday(events: events)
    end
    return false if events_string == @last_events_string and title == @last_title 
    today = (title == "Today's Events") ? Time.now.strftime("%A %B %d, %Y") : ""
    
    @last_events_string = events_string
    @last_title = title

    items = [
      SyncSign::Widget::Textbox.new(
        x: 0, y: 0, width: 400, height: 64,
        align: :center,
        font: :roboto_slab,
        size: 48,
        text: title
      ),
      SyncSign::Widget::Textbox.new(
        x: 0, y: 66, width: 400, height: 24,
        align: :center,
        font: :aprilsans,
        size: 24,
        text: today
      ),
      SyncSign::Widget::Textbox.new(
        # bump the top down if we're displaying today's date as well
        x: 0, y: (today.length == 0 ? 72 : 72+24), width: 400, height: 225,
        align: :left,
        font: one_day ? :roboto_condensed : :aprilsans,
        size: one_day ? 24 : 16,
        linespacing: one_day ? 8 : 2,
        text: events_string
      ),
      SyncSign::Widget::Textbox.new(
        x: 304, y: 254, width: 96, height: 24,
        align: :center,
        font: :charriot,
        size: 10,
        linespacing: 1,
        text: "Last Update\n#{Time.now.strftime("%Y-%m-%d %H:%M")}"
      ),
      SyncSign::Widget::ButtonLabels.new(
        labels: button_labels
      )
    ]

    tmpl = SyncSign::Template.new(items: items, enable_buttons: true)
    @signintf.update(template: tmpl)

    true
  end

  def button_manager
    EventMachine::MQTT::ClientConnection.connect('localhost', :keep_alive => 30) do |c|
      c.subscribe('syncsign/button')
      c.receive_callback do |message|
        button = JSON.parse(message.payload)['buttonPressed'].to_i
        next if @current_buttons.length < button or !@current_buttons[button-1]
        @button_callback.call @current_buttons[button-1]
      end
    end
  end

  private

  def format_events(events: [])
    allday_event_list = ""
    event_list = ""

    if(events.empty?)
      event_list = "No Events!"
    else
      events[0..5].each do |event|
        name = event[:name]
        if(event[:all_day])
          name = "#{name[0..31].strip}..." if name.length > 32
          allday_event_list += "> #{name}\n"
        else
          name = "#{name[0..28].strip}..." if name.length > 29
          event_list += "#{event[:start].strftime("%H:%M")} #{name}\n"
        end
      end
      event_list += "[more events today]" if events.length > 6
    end

    if(allday_event_list == "") then
      return event_list
    else
      return "#{allday_event_list}#{event_list}"
    end
  end
  
  def format_events_multiday(events: [])
    event_list = ""
    if(events.empty?)
      event_list = "No Events!"
    else
      events[0..8].each do |event|
        if(event[:all_day])
          event_list += "#{event[:start].strftime("%a %Y-%m-%d")} #{event[:name]}\n"
        else
          event_list += "#{event[:start].strftime("%a %Y-%m-%d %H:%M")} #{event[:name]}\n"
        end
      end
    end

    event_list
  end
end

