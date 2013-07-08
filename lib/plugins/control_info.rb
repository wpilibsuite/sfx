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
  module Plugins
    class ControlInfo
      attr_reader :name, :description, :category, :group_types, :types, :save_children, :sealed
      def initialize(url_resolver, info)
        info = Hash[info.map{|k,v| [k.to_s, v]}]
        if info['From Package'] || info['From Class'] || info['From Jar']
          # TODO: ?
        end
        @name = info['Name']
        @description = info['Description']
        @category = info['Category']
        @sealed = info['Sealed'] || false
        oi = info['Image']
        @save_children = info['Save Children']
        @image_proc = lambda do
          if oi and oi.length > 0
            url_resolver.(oi).open_stream
          else
            nil
          end
        end
        @types = [*info["Types"], *info["Supported Types"]].map{|x|Java::dashfx.lib.data.SmartValueTypes.valueOf(x).mask}
        @group_types = info["Group Type"]
        @new = lambda { |source, placeholders, pholder_override, defaults,custom_props|
          lambda {
            fx = FxmlLoader.new
            fx.location = url_resolver.(source)
            fx.controller = SD::DesignerSupport::PlaceholderFixer.new(*placeholders) if placeholders
            opts = {jit: :no_jit}
            if custom_props
              opts[:on_root_set] = lambda { |root|
                root.setCustomPropObject(SD::Plugins::CustomPropertyClass.new(custom_props))
              }
            end
            if placeholders
              opts[:jit] = :no_jit
            end
            fx.load(jruby_ext: opts).tap do |obj|
              if placeholders
                objs = fx.controller.fix(obj, pholder_override)
                if [*defaults].any? {|k, v| k.include? "."}
                  nested, defaults = defaults.partition{|k, v| k.include? "."}
                  nested.each do |k, v|
                    name, prop = k.split(".")
                    objs[name].send(prop + "=", v)
                  end
                end
              end
              [*defaults].each do |k, v|
                obj.send(k + "=", v)
              end
            end
          }
        }.(info["Source"],info["Placeholders"],info["Placeholder Override"] ||{},info["Defaults"], info["Custom Properties"])
      end

      def new
        @new.call
      end

      def image_stream
        @image_proc.call
      end

      def self.find(desc)
        SD::Plugins.control(desc)
      end

      def id
        @name
      end

      def to_s
        @name
      end

      protected
      attr_writer :name, :description, :category, :group_types, :types, :new, :image_proc, :save_children
    end

    class JavaControlInfo < ControlInfo
      def initialize(jclass, moar_info={})
        annote = jclass.annotation(Java::dashfx.lib.controls.Designable.java_class)
        cat_annote = jclass.annotation(Java::dashfx.lib.controls.Category.java_class)
        types_annote = jclass.annotation(Java::dashfx.lib.data.SupportedTypes.java_class)
        oi = annote.image
        self.name = annote.value
        self.description = annote.description
        self.image_proc = Proc.new do
          if oi and oi.length > 0
            jclass.ruby_class.java_class.resource_as_stream(oi)
          else
            nil
          end
        end
        self.category = cat_annote.value if cat_annote
        self.types = if types_annote
          types_annote.value.map{|x|x.mask}
        else
          []
        end
        self.new = lambda { jclass.ruby_class.new }
        self.group_types = moar_info["Group Type"] # TODO: this is not very good... should be cleaner
        self.save_children = moar_info['Save Children']
      end
    end
  end
end
