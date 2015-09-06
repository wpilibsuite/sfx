/*
 * Copyright (C) 2015 patrick
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
package edu.wpi.first.sfx.designer.ui;

import dashfx.lib.controls.Designable;
import dashfx.lib.util.ControlTree;
import edu.wpi.first.sfx.designer.Main;
import edu.wpi.first.sfx.designer.util.Property;
import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;
import javafx.event.ActionEvent;
import javafx.fxml.FXML;
import javafx.fxml.FXMLLoader;
import javafx.geometry.HPos;
import javafx.geometry.Pos;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.Tooltip;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.HBox;

/**
 *
 * @author patrick
 */
public class PropertiesPopup extends javafx.stage.Popup
{
	private final PropertiesPane ppane;
    public PropertiesPopup()
	{
      super();
      //require 'utils/titled_form_pane'
      getContent().add(ppane = new PropertiesPane());
      //self.hide_on_escape = true
	  setHideOnEscape(true);
			  }
public void setProperties(List<Property> props)
{
	ppane.setProperties(props);
}
public void setTitle(String title)
{
	ppane.setTitle(title);
}
//    def properties=(props)
//      @ppane.properties = props
//    end
//    def title=(props)
//      @ppane.title = props
//    end
//    def decor_manager=(dm)
//      @ppane.decor_manager = dm
//    end
//    def focus_default?
//      scene.focus_owner == @ppane.raw_title
//    end
//    def focus_default!
//      @ppane.raw_title.request_focus
//    end
	class PropertiesPane extends javafx.scene.layout.BorderPane{
    //include JRubyFX::Controller
    
    @FXML // fx:id="titlebar"
    private HBox titlebar; // Value injected by FXMLLoader

    @FXML // fx:id="prop_list"
    private TitledFormPane prop_list; // Value injected by FXMLLoader

    @FXML // fx:id="title"
    private Label title; // Value injected by FXMLLoader
		private List<edu.wpi.first.sfx.designer.util.Property> allprops;

    public PropertiesPane()
	{
	FXMLLoader fxmlLoader = new FXMLLoader(Main.class.getResource("res/PropertiesPopup.fxml"));
		fxmlLoader.setRoot(this);
		fxmlLoader.setController(this);

		try
		{
			fxmlLoader.load();
		}
		catch (IOException exception)
		{
			throw new RuntimeException(exception);
		}
	}

//    def decor_manager=(dm)
//      # TODO: evaluate better ways to do this
//      @dm = dm
//    end

    public void setProperties(List<Property> props)
	{
      this.prop_list.getChildren().clear();
      this.allprops = props.stream().sorted((a, b) -> {
        if (a.getCategory().equals(b.getCategory()))
          return a.getName().compareTo(b.getName());
				  else if (a.getCategory().equals("Basic"))
          return -1;
				  else if (b.getCategory().equals("Basic"))
          return 1;
        else
          return a.getCategory().compareTo(b.getCategory());
				  
      }).collect(Collectors.toList());
      List<Property> bits = props.stream().filter(x -> x.getCategory().equals("Basic")).collect(Collectors.toList());
      if (bits.isEmpty()){
        bits = props.stream().filter(x -> x.getCategory().equals("General")).collect(Collectors.toList());
		 if (bits.isEmpty())
			bits = props;
				}
      for (Property prop : bits)
	  {
		  Label lbl = new Label(prop.getName() + ":");
		  lbl.setTooltip(new Tooltip(prop.getDescription()));
		  this.prop_list.getChildren().add(lbl);
		  Designable d = null;
		  //SD::Designers.get_for(prop.type).tap{|x|x.design(prop)}.ui
		  this.prop_list.getChildren().add(new Label("Designer Here"));
				  }
      if (bits != props)
	  {
        Button expando = new Button("More");
        expando.setOnAction(e -> showAll());
		TitledFormPane.setExpand(expando, true);
        expando.setAlignment(Pos.CENTER);
        GridPane.setHalignment(expando, HPos.CENTER);
        this.prop_list.getChildren().add(expando);
	  }
      else
        show_decorators();
      
	}
	  
	  private void showAll()
	  {
		  
	  }
	  private void show_decorators()
	  {
		  
	  }
/*
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
    end*/

    public void setTitle(String props)
	{
      this.title.setText(props);
  }
	@FXML
    void move(MouseEvent e) {
  if (this.drag_info != null)
	  {
        PropertiesPopup.this.setX(drag_info.original_x + e.getScreenX());
        PropertiesPopup.this.setY(drag_info.original_y + e.getScreenY());
	}
    }

    @FXML
    void begin_move(MouseEvent e) {
this.drag_info = new DragInfo(PropertiesPopup.this.getX() - e.getScreenX(),
        PropertiesPopup.this.getX() - e.getScreenY());
    }

    @FXML
    void finish_move(ActionEvent event) {
		this.drag_info = null;
    }

    @FXML
    void close(ActionEvent event) {
		PropertiesPopup.this.hide();
    }
private DragInfo drag_info = null;

			}

private static class DragInfo {
		public final double original_x;
		public final double original_y;

		private DragInfo(double d, double d0)
		{
			original_x = d;
			original_y = d0;
		}
	
}
}
  