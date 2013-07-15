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
        generic_init(url_resolver, info)
        @sealed = info['Sealed'] || false
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

      def generic_init(url_resolver, info)
        @name = info['Name'] if info['Name']
        @description = info['Description'] if info['Description']
        @category = info['Category'] if info['Category']
        @save_children = info['Save Children'] if info['Save Children']
        @types = [*info["Types"], *info["Supported Types"]].map{|x|Java::dashfx.lib.data.SmartValueTypes.valueOf(x).mask} unless @types
        @group_types = info["Group Type"] if info["Group Type"]
        unless @image_proc
          oi = info['Image']
          @image_proc = lambda do
            if oi and oi.length > 0
              url_resolver.(oi).open_stream
            else
              nil
            end
          end
        end
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
      attr_writer :name, :description, :category, :group_types, :types, :new, :image_proc, :save_children, :sealed
    end

    class JavaControlInfo < ControlInfo
      def initialize(loader, jclass, moar_info={})
        annote = jclass.annotation(Java::dashfx.lib.controls.Designable.java_class)
        cat_annote = jclass.annotation(Java::dashfx.lib.controls.Category.java_class)
        types_annote = jclass.annotation(Java::dashfx.lib.data.SupportedTypes.java_class)
        oi = annote.image
        self.name = annote.value
        self.description = annote.description
        if oi and oi.length > 0
          self.image_proc = Proc.new do
            jclass.ruby_class.java_class.resource_as_stream(oi)
          end
        end
        self.category = cat_annote.value if cat_annote
        self.types = if types_annote
          types_annote.value.map{|x|x.mask}
        else
          nil
        end
        self.new = lambda { jclass.ruby_class.new }

        generic_init(loader, moar_info)
      end
    end

    class RubyControlInfo < ControlInfo
      def initialize(loader, info)
        info = Hash[info.map{|k,v| [k.to_s, v]}]
        generic_init(loader, info)
        self.sealed = true
        require java.io.File.new(loader.(info["Source"]).to_uri).to_s # TODO: embedded jars
        @clz = constantize(info["Class"])
      end

      def new
        @clz.new
      end

      # steal handy methods from activesupport
      # Tries to find a constant with the name specified in the argument string.
      #
      # 'Module'.constantize # => Module
      # 'Test::Unit'.constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter
      # whether it starts with "::" or not. No lexical context is taken into
      # account:
      #
      # C = 'outside'
      # module M
      # C = 'inside'
      # C # => 'inside'
      # 'C'.constantize # => 'outside', same as ::C
      # end
      #
      # NameError is raised when the name is not in CamelCase or the constant is
      # unknown.
      def constantize(camel_cased_word)
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        names.inject(Object) do |constant, name|
          if constant == Object
            constant.const_get(name)
          else
            candidate = constant.const_get(name)
            next candidate if constant.const_defined?(name, false)
            next candidate unless Object.const_defined?(name)

            # Go down the ancestors to check it it's owned
            # directly before we reach Object or the end of ancestors.
            constant = constant.ancestors.inject do |const, ancestor|
              break const if ancestor == Object
              break ancestor if ancestor.const_defined?(name, false)
              const
            end

            # owner is in Object, so raise
            constant.const_get(name, false)
          end
        end
      end

      # Tries to find a constant with the name specified in the argument string.
      #
      # 'Module'.safe_constantize # => Module
      # 'Test::Unit'.safe_constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter
      # whether it starts with "::" or not. No lexical context is taken into
      # account:
      #
      # C = 'outside'
      # module M
      # C = 'inside'
      # C # => 'inside'
      # 'C'.safe_constantize # => 'outside', same as ::C
      # end
      #
      # +nil+ is returned when the name is not in CamelCase or the constant (or
      # part of it) is unknown.
      #
      # 'blargle'.safe_constantize # => nil
      # 'UnknownModule'.safe_constantize # => nil
      # 'UnknownModule::Foo::Bar'.safe_constantize # => nil
      def safe_constantize(camel_cased_word)
        constantize(camel_cased_word)
      rescue NameError => e
        raise unless e.message =~ /(uninitialized constant|wrong constant name) #{const_regexp(camel_cased_word)}$/ ||
          e.name.to_s == camel_cased_word.to_s
      rescue ArgumentError => e
        raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
      end
    end
  end
end
