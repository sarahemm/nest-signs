require 'signconfig.rb'

class SignInterface
  def initialize(type:, render_direct: false)
    @type = type
    @cfg = SignConfig.new
    @nodes = @cfg['signs'][@type.to_s]
    @nodes = [@nodes] if @nodes.class == String
    @signsvc = SyncSign::Service.new(apikey: @cfg['keys']['syncsign'], render_direct: render_direct)
  end

  def update(template:)
    @nodes.each do |nodeid|
      @signsvc.node(nodeid).render(template: template)
    end
  end
end
