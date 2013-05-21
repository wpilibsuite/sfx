
module SD::DesignerSupport
  class Overlay < Java::javafx::scene::layout::GridPane
    include JRubyFX::Controller
    include Java::dashfx::data::Registerable
    java_import 'dashfx.controls.ResizeDirections'
    fxml "DesignerOverlayControl.fxml"
    attr_reader :child, :parent_designer
    attr_accessor :editing_nested
    #Observable
    property_accessor :running, :disabled

    DIRECTIONS = {:moveRegion =>[0.0, 0.0, 1.0, 1.0],
      :nwResizeRegion =>[-1.0, -1.0, 1.0, 1.0],
      :nResizeRegion =>[0.0, -1.0, 0.0, 1.0],
      :neResizeRegion =>[1.0, -1.0, 0.0, 1.0],
      :eResizeRegion =>[1.0, 0.0, 0.0, 0.0],
      :seResizeRegion =>[1.0, 1.0, 0.0, 0.0],
      :sResizeRegion =>[0.0, 1.0, 0.0, 0.0],
      :swResizeRegion =>[-1.0, 1.0, 1.0, 0.0],
      :wResizeRegion =>[-1.0, 0.0, 1.0, 0.0]}

    RESIZABILITY_MAPPER = {
      ResizeDirections::Move => [:moveRegion],
      ResizeDirections::UpDown => [:nResizeRegion, :sResizeRegion, :nHandle, :sHandle],
      ResizeDirections::LeftRight => [:eResizeRegion, :eResizeRegion, :eHandle, :wHandle],
      ResizeDirections::SouthEastNorthWest => [:nwResizeRegion, :seResizeRegion],
      ResizeDirections::NorthEastSouthWest => [:neResizeRegion, :swResizeRegion],
    }

    def initialize(child, parent)
      @child = child
      @childContainer.setCenter(child.getUi);
      @parent_designer = parent
      @drag_action = nil
      @selected = false
      #
      @selected_ui.opacity = 0
      @running = SimpleBooleanProperty.new(false)
      @disabled = SimpleBooleanProperty.new(false)
      # TODO: intercept events
      @selected_ui.visibleProperty.bind(@running.or(@disabled).not)
      @editing_nested = false
    end

    def registered(prov)
      sops = get_parent.getSupportedOps

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
        parent.continue_dragging(e.scene_x - @drag_action[0], e.scene_y - @drag_action[1])
      elsif @supported_ops.include? e.target.id.to_sym
        nodes = [self]
        if original && (e.control_down? || @parent_designer.multiple_selected?)
          nodes += @parent_designer.multi_drag(self)
        end
        @drag_action = [e.scene_x, e.scene_y]
        parent.begin_dragging(nodes, nodes.map{|n| n.instance_variable_get(:@childContainer)}, e.scene_x, e.scene_y, *DIRECTIONS[e.target.id.to_sym])
      end
      e.consume
    end

    def properties
      # ahh! must get stuff....
      props = []
      jc = child.java_class
      [jc, *jc.java_instance_methods].each do |src|
        src.annotations.each do |annote|
          if annote.is_a? Java::dashfx.controls.Designable and src != jc
            props << [src.invoke(child), annote] # TODO: real class
          elsif annote.is_a? Java::dashfx.controls.DesignableProperty
            annote.value.length.times do |i|
              props << [child.method(annote.value[i] + "Property").call, RDesignableProperty.new(annote.value[i], annote.descriptions[i])]
            end
          end
        end
      end
      return props
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
        parent.finish_dragging
      end
      @drag_action = nil
    end
    #
    def onClick(e)
      # ctx menu goes here
    end

    def exit_nesting
      # TODO: we should not need to test running
      @editing_nested = false
      self.running = false
    end

    def checkDblClick(e)
      if e.click_count > 1
        @parent_designer.nested_edit(self)
        # enable nested mode!

        @editing_nested = true
        self.running = true
        # TODO: disable!
        e.consume
      end
    end
    #    add_method_signature :onClick, [Void::TYPE, MouseEvent]
    def inspect
      "#<DesignerOverlay:0x#{object_id.to_s(16)} @selected=#{selected.inspect} @running=#{running.inspect} @editing_nested=#{editing_nested.inspect} @child=#{child.inspect}>"
    end

    def request_ctx_menu(e)
      @context_menu.show(@selected_ui, e.screen_x, e.screen_y)
    end

    def z_send_backward
      self.parent.z_edit(self, Java::dashfx.data.ZPositions::Down)
    end
    def z_send_bottom
      self.parent.z_edit(self, Java::dashfx.data.ZPositions::Bottom)
    end
    def z_send_forward
      self.parent.z_edit(self, Java::dashfx.data.ZPositions::Up)
    end
    def z_send_top
      self.parent.z_edit(self, Java::dashfx.data.ZPositions::Top)
    end
  end
end

RDesignableProperty = Struct.new("RDesignableProperty", :value, :description)

SD::DesignerSupport::Overlay.become_java!
