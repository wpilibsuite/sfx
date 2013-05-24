require 'jrubyfx'
require 'designer_support/toolbox_item'
require 'designer_support/overlay_control'
require 'designer_support/properties_popup'
require 'designer_support/aa_tree_cell'
require 'designer_support/toolbox_popup'
require 'designer_support/pref_types'
require 'playback'
require 'data_source_selector'
require 'settings_dialog'
require 'yaml'

class SD::Designer
  include JRubyFX::Controller
  java_import 'dashfx.data.DataInitDescriptor'
  java_import 'dashfx.data.InitInfo'

  fxml "SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @TooboxTabs
    @selected_items = []
    @dnd_ids = []
    @dnd_opts = {}
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    puts @add_tab.id, "is addtab"
    @add_tab.id = "AddTab" # TODO: hack. FIXME
    puts @add_tab.id
    #p find!("#AddTab")
    @root = @GridPane
    @canvas = @canvas
    @savedSelection = 1
    @ui2pmap = {@canvas.ui => @canvas}
    @selSem = false

    @data_core = Java::dashfx.data.DataCore.new()
    @canvas.registered(@data_core)
    @data_core.known_names.add_change_listener do |change|
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
            mode = :hide
            if @toolbox.get_translate_x == 36.0
              mode = :show
              if q.id == "AddTab"
                @toolbox.selection_model.clear_and_select @savedSelection
              end
            elsif q.id == "AddTab"
              @toolbox.selection_model.select_first
            end
            if mode == :hide # TODO: clean this up
              hide_toolbox
            else
              show_toolbox
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
            data.each{|i| tbx_popup.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id), :assign_name => item.value)}
          end
          tbx_popup.x = e.screen_x
          tbx_popup.y = e.screen_y
          register_clickoff do
            tbx_popup.hide
          end
          tbx_popup.show @stage
        end
      end
    end
    @aa_tree.root = tree_item("/")
    @stage.set_on_shown do
      #self.message = "Ready"
    end
    @stage.set_on_close_request do
      @canvas.dispose
    end

    @prefs = java.util.prefs.Preferences.user_node_for_package(InitInfo.java_class)
    ip = if !@prefs.get_boolean("team_number_auto", true) and (1..9001).include? @prefs.get_int("team_number", 0)
      @prefs.get_int("team_number", 0)
    else
      snag_ip.tap do |x|
        if x && (1..9001).include?(x) && !@prefs.get_boolean("team_number_auto", false) && @prefs.get_boolean("team_number_auto", true) # nothing set
          @prefs.put_boolean("team_number_auto", false)
          @prefs.put_int("team_number", x)
        end
      end
    end

    if ip
      self.message = "Using #{ip} as team number"
      InitInfo.team_number = ip
    end

    #DEMO
    @canvas.mountDataEndpoint(DataInitDescriptor.new(Java::dashfx.data.endpoints.NetworkTables.new, "Default", InitInfo.new, "/"))
    #PLUGINS
    @playback = SD::Playback.new(@data_core, @stage)
  end

  def snag_ip
    java.net.NetworkInterface.network_interfaces.each do |networkInterface|
			networkInterface.inet_addresses.each do |inet|
        addr = inet.address
        if addr[0] == 10 && addr.length == 4 && addr[1] < 100 && addr[2] < 100 # TODO: will fail for alt 10.4.151.x
          teamn = addr[1] * 100 + addr[2]
          return teamn
        end
      end
    end
  end

  def associate_dnd_id(val, opts=nil)
    @dnd_ids << val unless @dnd_ids.include?(val)
    @dnd_opts[val] = opts
    @dnd_ids.index(val)
  end

  def find_toolbox_parts
    unless @found_plugins
      desc = YAML::load_stream(Java::dashfx.registers.ControlRegister.java_class.resource_as_stream("/dashfx/controls/ValueMeterDescriptor.yml").to_io)
      #TODO: why is this doubled [[]] ???
      desc = desc[0]
      # process the built in yaml
      desc.each do |x|
        oi = x["Image"]
        x["ImageStream"] = Proc.new do
          if oi and oi.length > 0
            Java::dashfx.registers.ControlRegister.java_class.resource_as_stream(oi)
          else
            nil
          end
        end
        x[:proc] = Proc.new {
          fx = FxmlLoader.new
          fx.location = Java::dashfx.registers.ControlRegister.java_class.resource(x["Source"])
          fx.load.tap do |obj|
            x["Defaults"].each do |k, v|
              obj.send(k + "=", v)
            end
          end
        }
      end

      # check for the plugins folder
      plugin_yaml = File.join(File.dirname(File.dirname(__FILE__)), "plugins")
      if Dir.exist? plugin_yaml
        xdesc = YAML::load_file(File.join(plugin_yaml, "manifest.yml"))
        # process the built in yaml
        xdesc.each do |x|
          oi = x["Image"]
          x["ImageStream"] = Proc.new do
            if oi and oi.length > 0
              java.net.URL.new("file://#{plugin_yaml}#{oi}").open_stream
            else
              nil
            end
          end
          x[:proc] = Proc.new {
            fx = FxmlLoader.new
            fx.location = java.net.URL.new("file://#{plugin_yaml}#{x["Source"]}")
            fx.load.tap do |obj|
              x["Defaults"].each do |k, v|
                obj.send(k + "=", v)
              end
            end
          }
        end

        desc += xdesc
      end

      # Process the java classes
      Java::dashfx.registers.ControlRegister.all.each do |jclass|
        annote = jclass.annotation(Java::dashfx.controls.Designable.java_class)
        oi = annote.image
        cat_annote = jclass.annotation(Java::dashfx.controls.Category.java_class)
        cat_annote = cat_annote.value if cat_annote
        desc << {
          "Name" => annote.value,
          "Description" => annote.description,
          "Image" => annote.image,
          "ImageStream" => Proc.new do
            if oi and oi.length > 0
              jclass.ruby_class.java_class.resource_as_stream(oi)
            else
              nil
            end
          end,
          "Category" => cat_annote,
          proc: Proc.new { jclass.ruby_class.new }
        }
      end
      @toolbox_bits = {:standard => desc}
      @found_plugins = true
    end
    @toolbox_bits
  end

  def add_designable_control(control, x=0, y=0, parent=@canvas)
    designer = SD::DesignerSupport::Overlay.new(control, self, parent)
    if control.is_a? Java::dashfx.data.DesignablePane
      designer.set_on_drag_dropped &method(:drag_drop)
      designer.set_on_drag_over &method(:drag_over)
    end
    parent.add_child_at designer,x,y
    @ui2pmap[control.ui] = control
    self.message = "Added new #{control.class.name}"
  end

  def ui2p(ui)
    @ui2pmap[ui]
  end

  def add_known(item)
    #self.message = "Found remote data. Open AutoAdd tab"
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
        obj = @dnd_ids[db.string.to_i][:proc].call
        pare = event.source == @canvas.ui ? @canvas : event.source.child # TODO: is this child.ui?
        if @dnd_opts[@dnd_ids[db.string.to_i]]
          # TODO: check for others and dont assume name
          obj.name = @dnd_opts[@dnd_ids[db.string.to_i]][:assign_name]
        end
        add_designable_control obj, event.x, event.y, pare
        hide_toolbox
        @clickoff_fnc.call if @clickoff_fnc
        @on_mouse.call(nil) if @on_mouse
        true
      else
        false
      end)

    event.consume()
  end

  def register_clickoff(&fnc)
    @clickoff_fnc = fnc
    @on_mouse = Proc.new do |e|
      e.consume if e
      @GridPane.remove_event_filter(MouseEvent::MOUSE_PRESSED,@on_mouse)
      fnc.call
      @on_mouse = nil
    end
    @GridPane.add_event_filter(MouseEvent::MOUSE_PRESSED,@on_mouse)
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
    @canvas.ui.children.each do |c|
      c.running = true
    end
    hide_controls
    @canvas.resume
  end

  def design
    @mode = :design
    @canvas.pause
    @canvas.ui.children.each do |c|
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
    stg = @stage
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
      bnds = @selected_items[0].localToScene(@selected_items[0].getBoundsInLocal)
      scr_x = @scene.x + @stage.x
      scr_y = @scene.y + @stage.y
      @properties.y = bnds.min_y + scr_y
      @properties.x = bnds.max_x + scr_x
      @properties.show(@stage)
    end
  end

  def hide_toolbox
    @toolbox.selection_model.select_first
    with(@toolbox) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, 300.0 => 36.0
      end.play
    end
    @add_tab_icon.image = @add_tab_plus
  end

  def show_toolbox
    with(@toolbox) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, 36.0 => 300.0
      end.play
    end
    @add_tab_icon.image = @add_tab_close
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
        @canvas.ui.children.remove(si)
      end
      @selected_items = []
      hide_properties
    end
  end

  def nested_edit(octrl)
    nested_traverse(octrl, lambda { |ctrl|
        ui2p(ctrl.parent).edit_nested(ctrl) do
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
    return if octrl == @canvas.ui
    ctrl = octrl
    begin
      saved = (ctrl.parent.children.to_a.find_all{|i| i != ctrl})
      saved.each &eachblock
      after.call(ctrl)
      ctrl = ctrl.parent
    end while ctrl != @canvas.ui
  end

  def show_data_sources
    data_core = @data_core
    stg = @stage
    stage(init_style: :utility, init_modality: :app, title: "Data Source Selector") do
      init_owner stg
      center_on_screen
      fxml SD::DataSourceSelector, :initialize => [data_core]
    end.show_and_wait
  end

  def aa_add_all
    hide_toolbox
    @aa_offset_tmp = 0
    @aa_tree.root.children.map{|x| @data_core.get_observable(x.value)}.each do |ctrl|
      type = SD::DesignerSupport::PrefTypes.for(ctrl.type)
      if type
        add_designable_control build(type, name: ctrl.name), @aa_offset_tmp, @aa_offset_tmp += 20
      else
        puts "Warning: no default control for #{ctrl.type.mask}"
      end
    end
  end

  def aa_add_new
    puts "clicked add new"
  end

  def edit_settings
    stg = @stage
    prefs = @prefs
    this = self
    stage(init_style: :utility, init_modality: :app, title: "SmartDashboard Settings") do
      init_owner stg
      fxml SD::SettingsDialog, :initialize => [prefs, this]
      show_and_wait
    end
  end

  def root_canvas=(cvs)
    childs = @canvas.ui.children.to_a
    @canvas.ui.children.clear
    cvs.ui.children.add_all(childs)
    cvs.registered(@data_core)
    @BorderPane.center = cvs.ui
    @canvas = cvs
    @ui2pmap[cvs.ui] = cvs
    cvs.ui.setOnDragDropped &method(:drag_drop)
    cvs.ui.setOnDragOver &method(:drag_over)
    cvs.ui.setOnMouseReleased &method(:canvas_click)
  end
end
