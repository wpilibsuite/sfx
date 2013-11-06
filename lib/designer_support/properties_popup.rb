
module SD::DesignerSupport
  class PropertiesPopup < Java::javafx::stage::Popup
    def initialize
      super()
      content.add(@ppane = PropertiesPane.new(self))
      self.hide_on_escape = true
    end

    def properties=(props)
      @ppane.properties = props
    end
    def title=(props)
      @ppane.title = props
    end
    def decor_manager=(dm)
      @ppane.decor_manager = dm
    end
    def focus_default?
      scene.focus_owner == @ppane.raw_title
    end
    def focus_default!
      @ppane.raw_title.request_focus
    end
  end
  class PropertiesPane < Java::javafx::scene::layout::BorderPane
    include JRubyFX::Controller
    fxml "PropertiesPopup.fxml"

    def initialize(parent)
      @popup = parent
    end

    def decor_manager=(dm)
      # TODO: evaluate better ways to do this
      @dm = dm
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
        expando = button("More")
        expando.set_on_action do
          show_all
        end
        SD::Utils::TitledFormPane.setExpand(expando, true)
        expando.alignment = Pos::CENTER
        GridPane.setHalignment(expando, HPos::CENTER)
        @prop_list.children.add expando
      else
        show_decorators
      end
    end

    def show_all
      @prop_list.children.clear
      lastType = ""
      @allprops.each do |prop|
        if lastType != prop.category
          add_title(lastType = prop.category)
        end
        show_prop(prop)
      end
      show_decorators
    end

    def add_title(value)
      @prop_list.children.add label(value) {
        self.font = font!("System Bold", 14)
        SD::Utils::TitledFormPane.setExpand(self, true)
      }
    end
    def show_prop(prop)
      @prop_list.children.add label!(prop.name + ": ", tooltip: tooltip!(prop.description))
      @prop_list.children.add SD::Designers.get_for(prop.type).tap{|x|x.design(prop)}.ui
    end

    def show_decorators
      # add the decorators with a header for each
      add_title("Decorators")
      dmprops = @dm.properties
      dmprops.each do |name, keys|
        btn = nil
        @prop_list.children.add hbox {
          label(name, max_height: 1e308, max_width: 1e308) {
            HBox.setHgrow(self, Java::javafx::scene::layout::Priority::ALWAYS)
            self.font = font!("System Bold", 14)
          }
          btn = button("X", max_height: 1e308, text_fill: Java::javafx::scene::paint::Color::RED)
          SD::Utils::TitledFormPane.setExpand(self, true)
        }
        btn.set_on_action do
          @dm.remove(name)
        end
        keys.each do |prop|
          show_prop(prop)
        end
      end
      # add the "add button" if we can
      bits = SD::Plugins.decorators - @dm.decorator_types
      return if bits.length < 1
      expando = menu_button("Add Decorator")
      bits.each do |clzz|
        clz = clzz.ruby_class.java_class
        desc = clz.annotation(Java::dashfx.lib.controls.Designable.java_class)
        mi = menu_item(desc.value)
        # TODO: install tooltips
        mi.set_on_action do
          @dm.add(clz)
          show_all
        end
        expando.items.add mi
      end
      SD::Utils::TitledFormPane.setExpand(expando, true)
      expando.alignment = Pos::CENTER
      GridPane.setHalignment(expando, HPos::CENTER)
      @prop_list.children.add expando
    end

    def title=(props)
      @title.text = props
    end
    def raw_title
      @title
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
