# TODO: cleanup this file. its rather icky
# Check Java version first
jre = ENV_JAVA["java.runtime.version"].match %r{^(?<version>(?<major>\d+)\.(?<minor>\d+))\.(?<patch>\d+)(_(?<update>\d+))?-?(?<release>ea|u\d)?(-?b(?<build>\d+))?}
if jre[:minor].to_i < 7 or (jre[:minor].to_i == 7 and jre[:update].to_i < 6)
  jop = javax.swing.JOptionPane
  jop.show_message_dialog(nil,
    "Your version of the JVM (#{jre[:minor]} with update #{jre[:update]}) is unsupported.
Only Java 7 after update 6 is supported. Java 6 is not supported.",
    "Java Platform Unsupported", # title
    jop::ERROR_MESSAGE)
  exit -1
end
puts "Using Java #{jre} and JRuby #{JRUBY_VERSION}"
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
Only Java 7u6+ is supported. Java 6 and Java 9 are not supported.",
      "JavaFX not found", # title
      jop::ERROR_MESSAGE)
    exit -1
  end
end

# TODO: reload toolbox on icon style change
# set up load path
$LOAD_PATH << "."
$PLUGIN_DIR = File.join(File.dirname(File.dirname(File.expand_path __FILE__)), "plugins")
q = $LOAD_PATH.find { |i| i.include?(".jar!/gems/jrubyfx")}
xx = q && File.dirname(q[0..(2 + q.index(".jar!/gems/jrubyfx"))]).gsub(/^file\:/, '')
sq = q && q[0..(3 + q.index(".jar!/gems/jrubyfx"))]
if q
  $PLUGIN_DIR = File.join(xx, "plugins")
  $LOAD_PATH << xx
end

$LOAD_PATH << "#{Dir.home}/sunspotfrcsdk/desktop-lib/"

# require in all the jars
require 'sfxlib.jar'
require 'sfxmeta.jar'
require "networktables-desktop.jar" # TODO: file.join
require 'version.rb'

# Make sure the same version was in the jars
if SD::Version::Comparable && SD::Version::Value != Java::dashfx.Version.BUILD
  jop = javax.swing.JOptionPane
  jop.show_message_dialog(nil,
    "An old jar file (version #{Java::dashfx.Version.BUILD}) was found that differs from
the current version (#{SD::Version::Value}).",
    "Mixed Version", # title
    jop::ERROR_MESSAGE)
  exit -2
end

puts "Release/Built? #{SD::Version::Comparable} Version Identifier: #{SD::Version::Value}"

fxml_root File.join(File.dirname(__FILE__), "..", "lib", "res"), "sfx/lib/res", (Java::JarMain.is_a? Class and Java::JarMain.java_class.method("resource"))
resource_root :images, File.join(File.dirname(__FILE__), "..", "lib", "res", "img"), "sfx/lib/res/img"

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
