require 'jrubyfx'
require 'designer_support/toolbox_item'
require 'designer_support/overlay_control'
require 'designer_support/properties_popup'
require 'designer_support/aa_tree_cell'
require 'designer_support/toolbox_popup'
require 'playback'

class SD::Designer
  include JRubyFX::Controller

  fxml_root "res/SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @TooboxTabs
    @selected_items = []
    @dnd_ids = []
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    puts @add_tab.id, "is addtab"
    @add_tab.id = "AddTab" # TODO: hack. FIXME
    puts @add_tab.id
    #p find!("#AddTab")
    @root = @GridPane
    @canvas = @canvas
    @savedSelection = 1
    @selSem = false

    @data_core = Java::dashfx.data.DataCore.new()
    @canvas.registered(@data_core)
    @data_core.known_names.add_listener do |change|
      change.next # TODO: figure out what this magic line does
      change.added_sub_list.each do |new_name|
        add_known new_name
      end
    end
    (@toolbox.tabs.length - 1).times { |i|
      tb = @toolbox.tabs[i+1] # don't want 1st tab
      tb.set_on_selection_changed do |e|
        if tb.selected
          @savedSelection = i + 1
        end
      end }
    @toolbox.set_on_mouse_clicked do |e|
      q = e.target
      while q
        # TODO: this should actually be much simpler comparison
        if q.to_s.include? "TabPaneSkin$TabHeaderSkin" and q.parent and not q.parent.to_s.include? "TabPaneSkin$TabHeaderSkin"
          if q.id == "AddTab" or @toolbox.get_translate_x == 36.0
            v = [300, 36]
            if @toolbox.get_translate_x == 36.0
              v.reverse!
              if q.id == "AddTab"
                @toolbox.selection_model.clear_and_select @savedSelection
              end
            elsif q.id == "AddTab"
              @toolbox.selection_model.select_first
            end
            with(@toolbox) do |tbx|
              timeline do
                animate tbx.translateXProperty, 0.sec => 500.ms, v[0] => v[1]
              end.play
            end
            break
          end
        end
        q = q.parent
      end
    end

    parts = find_toolbox_parts
    parts.each do |key, data|
      data.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))}

    end
    @mode = :design
    @aa_tree = @AATreeview
    @aa_tree.set_cell_factory do |q|
      SD::DesignerSupport::AATreeCell.new do |item, e|
        if e.click_count > 1
          puts "now checking for #{item.value} after I got #{e}"
          tbx_popup = SD::DesignerSupport::ToolboxPopup.new
          find_toolbox_parts.each do |key, data|
            data.each{|i| tbx_popup.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))}
          end
          tbx_popup.x = e.screen_x
          tbx_popup.y = e.screen_y
          tbx_popup.show stage
        end
      end
    end
    @aa_tree.root = tree_item("/")
    stage.set_on_shown do
      self.message = "Ready"
    end

    #DEMO
    @canvas.addDataEndpoint(Java::dashfx.data.endpoints.TestDataSource.new)
    #PLUGINS
    @playback = SD::Playback.new(@data_core, stage)
  end

  def associate_dnd_id(val)
    @dnd_ids << val unless @dnd_ids.include?(val)
    @dnd_ids.index(val)
  end

  def find_toolbox_parts
    {:standard => Java::dashfx.registers.ControlRegister.all.map(&:ruby_class)}
  end

  def add_designable_control(control, x=0, y=0, parent=@canvas)
    designer = SD::DesignerSupport::Overlay.new(control, self)
    if control.is_a? Java::dashfx.data.DesignablePane
      designer.set_on_drag_dropped &method(:drag_drop)
      designer.set_on_drag_over &method(:drag_over)
    end
    parent.add_child_at designer,x,y
    self.message = "Added new #{control.class.name}"
  end

  def add_known(item)
    self.message = "Found remote data. Open AutoAdd tab"
    @aa_tree.root.children.add tree_item(item) #TODO: nested
  end

  def drag_over(event)
    if event.gesture_source != self && event.dragboard.hasString
      event.acceptTransferModes(TransferMode::COPY)
    end
    event.consume();
  end

  def drag_drop(event)
    db = event.dragboard
    event.setDropCompleted(
      if db.hasString
        obj = @dnd_ids[db.string.to_i].new
        pare = event.source == @canvas ? event.source : event.source.child
        add_designable_control obj, event.x, event.y, pare
        @toolbox.selection_model.select_first
        with(@toolbox) do |tbx|
          timeline do
            animate tbx.translateXProperty, 0.sec => 500.ms, 300.0 => 36.0
          end.play
        end
        true
      else
        false
      end)

    event.consume()
  end

  def aa_show_toolbox(e)
    puts "Show toolbox!?!?!?"
    puts e
    p e

  end

  def multiple_selected?
    @selected_items.length > 1
  end

  def multi_drag(original)
    @just_dragged = true
    (@selected_items - [original])
  end

  def run
    @mode = :run
    @canvas.children.each do |c|
      c.running = true
    end
    hide_controls
    @canvas.resume
  end

  def design
    @mode = :design
    @canvas.pause
    @canvas.children.each do |c|
      c.running = false
    end
    show_controls
  end

  def hide_controls
    animate_controls(true)
  end

  def animate_controls(hide)
    mul = hide ? -1 : 1
    nul = hide ? 0 : 1
    # TODO: this should be in the fxml file
    lg = @left_gutter
    bg = @bottom_gutter
    tb = @toolbox
    sb = @stop_button
    stg = stage
    oy = stg.y
    # The properties are read only because of OS issues, so we just create a proxy
    stg_wap = SimpleDoubleProperty.new(stg.width)
    stg_wap.add_change_listener {|ov, old, new| stg.setWidth(new) }
    stg_hap = SimpleDoubleProperty.new(stg.height)
    stg_hap.add_change_listener {|ov, old, new| stg.setHeight(new); stg.y = oy }
    stg_xap = SimpleDoubleProperty.new(stg.x)
    stg_xap.add_change_listener {|ov, old, new| stg.x = new }
    timeline do
      animate lg.prefWidthProperty, 0.ms => 500.ms, (32 - 32 * nul) => (32 * nul)
      animate bg.translateYProperty, 0.ms => 500.ms, (32 * nul) => (32 - 32 * nul)
      animate tb.translateXProperty, 0.ms => 500.ms, (36 - 36 * nul) => (36 * nul)
      animate sb.visibleProperty, 0.ms => 500.ms, (!hide) => hide
      animate stg_wap, 0.ms => 500.ms, stg.width => (stg.width + 32 * mul)
      animate stg_hap, 0.ms => 500.ms, stg.height => (stg.height + 32 * mul)
      animate stg_xap, 0.ms => 500.ms, stg.x => (stg.x - 32 * mul)
    end.play
  end


  def show_controls
    animate_controls(false)
  end

  def message=(msg)
    @alert_msg.text = msg
    with(@msg_carrier) do |mc|
      timeline do
        animate mc.translateYProperty, 0.sec => [200.ms, 5.sec, 5.2.sec], 30.0 => [0.0, 0.0, 30.0]
      end.play
    end
  end

  def hide_properties
    if @properties
      @properties.hide
    end
  end

  def update_properties
    if @selected_items.length < 1 or @selected_items.find_all { |i| !i.editing_nested }.length != 1
      hide_properties
    else
      unless @properties
        @properties = SD::DesignerSupport::PropertiesPopup.new
      end
      @properties.properties = @selected_items[0].properties
      @properties.show(stage)
    end
  end

  def canvas_click(e)
    if @just_dragged
      @just_dragged  = false
      return
    end
    q = e.target
    new_selections = e.control_down? ? @selected_items : []
    begin
      if q.is_a? SD::DesignerSupport::Overlay
        if e.control_down? and new_selections.include? q
          new_selections -= [q]
        else
          new_selections << q
        end
        break
      end
    end while (q = q.parent) && q != @canvas
    (@selected_items + new_selections).each do |si|
      si.selected = new_selections.include? si
    end
    @selected_items = new_selections
    puts "new selections:"
    p @selected_items
    update_properties
  end

  def do_playback_mode
    puts "Playback!"
    @playback.launch
  end

  def canvas_keyup(e)
    if e.code == KeyCode::DELETE
      @selected_items.each do |si|
        @canvas.children.remove(si)
      end
      @selected_items = []
      hide_properties
    end
  end

  def nested_edit(octrl)
    nested_traverse(octrl, lambda { |ctrl|
        ctrl.parent.edit_nested(ctrl) do
          exit_nesting(octrl)
        end}) do |x|
      x.disabled = true
    end
  end

  def exit_nesting(octrl)
    octrl.disabled = false
    octrl.exit_nesting
    nested_traverse(octrl, lambda { |ctrl| ctrl.parent.exit_nested }) do |x|
      if x.is_a? SD::DesignerSupport::Overlay
        x.disabled = false
        x.exit_nesting
      end
    end
  end

  def print_tree(prefix, elt)
    if elt.respond_to? :getChildren
      elt.children.each do |c|
        print_tree(prefix + " ", c)
      end
    end
  end

  def nested_traverse(octrl, after, &eachblock)
    return if octrl == @canvas
    ctrl = octrl
    begin
      saved = (ctrl.parent.children.to_a.find_all{|i| i != ctrl})
      saved.each &eachblock
      after.call(ctrl)
      ctrl = ctrl.parent
    end while ctrl != @canvas
  end
end