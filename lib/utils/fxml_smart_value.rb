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

module SD
  module Utils
    class FxmlSmartValue
      def initialize(sv)
        @sv = sv
        @cached = {}
        #        unless @sv.empty?
        #          if @sv.hash?
        #            omap = @sv.as_hash
        #            _redefine(omap)
        #          end
        #        end
      end

      def _redefine(omap)
        cached = @cached
        omap.each do |key, sv|
          singleton_class.send :define_method, key do
            puts "doing #{key}."
            cached[key] = FxmlSmartValue.new(sv) unless cached.has_key? key
            cached[key]
          end
          singleton_class.send :define_method, "#{key}Property" do
            puts "doing #{key}Property"
            cached[key] = FxmlSmartValue.new(sv) unless cached.has_key? key
            cached[key].raw_sv
          end
        end
      end

      def [](x)
        if @sv.array?
          @sv.as_array[x]
        else
          nil
        end
      end

      def method_missing(name, *args)
        puts "mming #{name} with ", args.inspect
        name = name.to_s
        if name.end_with? "Property"
          name = name[0..-9]
          if @cached.has_key?(name)
            puts 58
            @cached[name].raw_sv
          elsif @sv.hash? and @sv.as_hash.has_key?(name)
            puts 62
            (@cached[name] = FxmlSmartValue.new(@sv.as_hash[name])).raw_sv
          else
            puts "supering prop"
            super
          end
        else
          if @cached.has_key?(name)
            puts 70
            @cached[name]
          elsif @sv.hash? and @sv.as_hash.has_key?(name)
            puts "73"
            @cached[name] = FxmlSmartValue.new(@sv.as_hash[name])
          else
            puts "supering non"
            super
          end
        end
      end

      def to_raw
        @sv.value || false
      end

      def raw_sv
        @sv
      end
    end
  end
end

class RubyDhb < Java::dashfx.controls.DataHBox

  def initialize
    super
  end

  def registered
    smartBaseProperty.setValue(SD::Utils::FxmlSmartValue.new(getObservable("")))
  end

  def getSmartBase
    puts "called getSM"
    puts "we have #{smartBaseProperty.value}"
    smartBaseProperty.value || false
  end
  def smartBaseProperty
    puts "called property"
    unless @sbp
      @sbp = Java::javafx.beans.property.SimpleObjectProperty.new(self, "smartBase")
      @sbp.setValue(SD::Utils::FxmlSmartValue.new(getObservable("")))
    end
    if @sbp.value && @sbp.value.raw_sv != getObservable("")
      @sbp.setValue(SD::Utils::FxmlSmartValue.new(getObservable("")))
    end
    @sbp
  end
  def smartBaseGetType
    puts "called getType"
    java.lang.Object
  end
end