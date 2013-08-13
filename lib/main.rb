# TODO: cleanup this file. its rather icky
# Check Java version first
jre = ENV_JAVA["java.runtime.version"].match %r{^(?<version>(?<major>\d+)\.(?<minor>\d+))\.(?<patch>\d+)(_(?<update>\d+))?-?(?<release>ea|u\d)?(-?b(?<build>\d+))?}
if jre[:minor].to_i != 7 or jre[:update].to_i < 6
  jop = javax.swing.JOptionPane
  jop.show_message_dialog(nil,
    "Your version of the JVM (#{jre[:minor]} with update #{jre[:update]}) is unsupported.
Only Java 7 after update 6 is supported. Java 6 and Java 8 are not supported.",
    "Java Platform Unsupported", # title
    jop::ERROR_MESSAGE)
  exit -1
end
begin
  require 'jrubyfx'
rescue SystemExit
  begin
    # Attempt to load a javafx class to see if thats why we are exiting
    Java.javafx.application.Application
  rescue  LoadError, NameError
    jop = javax.swing.JOptionPane
    jop.show_message_dialog(nil,
      "JavaFX not found.
Only Java 7u6 is supported. Java 6 and Java 8 are not supported.",
      "JavaFX not found", # title
      jop::ERROR_MESSAGE)
    exit -1
  end
end
# TODO: reload toolbox on icon style change
# set up load path
$LOAD_PATH << "."
$PLUGIN_DIR = File.join(File.dirname(File.dirname(File.expand_path __FILE__)), "plugins")
q = $LOAD_PATH.find { |i| i.include?(".jar!/META-INF/jruby.home/lib/ruby/")}
if q
  xx = File.dirname(q[0..(2 + q.index(".jar!/META-INF/jruby.home/lib/ruby/"))]).gsub(/^file\:/, '')
  $PLUGIN_DIR = File.join(xx, "plugins")
  $LOAD_PATH << xx
  unless File.exist? File.join(xx, "sfxlib.jar")
    # extract them to avoid double double trouble trouble
    sq = q[0..(3 + q.index(".jar!/META-INF/jruby.home/lib/ruby/"))]
    ["sfxlib.jar", "sfxmeta.jar"].each do |filen|
      is = java.net.URL.new("jar:#{sq}!/x#{filen}").open_stream
      File.open(File.join(xx, filen),"wb") do |f|
        ar = Java::byte[40960].new
        loop do
          r = is.read(ar, 0, 40960)
          if r == 40960
            f << ar.to_s
          elsif r == -1
            break
          else
            f << ar.to_s[0...r]
          end
        end
      end
    end
  end
end

$LOAD_PATH << "#{Dir.home}/sunspotfrcsdk/desktop-lib/"

# require in all the jars
require 'sfxlib.jar'
require 'sfxmeta.jar'
require "networktables-desktop.jar" # TODO: file.join

fxml_root File.join(File.dirname(__FILE__), "res"), "res"
resource_root :images, File.join(File.dirname(__FILE__), "res", "img"), "res/img"

module SD
  class App < JRubyFX::Application
    def start(stage)
      with(stage, :title => "SmartDashboard") do
        fxml SD::Designer
        icons.add image(resource_url(:images, "16-fxicon.png").to_s)
        icons.add image(resource_url(:images, "32-fxicon.png").to_s)
        show
      end
    end
  end
end

require 'designer'

SD::App.launch
