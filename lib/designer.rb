require 'jrubyfx'
%W[designer_support io_support plugins windowing].each do |x|
  Dir["#{File.dirname(__FILE__)}/#{x}/*.rb"].each {|file| require file }
end
require 'playback'
require 'data_source_selector'
require 'settings_dialog'
require 'yaml'
require 'zlib'
require 'rubygems/package'

class SD::Designer
  include JRubyFX::Controller
  java_import 'dashfx.lib.data.DataInitDescriptor'
  java_import 'dashfx.lib.data.InitInfo'
  java_import 'dashfx.lib.registers.ControlRegister'

  fxml "SFX.fxml"

  def initialize
    # best to catch missing stuff now
    @toolbox= @left_gutter
    @selected_items = []
    @dnd_ids = []
    @dnd_opts = {}
    @add_tab = @AddTab
    @toolbox_group = {:standard => @STDToolboxFlow}
    @root = @GridPane
    @savedSelection = 1
    @preparsed = 0
    @ui2pmap = {}
    @selSem = false
    @mode = :design
    @toolbox_status = :hidden
    @aa_tree = @AATreeview
    @data_core_sublist = []
    @aa_tree_list = []
    @aa_tree.root = tree_item("/")
    @layout_managers = {}
    @view_controllers = []

    # Load preferences
    @prefs = SD::DesignerSupport::Preferences

    # load the custom regexer
    @aa_regexer.text_property.add_change_listener do |ov, ol, new|
      begin
        regx = Regexp.new(new, "i")
        @aa_filter.regex = regx
        # filter the list
        @aa_tree_list.each do |child|
          child[:fout] = child[:value].match(regx) == nil
        end
        @aa_tree.root.children.clear
        @aa_tree.root.children.add_all(@aa_tree_list.find_all{|x|!x[:fout]}.map{|x|tree_item(value: x)})
        @aa_regexer.style = "-fx-border-color: green;"
        @aa_regex_message.text = "Valid regex"
      rescue Exception => e
        @aa_regex_message.text = e.message
        @aa_regexer.style = "-fx-border-color: red;"
      end
    end
    aa_hide_regex_panel() # it shows by default

    # get all toolbox bits and add them to the ui toolbox
    find_toolbox_parts.each do |key, data|
      data.each{|i| @toolbox_group[key].children.add SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))}
    end

    #load recent files
    build_open_menu

    # Set the auto add tree cells
    @aa_tree.set_cell_factory do |q|
      SD::DesignerSupport::AATreeCell.new
    end

    # On shown and on closing handlers
    @stage.set_on_shown do

      # Create our data core. TODO: use preferences to configure it.
      @data_core = Java::dashfx.lib.data.DataCore.new()
      # when the data core finds about new names, let us know!
      @data_core.known_names.add_change_listener do |change|
        change.next # change is an "iterator" of stuff, so use next to get the added list
        change.added_sub_list.each do |new_name|
          add_known new_name
          @view_controllers.each do |vc|
            if vc.should_add?(new_name, @data_core.known_names.get)
              aa_add_some(vc.pane, new_name)
            end
          end
        end
      end

      #TODO: use preferences for this. DEMO.
      @data_core.mountDataEndpoint(DataInitDescriptor.new(Java::dashfx.lib.data.endpoints.NetworkTables.new, "Default", InitInfo.new, "/"))
      #TODO: use standard plugin arch for this
      @playback = SD::Playback.new(@data_core, @stage)

      # Add known tab and any plugin tabs
      main_tab = add_tab(SD::Windowing::DefaultViewController.new)
      SD::Plugins.view_controllers.find_all{|x|x.default > 0}.each do |x|
        add_tab(x.new)
      end
      tab_select(main_tab)

      self.message = "Ready"
      SD::DesignerSupport::Overlay.preparse_new(3)
    end
    @stage.on_close_request do |event|
      stop_it = false
      # TODO: multi-windows
      # TODO: I cant seem to prevent window from closing
      if false && @canvas.children.length > 0 && SD::IOSupport::DashObject.parse_scene_graph(@canvas) != @current_save_data
        answer = SD::DesignerSupport::SaveQuestion.ask(@stage)
        if answer == :cancel_oh_so_broken
          event.consume
          stop_it = true
        elsif answer == :save
          save
        end
      end
      @canvas.dispose unless true # stop_it
    end

    # get the team number
    # if the team number is set in prefs, use it
    ip = if !@prefs.team_number_auto and (1..9001).include? @prefs.team_number
      @prefs.team_number || 0
    else # otherwise, snag from nics and if we have not set any preferences, save it.
      snag_ip.tap do |x|
        if x and (1..9001).include? x and not @prefs.has_key? :team_number_auto
          @prefs.team_number_auto = false
          @prefs.team_number = x
        end
      end
    end
    if ip
      self.message = "Using #{ip == 0 ? "localhost" : ip } as team number"
      InitInfo.team_number = ip
    end

    # pre-parse one item for speedy adding
    SD::DesignerSupport::Overlay.preparse_new(1)
    # do this now so props are fast to load
    @properties = SD::DesignerSupport::PropertiesPopup.new

    # when we blur, hide the properties window. TODO: property window needs improvements
    @stage.focused_property.add_change_listener do |v, o, new|
      unless new
        @was_showing = @properties.showing?
        @properties.hide
      else
        @properties.show(@stage) if @was_showing
      end
    end
  end

  # iterate over all the interfaces on this computer and find one that matches 10.x.y.z, where x and y < 100
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

  # easy dnd way to send objects. should use actual text or an hash
  def associate_dnd_id(val, opts=nil)
    hide_toolbox # TODO: cheap hack
    @dnd_ids << val unless @dnd_ids.include?(val)
    @dnd_opts[val] = opts
    @dnd_ids.index(val)
  end

  # Scrounge around and find everything that should go in the toolbox. TODO: modularize this to use plugins
  def find_toolbox_parts
    unless @found_plugins # cache it as its expensive
      # TODO: exceptions
      SD::Plugins.load "built-in", lambda {|url|ControlRegister.java_class.resource url}

      # check for the plugins folder
      plugin_yaml = $PLUGIN_DIR
      if Dir.exist? plugin_yaml
        Dir["#{plugin_yaml}/*"].each do |plugin_path|
          SD::Plugins.load(plugin_path, if plugin_path.end_with? ".jar"
              require plugin_path
              class_loader = java.net.URLClassLoader.new([java.net.URL.new("file:#{plugin_path}")].to_java(java.net.URL))
              lambda {|url| class_loader.find_resource url.gsub(%r{^/}, '')}
            else
              lambda {|url| java.net.URL.new("file://#{plugin_path}/#{url}")}
            end)
        end
      end

      @toolbox_bits = {:standard => SD::Plugins.controls}
      @found_plugins = true
    end
    @toolbox_bits
  end

  # called to wrap the control in an overlay and to place in a control
  def add_designable_control(control, x, y, parent, oobj)
    designer = SD::DesignerSupport::Overlay.new(control, self, parent, oobj)

    # if its designable, add hooks for nested editing to work
    if control.is_a? Java::dashfx.lib.controls.DesignablePane
      designer.set_on_drag_dropped &method(:drag_drop)
      designer.set_on_drag_over &method(:drag_over)
      @layout_managers[control] = SD::Windowing::LayoutManager.new(control)
    end
    @layout_managers[parent].layout_controls({designer => [x, y]})
    # Add it to the map so we can get the controller later if needed from UI tree
    @ui2pmap[control.ui] = control
    self.message = "Added new #{control.java_class.name}"
    designer
  end

  def ui2p(ui)
    @ui2pmap[ui]
  end

  def add_known(item)
    val = {value: item, fout: false}
    @aa_tree_list << val
    @aa_tree.root.children.add tree_item(value: val) #TODO: nested
  end

  def drag_over(event)
    if event.gesture_source != self && event.dragboard.hasString
      event.acceptTransferModes(TransferMode::COPY)
    end
    event.consume();
  end

  # whenever we drop something on the canvas, this is called. There are two cases: auto add droppings, or normal droppings
  def drag_drop(event)
    db = event.dragboard
    event.setDropCompleted(
      if db.hasString
        if db.string.start_with? "AutoAdd:"
          id = db.string[8..-1] #strip prefix
          #open a popup and populate it
          tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
          find_toolbox_parts.each do |key, data| # TODO: grouping and sorting
            data.reject{|x|x.category == "Grouping"}.each do |i|
              ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id), :assign_name => id)
              ti.set_on_mouse_clicked do
                drop_add associate_dnd_id(i, :assign_name => id), event.x, event.y, event.source
                @on_mouse.call if @on_mouse # hide it
              end
              tbx_popup.add ti
            end
          end
          # position the popup at the location of the mouse
          tbx_popup.x = event.screen_x
          tbx_popup.y = event.screen_y
          # when we click other places, hide the toolbox
          register_clickoff do
            tbx_popup.hide
          end
          tbx_popup.show @stage
          SD::DesignerSupport::Overlay.preparse_new(1)
        else
          drop_add(db.string.to_i, event.x, event.y, event.source)
        end
        true
      else
        false
      end)

    event.consume()
  end

  # called to add a namable control to the items
  def drop_add(id,x, y, source)
    pare = source == current_vc.ui ? current_vc.pane : source.child
    dnd_obj = @dnd_ids[id]
    obj = dnd_obj.new # create the object that we are dragging on
    if @dnd_opts[dnd_obj]
      # TODO: check for other options
      obj.name = @dnd_opts[dnd_obj][:assign_name] if obj.respond_to? :name
    end
    add_designable_control obj, x, y, pare, @dnd_ids[id]
    hide_toolbox
    @clickoff_fnc.call if @clickoff_fnc
    @on_mouse.call(nil) if @on_mouse
  end

  def morph_child(overlay, event) #TODO: drip drip drip leakage
    tbx_popup = SD::DesignerSupport::ToolboxPopup.new # TODO: cache these items so we don't have to reparse fxml
    find_toolbox_parts.each do |key, data| # TODO: grouping and sorting
      data.reject{|x|x.category == "Grouping"}.each do |i|
        ti = SD::DesignerSupport::ToolboxItem.new(i, method(:associate_dnd_id))
        ti.set_on_mouse_clicked do
          obj = i.new
          yield(obj, i)
          @ui2pmap[obj.ui] = obj
          self.message = "Added new #{obj.java_class.name}"
          hide_toolbox
          @clickoff_fnc.call if @clickoff_fnc
          @on_mouse.call(nil) if @on_mouse
        end
        tbx_popup.add ti
      end
    end
    # position the popup at the location of the mouse
    tbx_popup.x = overlay.local_to_scene(overlay.bounds_in_local).min_x + @stage.x
    tbx_popup.y = overlay.local_to_scene(overlay.bounds_in_local).min_y + @stage.y
    # when we click other places, hide the toolbox
    register_clickoff do
      tbx_popup.hide
    end
    tbx_popup.show @stage
  end

  # These functions are used to do "clickoffs" aka close a window when you click anywhere
  def register_clickoff(&fnc)
    @clickoff_fnc = fnc
    on_mouse = @on_mouse = Proc.new do |e|
      e.consume if e
      @GridPane.remove_event_filter(MouseEvent::MOUSE_PRESSED,on_mouse)
      fnc.call
      @on_mouse = nil
    end
    @GridPane.add_event_filter(MouseEvent::MOUSE_PRESSED,on_mouse)
  end

  # TODO: somehow merge with above method
  def register_toolbox_clickoff(&fnc)
    @clickoff_tbx = fnc
    on_tmouse = @on_tmouse = Proc.new do |e|
      q = e.nil? ? false : e.target
      while q
        if q == @toolbox
          q = false
        else
          q = q.parent
        end
      end
      if q == nil # no parents found
        @GridPane.remove_event_filter(MouseEvent::MOUSE_PRESSED,on_tmouse)
        @clickoff_tbx.call
        @on_tmouse = nil
      end
    end
    @GridPane.add_event_filter(MouseEvent::MOUSE_PRESSED,on_tmouse)
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
    @view_controllers.each do |vc|
      vc.pane.children.each do |c|
        c.running = true
      end
    end
    hide_controls
    hide_toolbox
    hide_properties
  end

  def design
    @mode = :design
    @view_controllers.each do |vc|
      vc.pane.children.each do |c|
        c.running = false
      end
    end
    show_controls
  end

  def hide_controls
    animate_controls(true)
  end

  def animate_controls(hide)
    mul = hide ? -1 : 1
    nul = hide ? 0 : 1
    # TODO: this should be cleaned up
    bg = @bottom_gutter
    sb = @stop_button
    stg = @stage
    oy = stg.y
    ox = stg.x
    # The properties are read only because of OS issues, so we just create a proxy
    stg_hap = SimpleDoubleProperty.new(stg.height)
    stg_hap.add_change_listener {|ov, old, new| stg.setHeight(new); stg.y = oy; stg.x = ox; }
    timeline do
      animate bg.translateYProperty, 0.ms => 500.ms, (32 * nul) => (32 - 32 * nul)
      animate sb.visibleProperty, 0.ms => 500.ms, (!hide) => hide
      animate stg_hap, 0.ms => 500.ms, stg.height => (stg.height + 32 * mul)
    end.play
  end


  def show_controls
    animate_controls(false)
  end

  # set the popup message at the bottom
  def message=(msg)
    @alert_msg.text = msg
    with(@msg_carrier) do |mc|
      timeline do
        animate mc.translateYProperty, 0.sec => [200.ms, 5.sec, 5.2.sec], 30.0 => [0.0, 0.0, 30.0]
      end.play
    end
  end

  def save
    if @currently_open_file
      save_file(@currently_open_file)
    else
      save_as
    end
  end

  def save_as
    dialog = file_chooser(:title => "Save Layout...") do
      add_extension_filter("-fx:SmartDashboard save files (*.fxsdash)")
    end
    file = dialog.showSaveDialog(@stage)
    return unless file
    save_file file.path
  end

  def save_file(file)
    file += ".fxsdash" unless file.end_with? ".fxsdash"
    File.open(file, "w") do |io|
      Gem::Package::TarWriter.new(io) do |tar|
        tar.add_file("version", 0644) {|f|f.write("0.1")}
        tar.add_file("data.yml", 0644) do |yml|
          psg = SD::IOSupport::DashObject.parse_scene_graph(@view_controllers)
          yml.write YAML.dump(psg)
          @current_save_data = psg
        end
      end
    end
    self.message = "Saved!"
    @stage.title = "SmartDashboard : #{File.basename(file, ".fxsdash")}"
    @currently_open_file = file
    update_recent_opens(file)
    build_open_menu
  end

  def update_recent_opens(new)
    recently_open = @prefs.recently_open
    if recently_open.include? new
      # remove it and put it at the front
      recently_open -= [new]
    end
    recently_open = ([new] + recently_open).first(10)
    @prefs.recently_open = recently_open
  end

  def build_open_menu
    recently_open = @prefs.recently_open
    this = self
    with(@open_btn) do
      items.clear
      menu_item("Open", style: "-fx-font-weight: bold").on_action {this.open}
      separator_menu_item
      recently_open.each do |i|
        menu_item(File.basename(i, ".fxsdash")).on_action do
          this.open_file(i)
        end
      end
    end
  end

  def open
    dialog = file_chooser(:title => "Open Layout...") do
      add_extension_filter("-fx:SmartDashboard save files (*.fxsdash)")
    end
    file = dialog.show_open_dialog(@stage)
    return unless file
    open_file(file.path)
  end

  def open_file(file)
    update_recent_opens(file)
    build_open_menu
    data = {} # TODO: very memory inefficient
    File.open(file, "r") do |io|
      Gem::Package::TarReader.new(io) do |tar|
        tar.each do |entry|
          data[entry.full_name] = entry.read
        end
      end
    end
    if data["version"].to_f != 0.1
      self.message = "Unknown file version '#{data["version"]}'"
      return
    end
    doc =  YAML.load(data['data.yml'])
    @current_save_data = doc
    # TODO: tab support
    @canvas.children.clear
    self.root_canvas = doc.object.new
    doc.children.each {|x| open_visitor(x, @canvas) }
    @currently_open_file = file
    @stage.title = "SmartDashboard : #{File.basename(file, ".fxsdash")}"
    self.message = "File Load Successfull"
  end

  def open_visitor(cdesc, parent)
    desc = SD::Plugins::ControlInfo.find(cdesc.object)
    obj = desc.new
    obj.ui.setPrefWidth cdesc.sprops["Width"]
    obj.ui.setPrefHeight cdesc.sprops["Height"]
    add_designable_control(obj, cdesc.sprops["LayoutX"], cdesc.sprops["LayoutY"], parent, desc)
    cdesc.props.each do |prop, val|
      nom = "set#{prop}"
      if obj.respond_to? nom
        obj
      else
        obj.ui
      end.send(nom, (val.kind_of?(SD::IOSupport::ComplexObject) ? val.to_value : val))
    end
    cdesc.children.each {|x| open_visitor(x, obj) }
  end

  def new_document
    # TODO: check for unsaved changes
    # assign the root canvas node from preferences
    @canvas = @current_save_data = @currently_open_file = nil
    @stage.title = "SmartDashboard : Untitled"
    self.root_canvas = @prefs.root_canvas.new
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
      @properties.properties = @selected_items[0].properties
      sic = @selected_items[0].child
      name = sic.name if sic.respond_to? :name
      name = @selected_items[0].original_name unless name
      name = sic.java_class.name.split(".").last unless name
      @properties.title = name
      properties_show_around @selected_items[0]
    end
  end

  def properties_draghide
    hide_properties
  end

  def properties_dragshow(elt)
    properties_show_around(elt)
  end

  # display the properties near some element
  def properties_show_around(elt)
    bnds = elt.localToScene(elt.getBoundsInLocal)
    scr_x = @scene.x + @stage.x
    scr_y = @scene.y + @stage.y
    scr = Screen.getScreensForRectangle(scr_x, scr_y, 1, 1)[0]
    loc_x = bnds.max_x + scr_x + 5
    loc_y = bnds.min_y + scr_y
    if scr.bounds.max_x <= loc_x + @properties.width
      loc_x = bnds.min_x + scr_x - 5 - @properties.width
    end
    if scr.bounds.max_y <= loc_y + @properties.height
      loc_y = bnds.max_y + scr_y - @properties.height
    end
    @properties.y = loc_y
    @properties.x = loc_x
    @properties.show(@stage)
  end

  def show_hide_toolbox
    if @toolbox_status == :hidden
      show_toolbox
    else
      hide_toolbox
    end
  end

  def hide_toolbox
    return if @toolbox_status == :hidden
    @toolbox_status = :hidden
    asl = @add_slider
    @clickoff_tbx = Proc.new {|x|}
    @on_tmouse.call if @on_tmouse
    with(@left_gutter) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.ms => 500.ms, 0.0 => -266.0
        animate asl.minWidthProperty, 0.ms => 500.ms, 266.0 => 0.0
      end.play
    end
  end

  def show_toolbox
    return if @toolbox_status == :visible
    @toolbox_status = :visible
    asl = @add_slider
    with(@left_gutter) do |tbx|
      timeline do
        animate tbx.translateXProperty, 0.sec => 500.ms, -266.0 => 0.0
        animate asl.minWidthProperty, 0.ms => 500.ms, 0.0 => 266.0
      end.play
    end
    register_toolbox_clickoff do
      hide_toolbox
    end
  end

  def canvas_click(e)
    if @just_dragged
      @just_dragged  = false
      return
    end
    return if @mode != :design
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
    end while (q = q.parent) && q != current_vc.pane
    select(*new_selections)
  end

  def select(*items)
    new_selections = items
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

  def delete_selected
    @selected_items.each do |si|
      current_vc.pane.children.remove(si)
    end
    @selected_items = []
    hide_properties
  end

  def canvas_keyup(e)
    if e.code == KeyCode::DELETE
      delete_selected
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
    nested_traverse(octrl, lambda { |ctrl| ui2p(ctrl.parent).exit_nested }) do |x|
      if x.is_a? SD::DesignerSupport::Overlay
        x.disabled = false
        x.exit_nesting
      end
    end
    select(octrl)
  end

  # helper function for traversing parents when nesting editing
  def nested_traverse(octrl, after, &eachblock)
    return if octrl == current_vc.ui
    ctrl = octrl
    begin
      saved = (ctrl.parent.children.to_a.find_all{|i| i != ctrl})
      saved.each &eachblock
      after.call(ctrl)
      ctrl = ctrl.parent
    end while ctrl != current_vc.ui
  end

  # Settings for the canvas TODO: add other canvas properties
  def show_data_sources
    data_core = @data_core
    stg = @stage
    stage(init_style: :utility, init_modality: :app, title: "Data Source Selector") do
      init_owner stg
      center_on_screen
      fxml SD::DataSourceSelector, :initialize => [data_core]
    end.show_and_wait
  end

  # Add all known controls
  def aa_add_all
    # for each of the items in the tree view (TODO: NOT A TREE VIEW), add it as the pref type
    aa_add_some(current_vc.pane, *@aa_tree.root.children.map{|x| x.value[:value]}.find_all{|x| !@aa_regex_showing || x.match(@aa_filter.regex)})
  end

  def aa_add_some(pane, *names)
    names.each do |ctrl_name|
      ctrl = @data_core.get_observable(ctrl_name)
      begin
        new_objd = if !ctrl.type || ctrl.type == 64
          SD::Plugins.controls.find{|x| x.group_types == ctrl.group_name}
        else
          SD::DesignerSupport::PrefTypes.for(ctrl.type)
        end
        new_obj = new_objd.new
        if new_obj
          add_designable_control with(new_obj, name: ctrl.name), nil, nil, pane, new_objd
        else
          puts "Warning: no default control for #{ctrl.type.mask}"
        end
      rescue
        puts "Warning: error finding default control for #{ctrl}"
      end
    end
    hide_toolbox
  end
  # TODO: next few lines can be cleaned up im sure
  def aa_add_new
    @aa_filter.always_add = !@aa_filter.always_add
  end

  def aa_hide_regex_panel
    @aa_ctrl_panel.children.remove(@aa_ctrl_regex)
    @aa_expand_panel.text = "V"
  end

  def aa_show_regex_panel
    @aa_ctrl_panel.children.add(@aa_ctrl_regex)
    @aa_expand_panel.text = "^"
  end

  def aa_toggle_panel
    @aa_regex_showing = !@aa_regex_showing
    if @aa_regex_showing
      aa_show_regex_panel
    else
      aa_hide_regex_panel
    end
  end

  def current_vc
    @view_controllers[@vc_index]
  end

  def add_tab(vc)
    vc.tab = button(vc.name)
    vc.tab.set_on_action &method(:tab_clicked)
    @view_controllers << vc
    @tab_box.children.add(@tab_box.children.length - 1, vc.tab)
    tab_select(vc.tab)
    return vc.tab
  end

  def tab_select(tab)
    vc = @view_controllers.find{|x|x.tab == tab}
    @view_controllers.each do |lm|
      lm.tab.style_class.remove("active")
    end
    vc.tab.style_class.add("active")
    self.root_canvas = vc
    @vc_index = @view_controllers.index(vc)
  end

  def tab_clicked(e)
    tab_select(e.target)
  end

  # edit the smart dashboard settings
  def edit_settings
    hide_properties
    stg = @stage
    this = self
    stage(init_style: :utility, init_modality: :app, title: "SmartDashboard Settings") do
      init_owner stg
      fxml SD::SettingsDialog, :initialize => [this]
      show_and_wait
    end
  end

  # Assign the designer surface and set up handlers
  def root_canvas=(cvs)
    cvs.pane.registered(@data_core)
    @BorderPane.center = cvs.ui
    @cur_canvas = cvs
    @layout_managers[cvs.pane] = cvs.layout_manager
    @ui2pmap[cvs.ui] = cvs
    cvs.ui.setOnDragDropped &method(:drag_drop)
    cvs.ui.setOnDragOver &method(:drag_over)
    cvs.ui.setOnMouseReleased &method(:canvas_click)
  end
end
