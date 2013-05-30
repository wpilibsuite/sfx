require 'jrubyfx'
#p Java::javafx.beans.property.SimpleStringProperty
$LOAD_PATH << "."
$PLUGIN_DIR = File.join(File.dirname(File.dirname(File.expand_path __FILE__)), "plugins")
q = $LOAD_PATH.find { |i| i.include?(".jar!/META-INF/jruby.home/lib/ruby/")}
if q
  xx = File.dirname(q[0..(2 + q.index(".jar!/META-INF/jruby.home/lib/ruby/"))]).gsub(/^file\:/, '')
  $PLUGIN_DIR = File.join(xx, "plugins")
  $LOAD_PATH << xx
end

require 'sfxlib.jar'
require 'sfxmeta.jar'
require "#{ENV["HOME"]}/sunspotfrcsdk/desktop-lib/networktables-desktop.jar" # TODO: file.join
#p Java::dashfx.lib.data.InitInfo
#p Java::dashfx.lib.data.DataInitDescriptor
fxml_root File.join(File.dirname(__FILE__), "res"), "res"

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "SmartDashboard") do
        fxml SD::Designer
        icons.add image("file://" + File.join(File.dirname(__FILE__), "res", "icon.png"))
        show
      end
    end
  end
end

require 'designer'

SD::App.launch
