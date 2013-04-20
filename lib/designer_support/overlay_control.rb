
module SD::DesignerSupport
  class Overlay < Java::javafx::scene::layout::GridPane
    include JRubyFX::Controller
    include Java::dashfx::data::Registerable
    fxml_root "../res/DesignerOverlayControl.fxml"
    attr_reader :child, :parent_designer

    DIRECTIONS = {:moveRegion =>[0.0, 0.0, 1.0, 1.0],
      :nwResizeRegion =>[-1.0, -1.0, 1.0, 1.0],
      :nResizeRegion =>[0.0, -1.0, 0.0, 1.0],
      :neResizeRegion =>[1.0, -1.0, 0.0, 1.0],
      :eResizeRegion =>[1.0, 0.0, 0.0, 0.0],
      :seResizeRegion =>[1.0, 1.0, 0.0, 0.0],
      :sResizeRegion =>[0.0, 1.0, 0.0, 0.0],
      :swResizeRegion =>[-1.0, 1.0, 1.0, 0.0],
      :wResizeRegion =>[-1.0, 0.0, 1.0, 0.0]}

    def initialize(child, parent)
      @child = child;
      @childContainer.setCenter(child);
      @parent_designer = parent
      @drag_action = nil
      @selected = false
      #
      @selected_ui.opacity = 0
      @running = SimpleBooleanProperty.new(false)
      @selected_ui.visibleProperty.bind(@running.not)
    end

    def registered(prov)
      @child.registered(prov)
    end

    def dragUpdate(e, original = true)
      if @drag_action
        parent.continue_dragging(e.scene_x - @drag_action[0], e.scene_y - @drag_action[1])
      else
        nodes = [self]
        if original && (e.control_down? || @parent_designer.multiple_selected?)
          nodes += @parent_designer.multi_drag(self)
        end
        @drag_action = [e.scene_x, e.scene_y]
        parent.begin_dragging(nodes, nodes.map{|n| n.instance_variable_get(:@childContainer)}, e.scene_x, e.scene_y, *DIRECTIONS[e.target.id.to_sym])
      end
    end

    def properties
      # ahh! must get stuff....
      props = []
      jc = child.java_class
      [jc, *jc.declared_instance_methods].each do |src|
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

    def running
      @running.value
    end

    def running=(run)
      @running.value = run
    end

    on_mouse :dragDone do
      if @drag_action
        parent.finish_dragging
      end
      @drag_action = nil
    end
    #
    def onClick(e)
      # ctx menu goes here
    end
    #    add_method_signature :onClick, [Void::TYPE, MouseEvent]
  end
end

RDesignableProperty = Struct.new("RDesignableProperty", :value, :description)

SD::DesignerSupport::Overlay.become_java!