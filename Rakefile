#!/usr/bin/env rake
require 'ant'
task :default => "single-jar"

nwt_jar = "#{ENV['HOME']}/sunspotfrcsdk/desktop-lib/networktables-desktop.jar"
nwt_jar = ENV['NWT_JAR'] if ENV['NWT_JAR']
jrubyfx_path = ENV['jrubyfx'] || "../jrubyfx/lib/"
jrubyfx_fxmlloader_path = ENV['fxmlloader'] || "../FXMLLoader/lib/"
$LOAD_PATH << jrubyfx_fxmlloader_path
$LOAD_PATH << jrubyfx_path


desc "Creates a single jar from all the other files"
task "single-jar" => :compile do
  cp "../sfxlib/dist/sfxlib.jar", "lib/"
  cp "../sfxmeta/dist/sfxmeta.jar", "lib/"
  cp nwt_jar, "lib/networktables-desktop.jar"

  # now we stuff stuff together (ha ha)
  require 'jrubyfx_tasks'
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
  ant do
    ant(dir: "../sfxmeta/", target: "jar")
    ant(dir: "../sfxlib/") do
      target name: "clean" # must clean or the annotation processors will fail
      target name: "jar"
    end
  end
end

desc "Removes all build files"
task :clean do
  ant do
    ant(dir: "../sfxlib/") do
      target name: "clean"
    end
    ant(dir: "../sfxmeta/") do
      target name: "clean"
    end
  end
  FileList["**/*.jar"].each do |ajar|
    rm ajar
  end
  rm_rf "gems"
  FileList["*.zip"].each do |ajar|
    rm ajar
  end
end


desc "Patches local gems"
task :patch do
  cp "fixes/observable_value.rb", File.join(jrubyfx_path, "jrubyfx", "core_ext")
  cp "fixes/j8_expression_value.rb", File.join(jrubyfx_fxmlloader_path, "fxmlloader")
end
