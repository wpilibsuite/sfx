#!/usr/bin/env rake
require 'ant'
task :default => "single-jar"

nwt_jar = "#{ENV['HOME']}/sunspotfrcsdk/desktop-lib/networktables-desktop.jar"
nwt_jar = ENV['NWT_JAR'] if ENV['NWT_JAR']
jrubyfx_path = ENV['jrubyfx'] || "../jrubyfx/lib/"
jrubyfx_fxmlloader_path = ENV['fxmlloader'] || "../FXMLLoader/lib/"
$LOAD_PATH << jrubyfx_fxmlloader_path
$LOAD_PATH << jrubyfx_path

require 'jrubyfx_tasks'

desc "Creates a single jar from all the other files"
task "single-jar" => :compile do
  cp "../sfxlib/dist/sfxlib.jar", "lib/xsfxlib.jar"
  cp "../sfxmeta/dist/sfxmeta.jar", "lib/xsfxmeta.jar"
  cp "../livewindowplugin/dist/livewindowplugin.jar", "plugins/"
  cp nwt_jar, "lib/networktables-desktop.jar"

  # now we stuff stuff together (ha ha)
  JRubyFX::Tasks::download_jruby("1.7.4") # TODO: should we use JRUBY_VERSION instead? downside => must be same jar as current
  JRubyFX::Tasks::jarify_jrubyfx("lib/*", "lib/main.rb", nil, "sfx.jar")
  ant do
    zip(destfile: "sfx.zip") do
      fileset dir: ".", includes: "plugins/"
      fileset dir: ".", includes: "sfx.jar"
    end
  end
end

desc "Compiles a bunch of other files"
task :compile do
  Dir.chdir("../sfxmeta/") {ant "jar"}
  Dir.chdir("../sfxlib/") {ant ["clean", "jar"]} # must clean or the annotation processors will fail

  JRubyFX::Tasks.compile(Dir['../{livewindowplugin,sfx/lib,sfx/plugins,sfxlib}/**/*.fxml'] + %w{-- ../sfxlib/dist/sfxlib.jar})

  Dir.chdir("../sfxlib/") {ant ["clean", "jar"]} # must clean or the annotation processors will fail
  Dir.chdir("../livewindowplugin/"){ant "jar"}
end

desc "Removes all build files"
task :clean do
  Dir.chdir("../sfxlib/"){ant "clean"}
  Dir.chdir("../sfxmeta/"){ant "clean"}
  Dir.chdir("../livewindowplugin/"){ant "clean"}
  rm FileList["**/*.jar"]
  rm_rf "gems"
  rm FileList["*.zip"]
  rm_rf FileList["../**/.jrubyfx_cache"]
end
