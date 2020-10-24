require 'yaml'

class SignConfig
  def initialize
    @cfg = YAML.load(File.read("/etc/signcfg.yaml"))
  end

  def [](key)
    @cfg[key]
  end
end
