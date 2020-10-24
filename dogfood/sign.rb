#!/usr/bin/ruby

require 'syncsign'

class Sign
  def initialize(logger:)
    @logger = logger
    @signintf = SignInterface.new(type: :dogfood)
  end

  def update(meal:, feed:, prepare:)
    prepare = {} if !prepare
    items = gen_sign_items(
      base_x: 0,
      pet: "Boom",
      feed: feed['boom'],
      prepare: prepare['boom'],
    )
    items += gen_sign_items(
      base_x: 150,
      pet: "Pavot",
      feed: feed['pavot'],
      prepare: prepare['pavot'],
    )

    items.flatten!
    # add the divider between Boom and Pavot
    items.push(SyncSign::Widget::Line.new(x0: 144, y0: 0, x1: 144, y1: 104))
    # add the meal
    items.push SyncSign::Widget::Textbox.new(
      x: 148-80/2-4, y: 108, width:80, height: 32,
      align: :center,
      font: :aprilsans,
      size: 24,
      text: meal
    )

    tmpl = SyncSign::Template.new(items: items)
    @signintf.update(template: tmpl)
  end
  
  private

  def gen_sign_items(base_x:, pet:, feed:, prepare:)
    feed = [] unless feed
    prepare = [] unless prepare

    next_text_top = 32
    # generate a group of items for half the dog food display
    tmpl = [
      SyncSign::Widget::Textbox.new(
        x: (base_x+4), y: 0, width: 136, height: 32,
        align: :center,
        font: :roboto_slab,
        size: 24,
        text: pet
      ),
    ]

    feed.each do |item|
      text = ""
      type = nil
      if(item['food']) then
        text = item['food']
        type = :food
      elsif(item['med'])
        text = item['med']
        type = :med
      end
      
      tmpl.push SyncSign::Widget::Textbox.new(
        x: (base_x), y: next_text_top, width: 144, height: 32,
        align: :center,
        font: :roboto_condensed,
        size: 24,
        colour: type == :food ? :black : :red,
        text: text
      )
      next_text_top += 24
    end
    if(!prepare.empty?) then
      next_text_top += 8
      tmpl.push SyncSign::Widget::Textbox.new(
        x: (base_x), y: next_text_top, width: 144, height: 24,
        align: :center,
        font: :ddin_condensed,
        size: 16,
        text: "Prepare for Later:"
      )
      next_text_top += 16
    end
    prepare.each do |item|
      text = ""
      type = nil
      if(item['food']) then
        text = item['food']
        type = :food
      elsif(item['med'])
        text = item['med']
        type = :med
      end
      tmpl.push SyncSign::Widget::Textbox.new(
        x: (base_x), y: next_text_top, width: 144, height: 24,
        align: :center,
        font: :ddin_condensed,
        size: 16,
        colour: type == :food ? :black : :red,
        text: text
      )
      next_text_top += 16
    end

    tmpl.flatten
  end
end

