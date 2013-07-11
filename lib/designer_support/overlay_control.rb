
module SD::DesignerSupport
  class Overlay < Java::javafx::scene::layout::GridPane
    include JRubyFX::Controller
    include Java::dashfx::lib::controls::Control
    java_import 'dashfx.lib.controls.ResizeDirections'
    fxml "DesignerOverlayControl.fxml"
    attr_reader :child, :parent_designer, :original_name
    attr_accessor :editing_nested
    #Observable
    property_accessor :running, :disabled

    DIRECTIONS = {
      :moveRegion =>[0.0, 0.0, 1.0, 1.0],
      :nwResizeRegion =>[-1.0, -1.0, 1.0, 1.0],
      :nResizeRegion =>[0.0, -1.0, 0.0, 1.0],
      :neResizeRegion =>[1.0, -1.0, 0.0, 1.0],
      :eResizeRegion =>[1.0, 0.0, 0.0, 0.0],
      :seResizeRegion =>[1.0, 1.0, 0.0, 0.0],
      :sResizeRegion =>[0.0, 1.0, 0.0, 0.0],
      :swResizeRegion =>[-1.0, 1.0, 1.0, 0.0],
      :wResizeRegion =>[-1.0, 0.0, 1.0, 0.0],
    }

    RESIZABILITY_MAPPER = {
      ResizeDirections::Move => [:moveRegion],
      ResizeDirections::UpDown => [:nResizeRegion, :sResizeRegion, :nHandle, :sHandle],
      ResizeDirections::LeftRight => [:eResizeRegion, :wResizeRegion, :eHandle, :wHandle],
      ResizeDirections::SouthEastNorthWest => [:nwResizeRegion, :seResizeRegion],
      ResizeDirections::NorthEastSouthWest => [:neResizeRegion, :swResizeRegion],
    }

    def initialize(child, parent_designer, parent, ctrl_info)
      @child = child
      @childContainer.setCenter(child.getUi);
      @parent_designer = parent_designer
      @parent = parent
      @drag_action = nil
      @selected = false
      #
      @selected_ui.opacity = 0
      @running = SimpleBooleanProperty.new(false)
      @running.bind(parent_designer.running_property)
      @disabled = SimpleBooleanProperty.new(false)
      # TODO: intercept events
      @selected_ui.visibleProperty.bind(@running.or(@disabled).not)
      @editing_nested = false
      @ctrl_info = ctrl_info
      @original_name = ctrl_info.id
    end

    def registered(prov)
      sops = @parent.getSupportedOps
      @supported_ops = RESIZABILITY_MAPPER.map do |key, cor|
        if sops.contains(key)
          cor
        else
          cor.each {|c| self.instance_variable_get("@#{c}").opacity = 0}
          []
        end
      end.flatten
      @child.registered(prov)
    end

    def dragUpdate(e, original = true)
      return if @editing_nested # TODO: something is wrong here...
      if @drag_action
        @parent.continue_dragging(e.scene_x - @drag_action[0], e.scene_y - @drag_action[1])
      elsif @supported_ops.include? e.target.id.to_sym
        nodes = [self]
        if original && (e.control_down? || @parent_designer.multiple_selected?)
          nodes += @parent_designer.multi_drag(self)
        end
        @drag_action = [e.scene_x, e.scene_y]
        @parent_designer.properties_draghide()
        @parent.begin_dragging(nodes, nodes.map{|n| n.instance_variable_get(:@childContainer)}, e.scene_x, e.scene_y, *DIRECTIONS[e.target.id.to_sym])
      end
      e.consume
    end

    # get all the properties
    def properties
      # ahh! must get stuff....
      props = []
      jc = child.java_class
      pc = @parent.java_class
      [jc, *jc.java_instance_methods, pc, *pc.java_class_methods].each do |src|
        src.annotations.each do |annote|
          if annote.is_a? Java::dashfx.lib.controls.Designable and src != jc and src != pc
            q = src.invoke(child).to_java
            # TODO: proper types
            # TODO: fake properties for PC
            camel = src.name.gsub(/^(get|set)/, '').gsub(/Property$/, '')
            type = jc.java_method("get" + camel.gsub(/^([a-z])/){|x|x.upcase}).return_type
            props << SD::DesignerSupport::Property.new(camel, annote.value, annote.description, type, q, child, src) if q.is_a? Java::JavafxBeansValue::WritableValue
          elsif annote.is_a? Java::dashfx.lib.controls.DesignableProperty and src != pc
            annote.value.length.times do |i|
              prop_name = annote.value[i] + "Property"
              meth = child.respond_to?(prop_name) ? child.method(prop_name) : child.ui.method(prop_name)
              get_name = "get" + (annote.value[i].gsub(/^([a-z])/){|x|x.upcase})
              type = child.respond_to?(get_name) ? child.java_method(get_name) : child.ui.java_method(get_name)
              # TODO: this is absurd, sometimes it fails to find the method
              if type.name == :"()"
                type = child.respond_to?(get_name) ? child.java_class.java_instance_methods.find{|x|x.name==get_name} :
                  child.ui.java_class.java_instance_methods.find{|x|x.name==get_name}
              end
              type_method = type
              type = type.return_type
              props << SD::DesignerSupport::Property.new(annote.value[i], annote.value[i], annote.descriptions[i], type, meth.call, child, type_method)
            end
          elsif annote.is_a? Java::dashfx.lib.controls.DesignableChildProperty and src == pc
            annote.property.length.times do |i|
              # TODO: proper typing
              q = simple_object_property()
              q.value = @parent.class.send("get#{annote.property[i]}", self)
              q.add_change_listener do |new|
                @parent.class.send "set#{annote.property[i]}", self, new
              end
              type_method = pc.java_class_methods.find{|x|x.name == "get#{annote.property[i]}"}
              type = type_method.return_type
              props << SD::DesignerSupport::Property.new(annote.property[i], annote.name[i], annote.description[i], type, q, @parent, type_method)
            end
          end
        end
      end
      if child.respond_to? :custom and child.custom
        child.custom.all_methods.each do |mname|
          props << child.custom.property_for(mname)
        end
      end
      props.each{|x|x.related_props = props}
      return props
    end

    def prop_names
      props = []
      jc = child.java_class
      [jc, *jc.java_instance_methods].each do |src|
        src.annotations.each do |annote|
          if annote.is_a? Java::dashfx.lib.controls.Designable and src != jc
            q = src.invoke(child).to_java
            props << [q, "set" + src.name.gsub(/^(get|set)/, '').gsub(/Property$/, '').gsub(/^([a-z])/){|x|x.upcase}] if q.is_a? Java::JavafxBeansValue::WritableValue # TODO: real class
          elsif annote.is_a? Java::dashfx.lib.controls.DesignableProperty
            annote.value.length.times do |i|
              prop_name = annote.value[i] + "Property"
              meth = child.respond_to?(prop_name) ? child.method(prop_name) : child.ui.method(prop_name)
              set_name = "set" + (annote.value[i].gsub(/^([a-z])/){|x|x.upcase})
              props << [meth.call, set_name]
            end
          end
        end
      end
      return props
    end

    # Used for YAML export
    def export_props
      # TODO: COlors and complex classes won't work like this
      Hash[prop_names.map{|x|[x[1].gsub(/^set/, ""),
            if x[0].value.is_a? java.lang.Enum
              SD::IOSupport::EnumObject.new(x[0].value)
            else
              x[0].value
            end]}]
    end
    def export_static_props
      Hash[%w{LayoutX LayoutY}.map {|prop| [prop, send("get#{prop}")] } +
          %w{Width Height}.map {|prop| [prop, child.ui.send("get#{prop}")] }]
    end

    def selected
      @selected
    end

    def selected=(value)
      @selected =  value
      @selected_ui.opacity = value ? 1 : 0
    end

    on :dragDone do |e|
      if @drag_action
        @parent.finish_dragging
        @parent_designer.properties_dragshow(self)
      end
      @drag_action = nil
    end

    def getUI
      self
    end

    def onClick(e)
      # ?
    end

    def exit_nesting
      # TODO: we should not need to test running
      @editing_nested = false
      self.running = false
    end

    def pane?
      child.is_a?(Java::dashfx.lib.controls.DesignablePane)
    end

    def save_children?
      pane? and @ctrl_info.save_children
    end

    def can_nest?
      pane? and !@ctrl_info.sealed
    end

    def checkDblClick(e)
      if e.click_count > 1 && pane?
        @parent_designer.nested_edit(self)
        # enable nested mode!

        @editing_nested = true
        self.running = true
        # TODO: disable!
        e.consume
      end
    end

    def inspect
      return "nill designer" unless @running # TODO: don't call inspect in fxmlloader
      "#<DesignerOverlay:0x#{object_id.to_s(16)} @selected=#{selected.inspect} @running=#{running.inspect} @editing_nested=#{editing_nested.inspect} @child=#{child.inspect}>"
    end

    def request_ctx_menu(e)
      @context_menu.show(@selected_ui, e.screen_x, e.screen_y)
    end

    # Z ordering requests
    def z_send_backward
      @parent.z_edit(self, Java::dashfx.lib.data.ZPositions::Down)
    end
    def z_send_bottom
      @parent.z_edit(self, Java::dashfx.lib.data.ZPositions::Bottom)
    end
    def z_send_forward
      @parent.z_edit(self, Java::dashfx.lib.data.ZPositions::Up)
    end
    def z_send_top
      @parent.z_edit(self, Java::dashfx.lib.data.ZPositions::Top)
    end

    def morph_into(e)
      @parent_designer.morph_child(self, e) do |new, i|
        prop_names.each do |(prop, set_name)|
          new.method(set_name).call(prop.get) if new.respond_to? set_name rescue nil # property is invalid/different type
        end
        @child = new
        @childContainer.center = new.get_ui
        @ctrl_info = i
        @original_name = i.name
      end
    end

    def delete
      @parent_designer.tap do |pd|
        pd.select(self)
        pd.delete_selected
      end
    end
  end
end

RDesignableProperty = Struct.new("RDesignableProperty", :value, :description)

SD::DesignerSupport::Overlay.become_java!
