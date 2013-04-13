
module SD::DesignerSupport
  class Overlay < Java::javafx::scene::layout::GridPane
    include JRubyFX::Controller
    fxml_root "../res/DesignerOverlayControl.fxml"
    attr_reader :child

    DIRECTIONS = {:moveRegion =>[0.0, 0.0, 1.0, 1.0],
      :nwResizeRegion =>[-1.0, -1.0, 1.0, 1.0],
      :nResizeRegion =>[0.0, -1.0, 0.0, 1.0],
      :neResizeRegion =>[1.0, -1.0, 0.0, 1.0],
      :eResizeRegion =>[1.0, 0.0, 0.0, 0.0],
      :seResizeRegion =>[1.0, 1.0, 0.0, 0.0],
      :sResizeRegion =>[0.0, 1.0, 0.0, 0.0],
      :swResizeRegion =>[-1.0, 1.0, 1.0, 0.0],
      :wResizeRegion =>[-1.0, 0.0, 1.0, 0.0]}

    def initialize(child)
      @child = child;
      @childContainer.setCenter(child);
      @drag_action = nil
      @selected = false #SimpleBooleanProperty.new(false)
      #@selected_ui.visibleProperty.bind(@selected)
    end

    def begin_drag_pos(sizeX, sizeY, posX, posY, e)
			{:sizeX => sizeX,
        :sizeY => sizeY,
        :pos_x => posX,
        :pos_y => posY,
        :lastDragX => e.scene_x,
        :lastDragY => e.scene_y,
        :last_size_x => @childContainer.width,
        :last_size_y => @childContainer.height,
        :last_pos_x => layout_x,
        :last_pos_y => layout_y}
    end

    def update_drag_action(hist, e)
			diff_x = e.scene_x - hist[:lastDragX]
			diff_y = e.scene_y - hist[:lastDragY]
			setLayoutX(hist[:last_pos_x] + diff_x * hist[:pos_x])
			setLayoutY(hist[:last_pos_y] + diff_y * hist[:pos_y])
			@childContainer.setPrefSize(hist[:last_size_x] + diff_x * hist[:sizeX], hist[:last_size_y] + diff_y * hist[:sizeY])
    end

    def dragUpdate(e)
      if @drag_action
        update_drag_action(@drag_action, e)
      else
        @drag_action = begin_drag_pos(*[DIRECTIONS[e.target.id.to_sym], e].flatten)
      end
    end

    def properties
      # ahh! must get stuff....
      props = []
      jc = child.java_class
      [jc, *jc.declared_instance_methods].each do |src|
        src.annotations.each do |annote|
          if annote.is_a? Java::dashfx.controls.Designable and src != jc
            props << [src, annote] # TODO: real class
          elsif annote.is_a? Java::dashfx.controls.DesignableProperty
            annote.value.length.times do |i|
              props << [src, RDesignableProperty.new(annote.value[i], annote.descriptions[i])]
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

    on_mouse :dragDone do
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