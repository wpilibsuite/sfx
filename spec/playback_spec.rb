# encoding: utf-8
# Copyright (C) 2013 patrick
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


require 'playback'

PLAYBACK_FILE = "/tmp/testplayback.plybk"
module PlaybackHelper
  currier = lambda{|fn, rw|SD::PlaybackDumper.new(fn, rw)}.to_proc.curry(2)[PLAYBACK_FILE]
  define_method(:reader) {currier.('r')}
  define_method(:writer) {currier.('w')}
end

## RSpec configuration block
RSpec.configure do |config|
  config.mock_with :rspec
  config.order = "random"
  config.include PlaybackHelper
end

describe SD::PlaybackDumper do

  def save_and_load(trans)
    w = writer
    w << trans
    w.flush
    File.exist?(PLAYBACK_FILE).should == true
    r = reader
    r.parse.should == trans
  end

  after :each do
    File.delete(PLAYBACK_FILE)
  end

  it "should be able to write files" do
    writer.flush
    File.exist?(PLAYBACK_FILE).should == true
  end

  it "should be able to save an empty transaction" do
    w = writer
    w << [SD::DiskTransaction.new]
    w.flush
    File.exist?(PLAYBACK_FILE).should == true
  end

  it "should be able to save and load an empty transaction" do
    w = writer
    w << [SD::DiskTransaction.new]
    w.flush
    File.exist?(PLAYBACK_FILE).should == true
    r = reader
    r.parse.should == [SD::DiskTransaction.new]
  end

  it "should be able to save a single transaction" do
    w = writer
    w << [SD::DiskTransaction.new([SD::DiskValue.new("This is the Name", "Group name", 0, "value")])]
    w.flush
    File.exist?(PLAYBACK_FILE).should == true
  end

  it "should be able to save and load an single transaction" do
    w = writer
    trans = [SD::DiskTransaction.new([SD::DiskValue.new("This is the Name", "Group name", 0, "value")])]
    w << trans
    w.flush
    File.exist?(PLAYBACK_FILE).should == true
    r = reader
    r.parse.should == trans
  end

  it "should be able to save and load an single transaction - snl" do
    save_and_load [SD::DiskTransaction.new([SD::DiskValue.new("This is the Name", "Group name", 0, "value")])]
  end


  it "should be able to save and load multiple transactions" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new("This is the Name", "Group name", 0, "value")]),
      SD::DiskTransaction.new([SD::DiskValue.new("Other name", "Different group name", 0, "Moar")])
    ]
  end

  it "should be able to save and load multiple transactions with the same names" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new("name", "Group name", 0, "value")]),
      SD::DiskTransaction.new([SD::DiskValue.new("name", "", 0, "Moar")])
    ]
  end
  it "should be able to save nil group as empty" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new("name", nil, 0, "Moar")])
    ]
  end

  it "should be able to save any group type" do
    save_and_load([0, 1, 2, 10, 50, 100, 127, 128, 129, 200, 255, 256, 500, 512, 513, 0xFFFF].map { |type|
      SD::DiskTransaction.new([SD::DiskValue.new("name", nil, type, "value")])
    })
  end

  it "should be able to save large group names" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new("name", ("long" * 512), 0, "Moar")])
    ]
  end
  it "should be able to save large name names" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new(("long" * 512), nil, 0, "Moar")])
    ]
  end
  it "should be able to save strings and numbers" do
    save_and_load [
      SD::DiskTransaction.new([SD::DiskValue.new("name", nil, 0, "A string")]),
      SD::DiskTransaction.new([SD::DiskValue.new("n2", nil, 0, java.lang.String.new("A string"))]),
      SD::DiskTransaction.new([SD::DiskValue.new("n3", nil, 0, 51)]),
      SD::DiskTransaction.new([SD::DiskValue.new("n4", nil, 0, 52.34)]),
      SD::DiskTransaction.new([SD::DiskValue.new("n5", nil, 0, java.lang.Double.new(76.0))]),
      SD::DiskTransaction.new([SD::DiskValue.new("n6", nil, 0, java.lang.Float.new(76.0))]),
      SD::DiskTransaction.new([SD::DiskValue.new("n7", nil, 0, java.lang.Integer.new(760))]),
    ]
  end

  it "should be able to save booleans and nil" do
    save_and_load [
      SD::DiskTransaction.new([
          SD::DiskValue.new("name", nil, 0, true),
          SD::DiskValue.new("n2", nil, 0, false),
          SD::DiskValue.new("n3", nil, 0, java.lang.Boolean.new(true))]),
      SD::DiskTransaction.new([
          SD::DiskValue.new("n4", nil, 0, java.lang.Boolean.new(false)),
          SD::DiskValue.new("n5", nil, 0, java.lang.Boolean.new(nil)),
          SD::DiskValue.new("n6", nil, 0, nil)]),
    ]
  end

  it "should be able to save arrays" do
    save_and_load [
      SD::DiskTransaction.new([
          SD::DiskValue.new("name", nil, 0, [true, false , "heloo", java.lang.String.new("java!"), java.lang.Boolean.new(true)])]),
      SD::DiskTransaction.new([
          SD::DiskValue.new("n4", nil, 0, [].to_java, String)]),
    ]
  end
end
