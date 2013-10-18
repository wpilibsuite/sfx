
module SD::DesignerSupport
  class PropertiesPopup < Java::javafx::stage::Popup
    def initialize
      super()
      content.add(PropertiesPane.new self)
      self.hide_on_escape = true
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
    end


    def properties=(props)
      @prop_list.children.clear
      @prop_list.children.add label("General") {
        self.font = font!("System Bold", 14)
        SD::Utils::TitledFormPane.setExpand(self, true)
      }
      col = 0
      # TODO: sort in wrong now with titles
      props.sort{|a, b| a.name <=> b.name}.each do |prop|
        with(@prop_list) do
          children.add label!(prop.name + ": ", tooltip: tooltip!(prop.description))
          children.add SD::Designers.get_for(prop.type).tap{|x|x.design(prop)}.ui
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
