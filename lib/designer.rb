require 'jrubyfx'
require 'designer_support/toolbox_item'
require 'designer_support/overlay_control'
require 'designer_support/properties_popup'
require 'playback'

class SD::Designer
  include JRubyFX::Controller

  fxml_root "res/SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @TooboxTabs
    @selected_items = []
    puts "Going to find addtab...."
    p @testBorderPane
    p @accord
    p @x2
    p @x3
    p @spaine
    p @Content
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    p @add_tab, "is addtab", @toolbox
    @add_tab.id = "AddTab" # TODO: hack. FIXME
    puts @add_tab
    puts @toolbox
    #p find!("#AddTab")
    @root = @GridPane
    @canvas = @canvas
    @savedSelection = 1
    @selSem = false
    (@toolbox.tabs.length - 1).times { |i|
      tb = @toolbox.tabs[i+1] # don't want 1st tab
      tb.set_on_selection_changed do |e|
        if tb.selected
          @savedSelection = i + 1
          puts "Changed selection to #{@savedSelection}"
        end
      end }
    @toolbox.set_on_mouse_clicked do |e|
      q = e.target
      while q
        # TODO: this should actually be much simpler comparison
        if q.to_s.include? "TabPaneSkin$TabHeaderSkin" and q.parent and not q.parent.to_s.include? "TabPaneSkin$TabHeaderSkin"
          puts "checking ids and status"
          p q.id, @add_tab.id, @toolbox.get_translate_x
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
    #  onDragOver="#drag_over" onDragDrop="#drag_drop
    # TODO: HACK
    #      @canvas.set_on_drag_over {|e| drag_over(e)}
    #      @canvas.set_on_drag_drop {|e| drag_drop(e)}

    parts = find_toolbox_parts
    parts.each do |key, data|
      data.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i)}

    end
    @mode = :design
    stage.set_on_shown do
      puts "setting message"
      self.message = "Ready"
    end

    #DEMO
    bsc = Java::dashfx.controls.BadSliderControl.new()
    grph = Java::dashfx.controls.GraphA.new()
    # TODO: clean up
    @data_core = Java::dashfx.data.DataCore.new()
    #puts @data_core.methods.sort
    @data_core.addControl(bsc)
    @data_core.addControl(grph)
    @data_core.addDataEndpoint(Java::dashfx.data.endpoints.TestDataSource.new)
    add_designable_control(bsc)
    add_designable_control(grph)

    #PLUGINS
    @playback = SD::Playback.new(@data_core, stage)
  end

  def find_toolbox_parts
    {:standard => %W[Graph PieChart Speedometer Label Solenoid DigitalSwitch Image Camera Motor Gyro]}
  end

  def add_designable_control(control, x=0, y=0)
    designer = SD::DesignerSupport::Overlay.new(control, self)
    designer.layout_x = x
    designer.layout_y = y
    @canvas.children.add designer
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
        add_designable_control button(db.string,
          max_width: java.lang.Double::MAX_VALUE,
          max_height: java.lang.Double::MAX_VALUE), event.scene_x, event.scene_y
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

  def multiple_selected?
    @selected_items.length > 1
  end

  def multi_drag(original, e)
    @just_dragged = true
    (@selected_items - [original]).map do |itm|
      itm.dragUpdate(e, false)
      itm
    end
  end

  def run
    @mode = :run
    @canvas.children.each do |c|
      c.running = true
    end
    hide_controls
    @data_core.resume
  end

  def design
    @mode = :design
    @data_core.pause
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
        animate mc.translateYProperty, 0.sec => [200.ms, 5.sec, 5200.ms], 30.0 => [0.0, 0.0, 30.0]
      end.play
    end
  end

  def hide_properties
    if @properties
      @properties.hide
    end
  end

  def update_properties
    if @selected_items.length != 1
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
      end
    end while (q = q.parent) && q != @canvas
    (@selected_items + new_selections).each do |si|
      si.selected = new_selections.include? si
    end
    @selected_items = new_selections
    update_properties
  end

  def do_playback_mode
    puts "Playback!"
    @playback.launch
  end
end