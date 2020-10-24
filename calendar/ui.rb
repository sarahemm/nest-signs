require 'syncsign'
require 'em/mqtt'

class UIManager
  def initialize(signmgr: nil, calmgr: nil)
    @cur_screen = :default
    @sign = signmgr
    @cal = calmgr
    @sign.button_callback = lambda { |button|
      self.current_screen = button
      process_updates
    }
  end

  def run
    process_updates

    EventMachine.run do
      # set up a thread to listen for button press events
      @sign.button_manager

      # set up a thread to handle refreshing calendar data
      EventMachine::PeriodicTimer.new(30.0) do
        # reset the date shift if we've been idle for awhile
        if(@screen_change_time != nil and (Time.now - @screen_change_time) >= SCREEN_RETURN_TIME)
          puts "Idle, switching display back to default."
          self.current_screen = :default
          @screen_change_time = nil
        end
        process_updates
      end
    end
  end

  def process_updates
    puts "Getting list of events..."
    events = @cal.get_events(
      date: self.current_date,
      one_day: (self.effective_screen != :more_events),
      calendars: [
        "primary",
        "saskeah@gmail.com", 
        "i5ha25ah2lb3sl525lln97mndo@group.calendar.google.com"
      ]
    )
    print "Pushing events to sign..."
    updated = @sign.update(events: events, title: current_screen_title, buttons: current_buttons, one_day: (self.effective_screen != :more_events))
    puts updated ? "done." : "skipped."
  end
  
  def current_screen=(new_screen)
    puts "Changing current screen to #{new_screen.to_s}"
    @screen_change_time = (new_screen == :default) ? nil : Time.now
    @cur_screen = new_screen
  end

  def current_screen
    @cur_screen
  end

  def current_screen_title
    case self.effective_screen
      when :today
        return "Today's Events"
      when :yesterday
        return "Yesterday"
      when :tomorrow
        return "Tomorrow"
      when :more_events
        return "Future Events"
    end
  end

  def current_date
    case self.effective_screen
      when :today, :more_events
        return DateTime.now
      when :yesterday
        return DateTime.now - 1
      when :tomorrow
        return DateTime.now + 1
    end
  end

  def effective_screen
    # return the screen actually displayed (e.g. :default will return
    # :today or :tomorrow depending on the time of day)
    eff_screen = @cur_screen
    if(eff_screen == :default) then
      eff_screen = Time.now.hour >= TOMORROW_AFTER_HOUR ? :tomorrow : :today
    end
    
    eff_screen
  end

  def current_buttons
    case self.effective_screen
      when :yesterday
        return [:today, :tomorrow, nil, :more_events]
      when :today
        return [:yesterday, :tomorrow, nil, :more_events]
      when :tomorrow
        return [:yesterday, :today, nil, :more_events]
      when :more_events
        return [:yesterday, :tomorrow, nil, :today]
    end
  end
end

