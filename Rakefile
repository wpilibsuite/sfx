#!/usr/bin/env rake
require 'ant'
task :default => "single-jar"

nwt_jar = "target/dependency/NetworkTables-0.1.0-SNAPSHOT.jar"
nwt_jar = ENV['NWT_JAR'] if ENV['NWT_JAR']
jrubyfx_path = ENV['jrubyfx'] || "../jrubyfx/lib/"
jrubyfx_fxmlloader_path = ENV['fxmlloader'] || "../FXMLLoader/lib/"
$LOAD_PATH << jrubyfx_fxmlloader_path
$LOAD_PATH << jrubyfx_path

require 'jrubyfx_tasks'

require 'jbundler'
require 'warbler'
JBundler.install unless File.exist? ".jbundler/classpath.rb"
wt = Warbler::Task.new

def f?(test)
  fail "Ant failure: #{test}" if test && test != true && test != 0
end

desc "Creates a single jar from all the other files"
task "single-jar2" => :compile do
  cp "../sfxlib/dist/sfxlib.jar", "lib/sfxlib.jar"
  cp "../sfxmeta/dist/sfxmeta.jar", "lib/sfxmeta.jar"
  cp "../livewindowplugin/dist/livewindowplugin.jar", "plugins/"
  cp nwt_jar, "lib/networktables-desktop.jar"
  # generate version header (if found). Must be the same format as sfxlib (generated by build.xml)
  File.open("lib/version.rb", "w") do |out|
    out << <<EOF
module SD
  class Version
    Comparable = #{(!!(ENV['BUILD_TAG'] && ENV['BUILD_ID'])).inspect}
    Value = "#{ENV['BUILD_TAG']}-#{ENV['BUILD_ID']}-#{ENV['GIT_COMMIT']}"
  end
end
EOF
  end
  # save it in the dialog also
  about_diag = "lib/res/About.fxml"
  contents = File.read(about_diag).gsub("$$VERSION$$", "#{ENV['BUILD_TAG']}-#{ENV['BUILD_ID']}-#{ENV['GIT_COMMIT']}")
  File.open(about_diag, "w+") { |f| f.write(contents) }
end
task wt.name => "single-jar2"

task "single-jar" => wt.name do
  mkdir_p "target/zip"
  cp "sfx.jar", "target/zip/sfx.jar"
  cp_r "plugins", "target/zip/"
end

desc "Compiles a bunch of other files"
task :compile do
  Dir.chdir("../sfxmeta/") {f? ant "jar"}
  Dir.chdir("../sfxlib/") {f? ant ["clean", "jar", "-Dvar.sunspot.home=#{Dir.home}/sunspotfrcsdk"]} # must clean or the annotation processors will fail
  extralib = "../livewindowplugin/dist/livewindowplugin.jar"
  extralib = if File.exist? extralib
    [extralib]
  else
    []
  end
  # to compile the fxml, we need the TFP in memory
  require_relative 'lib/utils/titled_form_pane'
  require '../sfxlib/dist/sfxlib.jar'
  require_relative 'lib/designer_support/data_source_editor'
  require 'jrubyfx'
fxml_root File.join(File.dirname(__FILE__),  "lib", "res")
  JRubyFX::Tasks.compile(Dir['../{livewindowplugin,sfx/lib,sfx/plugins,sfxlib}/**/*.fxml'] + %W{-- ../sfxlib/dist/sfxlib.jar} + extralib)

  Dir.chdir("../sfxlib/") {f? ant ["clean", "jar", "-Dvar.sunspot.home=#{Dir.home}/sunspotfrcsdk"]} # must clean or the annotation processors will fail
  Dir.chdir("../livewindowplugin/"){f? ant "jar"}
end

desc "Removes all build files"
task :clean do
  Dir.chdir("../sfxlib/"){f? ant "clean"}
  Dir.chdir("../sfxmeta/"){f? ant "clean"}
  Dir.chdir("../livewindowplugin/"){f? ant "clean"}
  rm FileList["**/*.jar"]
  rm_rf "gems"
  rm FileList["*.zip"]
  rm_rf FileList["../**/.jrubyfx_cache"]
end
