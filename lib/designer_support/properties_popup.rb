
module SD::DesignerSupport
  class PropertiesPopup < Java::javafx::stage::Popup
    def initialize
      super()
      content.add(PropertiesPane.new self)
    end

    def properties=(props)
      content[0].properties = props
    end
    def title=(props)
      content[0].title = props
    end
  end
  class PropertiesPane < Java::javafx::scene::layout::BorderPane
    include JRubyFX::Controller
    fxml "PropertiesPopup.fxml"

    def initialize(parent)
      @popup = parent
      #      @label.text = label
      #      @label.setTooltip tooltip(label)
    end


    def properties=(props)
      @prop_list.children.clear
      @prop_list.row_constraints.clear
      @prop_list.row_constraints.add_all (0...props.length).map{row_constraints(vgrow: :sometimes)}
      @prop_list.row_constraints.add row_constraints(vgrow: :always)
      col = 0
      props.each do |prop|
        with(@prop_list) do
          add label!(prop[1].value + ": ", tooltip: tooltip!(prop[1].description)), 0, col
          add Java::dashfx.lib.designers.Designers.getFor(prop[2]).tap{|x|x.design(prop[0])}.getUiBits, 1, col
          col += 1
        end
      end
    end

    def title=(props)
      @title.text = props
    end
    def move(e)
      if @drag_info
        @popup.x = @drag_info[:original_x]+ (e.screen_x - @drag_info[:m_x])
        @popup.y = @drag_info[:original_y]+ (e.screen_y - @drag_info[:m_y])
      end
    end
    def begin_move(e)
      @drag_info = {
        original_x: @popup.x,
        original_y: @popup.y,
        m_x: e.screen_x,
        m_y: e.screen_y
      }
    end

    def finish_move
      @drag_info = nil
    end

    def close
      @popup.hide
    end
  end
end
