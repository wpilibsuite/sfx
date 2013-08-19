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
require 'jrubyfx'

module SD

  class Playback
    include JRubyFX::DSL
    def initialize(data_core, parent_win)
      @core = data_core
      @stage = stage(title: "PlayBack>> Controller") do
        init_owner parent_win
      end
      @core.add_data_filter Java::dashfx.lib.data.endpoints.PlaybackFilter.new.tap{|x| @filter = x}
    end

    def launch
      SD::PlaybackController.load_into @stage, initialize: [@core, @filter]
      @stage.show_and_wait
      @filter.leave_playback
    end
  end

  class PlaybackFormatter < Java::javafx.util.StringConverter
    def initialize(&block)
      @proc = block
    end
    def fromString(str)
      raise str
    end
    def toString(dbl)
      @proc.(dbl)
    end
  end

  class PlaybackController
    include JRubyFX::Controller
    fxml "PlaybackEditor.fxml"

    def initialize(core, filter)
      @core = core
      @scale_value = 1.0
      @playing = nil
      @filter = filter
      @filter.enter_playback
      @slider.max_property.bind @filter.length
      @slider.value_property.bind_bidirectional @filter.pointer
      @slider.label_formatter = PlaybackFormatter.new {|d| core.date_at_index(d).to_s}
      @slider.major_tick_unit = 50 # TODO: dynamic
      @slider.show_tick_labels = true
      @slider.show_tick_marks = true
      @playback_src.items.clear
      @playback_src.items.add_all("Live Data",
        *Dir[File.join(Dir.home, ".smartdashboard-playback", "*.sdfxplbk")].tap{|x| @original_src = x}.map{|x|
          File.basename(x, ".sdfxplbk").gsub(/ ([0-9]{1,2})_([0-9]{2})_([0-9]{2}) ([AP]M)/, ' \1:\2:\3 \4')})
      @playback_src.selection_model.clear_and_select(0)
      @playback_src.selection_model.selected_index_property.add_change_listener do |idx|
        if idx == 0
          #hmm, TODO
        else
          load(@original_src[idx-1])
        end
      end
      @log_scale.value_property.add_change_listener do |new|
        @scale_value = logify(new)
        @speed_lbl.text = "#{"%.1f" % @scale_value}x"
        if @playing
          @filter.stop_the_film
          @filter.play_with_time(@playing/@scale_value)
        end
      end
    end

    logify_generic = ->(min_out, max_out, min_in, max_in, x) do
      Math::E ** (Math.log(min_out) + ((Math.log(max_out)- Math.log(min_out)) / (max_in - min_in)) * (x - min_in))
    end

    define_method(:logify, logify_generic.curry[0.1, 10, 0, 100])

    def step_1
      if @slider.value < @filter.length.get - 1
        @slider.value += 1
      end
    end

    def step_back_1
      if @slider.value > 0
        @slider.value -= 1
      end
    end

    def to_beginning
      @slider.value = 0
    end

    def to_end
      @slider.value = @filter.length.get
    end

    def kill
      @stage.close
    end

    def play
      @playing = 1
      @filter.play_with_time(1/@scale_value)
    end

    def yalp
      @playing = -1
      @filter.play_with_time(-1/@scale_value)
    end

    def stop
      @playing = nil
      @filter.stop_the_film
    end

    def load(file)
      pd = PlaybackDumper.new(file, "r")
      list = pd.parse
      @filter._impl_load(list.map(&:to_data), list.map{|x|x.date.to_java})
    end

    def save
      list, dates = @filter._impl_save
      dates = dates.map{|d|Time.at(d.time/1000.0)}
      list = list.zip(dates).map{|x,d|DiskTransaction.new(x).at(d)}
      timestamp = Time.now.strftime("%F %r -- ")
      dir = File.join(Dir.home, ".smartdashboard-playback")
      Dir.mkdir(dir) unless Dir.exist? dir
      pd = PlaybackDumper.new(File.join(dir, timestamp.gsub(":", "_") + ".sdfxplbk"), "w")
      pd << list
      pd.flush
      @playback_src.items.add(timestamp)
    end

  end
  class PlaybackDumper
    def initialize(filename, rw = "w")
      @file = File.open(filename, "#{rw}b")
      @tmp = []
      @previous = {}
      @lookup_tables = {}
      @rlookup_tables = {}
      @type_table = {}
      @rtype_table = {}
    end
    def <<(save_stream)
      @tmp += save_stream
      if @tmp.length > 20
        flush
      end
    end

    def parse
      read_table
      until @file.eof?
        read_entry
      end
      @tmp
    end

    def flush
      # TODO: sync
      # build table
      f = @file
      f << "f"
      new_values = @tmp.inject([]){|ar, dt| ar + dt.values}
      names = new_values.map(&:name) - @lookup_tables.keys
      f << [names.length].pack("U") # size of index
      from = @lookup_tables.values.max || 0
      names.each do |name|
        @lookup_tables[name] = (from += 1)
        f << [from, name.bytesize].pack("U*")
        f << name
      end
      all_types = @tmp.inject([]){|ar, dt| ar << dt.values.map(&:datat)}.flatten.uniq
      from = @type_table.values.max || 0
      f << [all_types.length].pack("U") # size of index
      all_types.each do |type|
        @type_table[type] = (from += 1)
        f << [from, type.name.bytesize].pack("U*")
        f << type.name
      end
      f << [@previous.length].pack("U")
      @previous.each do |name, value|
        write_transaction_value(name, value)
      end
      f << "\0"
      @tmp.each do |tmp|
        write_transaction(tmp)
      end
      f.flush
    end
    private

    def read_table
      f = @file
      raise "RatbleFale" unless "f" == f.getc
      # read names
      pairs = f.ucode
      pairs.times do
        id = f.ucode
        name = f.read(f.ucode)
        @lookup_tables[name] = id
        @rlookup_tables[id] = name
      end
      # read types
      pairs = f.ucode
      pairs.times do
        id = f.ucode
        name = eval(f.read(f.ucode)) # TODO: use constantize
        @type_table[name] = id
        @rtype_table[id] = name
      end
      # read transactions!
      pairs = f.ucode
      pairs.times do
        read_transaction_value
      end
      rand_bin = f.ucode
      f.read(rand_bin)
    end

    def read_transaction
      f = @file
      raise "Transactionsfail" unless "t" == f.getc
      date = f.read(8).unpack("E")[0]
      n = f.ucode
      @tmp << SD::DiskTransaction.new(n.times.map {read_transaction_value}).at(date)
    end

    def write_transaction(fr)
      f = @file
      f << "t"
      f << [fr.date.to_f].pack("E")
      f << [fr.values.length].pack("U")
      fr.values.each do |k|
        write_transaction_value(k)
      end
    end


    def read_entry
      c = @file.getc
      @file.ungetc(c)
      case c
      when "t" then read_transaction
      when "f" then read_table
      else raise "#{c.inspect} is not known as a entry marker"
      end
    end

    def read_transaction_value
      f = @file
      name = @rlookup_tables[f.ucode]
      real_type = @rtype_table[f.ucode]
      stype = f.ucode
      gname = f.read(f.ucode)
      typeid = f.read(1).ord
      enc, dec = find_codec(typeid)
      SD::DiskValue.new(name, gname, stype, dec.call(f), real_type)
    end

    def write_transaction_value(dv)
      name = dv.name
      gname = dv.group || ""
      value = dv.datav
      real_type = dv.datat
      stype = dv.type || 0
      f = @file
      f << [@lookup_tables[name], @type_table[real_type], stype, gname.length].pack("U*")
      f << gname
      type = value_type(value)
      enc, dec = find_codec(type)
      f << [type].pack("C*")
      enc.call(value, f)
    end

    def self.single_value(val)
      lambda {|f|val}
    end
    def self.packer(format, &block)
      if block_given?
        lambda {|v,f| f << [block.(v)].pack(format)}
      else
        lambda {|v,f| f << [v].pack(format)}
      end
    end
    def self.unpacker(format, clz=nil)
      size = [0].pack(format).length
      lambda do |f|
        up = f.read(size).unpack(format)[0]
        return clz ? clz.new(up) : up
      end
    end

    nothing = lambda {|v,f|}

    # TODO: i'm not sure I like this
    TYPES = {
      NilClass => 0,
      java.lang.Double => 1,
      Float => 2, # actually a java double
      java.lang.Float => 3,
      java.lang.Integer => 4,
      Fixnum => 5,
      java.lang.String => 20,
      String => 21,
      java.lang.Boolean => 22,
      TrueClass => 23,
      FalseClass => 24,
      Array => 50,
      java.lang.Object[] => 51,
    }

    CODECS = {
      # type => encoder, decoder
      0 => [nothing, single_value(nil)],
      1 => [packer("E", &:double_value), unpacker("E", java.lang.Double)],
      2 => [packer("E"), unpacker("E")],
      3 => [packer("e", &:float_value), unpacker("e", java.lang.Float)],
      4 => [packer("S<", &:int_value), unpacker("S<", java.lang.Integer)],
      5 => [packer("S<"), unpacker("S<")],
      # TODO: verify this stringy stuff works correctly
      20 => [lambda{|v,f| f << [v.length].pack("U"); f << v.to_s}, lambda{|f| len = f.ucode; java.lang.String.new(f.read(len))}],
      21 => [lambda{|v,f| f << [v.length].pack("U"); f << v}, lambda{|f| len = f.ucode; f.read(len)}],
      22 => [packer("C"){|v|v.boolean_value ? 1 : 0}, lambda {|f| java.lang.Boolean.new([false, true][f.read(1).unpack("C")[0]])}],
      23 => [nothing, single_value(true)],
      24 => [nothing, single_value(false)],
      50 => [lambda {|v, f|
          f << [v.length].pack("U");
          v.each {|lv|
            type = value_type(lv)
            enc, dec = find_codec(type)
            f << [type].pack("C*")
            enc.call(lv, f)
          }
        }, lambda{|f|
          f.ucode.times.map {
            typeid = f.read(1).ord
            enc, dec = find_codec(typeid)
            dec.call(f)
          }
        }],
      51 => [lambda{|v, f| CODECS[50][0].call(v,f)},lambda{|f| CODECS[50][1].call(f).to_java java.lang.Object}]
    }

    def value_type(v)
      self.class.value_type(v)
    end
    def find_codec(v)
      self.class.find_codec(v)
    end

    def self.value_type(value)
      vt = TYPES[value.class]
      raise "Invalid class #{value.class} from #{value.to_s} (#{value.inspect})" unless vt
      return vt
    end

    def self.find_codec(type)
      cd = CODECS[type]
      raise "Invalid type #{type}" unless cd
      return cd
    end
  end
  class DiskTransaction
    attr_reader :values, :deleted, :date
    def initialize(trans = [], deleted = nil)
      return unless trans
      if deleted or trans.is_a? Array
        @values = trans
        @deleted = []
      else
        @deleted = trans.deleted_names.to_a
        @values = trans.values.map{|x|DiskValue.new(x.name, x.group_name, (x.type && x.type.mask), x.data)}
      end
    end
    def at(date)
      @date = Time.at(date)
      return self
    end
    def ==(rhs)
      if rhs.is_a? self.class
        @values == rhs.values && @deleted == rhs.deleted
      end
    end
    def to_data
      Java::dashfx.lib.data.SimpleTransaction.new(@values.map(&:to_data).to_java(Java::dashfx.lib.data.SmartValue), @deleted.to_java(:String))
    end
  end
  class DiskValue
    attr_reader :name, :group, :type, :datav, :datat
    def initialize(name, group, type, data, datat = data.class)
      @name = name
      @group = group || ""
      @type = type
      @datat = datat
      @datav = if data.respond_to? :export_data
        data.export_data
      elsif data.respond_to? :as_raw
        data.as_raw
      else
        data
      end
    end

    def ==(rhs)
      if rhs.is_a? self.class
        if @name == rhs.name && @group == rhs.group && @type == rhs.type
          @datav == rhs.datav || (@datav.class == java.lang.Object[] && @datav.to_a == rhs.datav.to_a)
        end
      end
    end

    def to_data
      Java::dashfx.lib.data.SmartValue.new(@datat.new(@datav), Java::dashfx.lib.data.SmartValueTypes.values.find{|x| x.mask == @type}, @name, @group)
    end
  end
end

class File
  def ucode
    f = self
    b = (str = f.readchar).ord
    b = (0xFF & (b << 1)) if b > 127
    while b > 127
      str << f.readchar
      b = (0xFF & (b << 1))
    end
    str.force_encoding("utf-8").ord
  end
end
