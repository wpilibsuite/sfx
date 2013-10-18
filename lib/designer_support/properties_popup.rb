
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
      @allprops = props.sort{|a, b|
        if a.category == b.category
          a.name <=> b.name
        elsif a.category == "Basic"
          -1
        elsif b.category == "Basic"
          1
        else
          a.category <=> b.category
        end
      }
      bits = props.find_all{|x|x.category == "Basic"}
      if bits.length == 0
        bits = props.find_all{|x|x.category == "General"}
        bits = props if bits.length == 0
      end
      bits.each do |prop|
        with(@prop_list) do
          children.add label!(prop.name + ": ", tooltip: tooltip!(prop.description))
          children.add SD::Designers.get_for(prop.type).tap{|x|x.design(prop)}.ui
        end
      end
      if bits != props
        expando = button("V More V")
        expando.set_on_action do
          show_all
        end
        @prop_list.children.add expando
      end
    end

    def show_all
      @prop_list.children.clear
      lastType = ""
      @allprops.each do |prop|
        if lastType != prop.category
          @prop_list.children.add label(lastType = prop.category) {
            self.font = font!("System Bold", 14)
            SD::Utils::TitledFormPane.setExpand(self, true)
          }
        end
        with(@prop_list) do
          children.add label!(prop.name + ": ", tooltip: tooltip!(prop.description))
          children.add SD::Designers.get_for(prop.type).tap{|x|x.design(prop)}.ui
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
