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

import edu.wpi.first.sfx.designer.util.DemoImpl;
import edu.wpi.first.sfx.designer.ui.DesignerMetadata;
import dashfx.controls.DataAnchorPane;
import dashfx.lib._private.rt._Canvas_cmi;
import dashfx.lib.registers.ControlRegister;
import dashfx.lib.rt.ControlMetaInfo;
import edu.wpi.first.sfx.designer.DepManager;
import edu.wpi.first.sfx.designer.Main;
import edu.wpi.first.sfx.designer.util.MappedList;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ForkJoinPool;
import javafx.animation.KeyFrame;
import javafx.animation.KeyValue;
import javafx.animation.Timeline;
import javafx.application.Platform;
import javafx.beans.binding.Bindings;
import javafx.collections.FXCollections;
import javafx.collections.ListChangeListener;
import javafx.event.*;
import javafx.fxml.FXML;
import javafx.scene.Node;
import javafx.scene.control.*;
import javafx.scene.image.*;
import javafx.scene.input.DragEvent;
import javafx.scene.input.KeyEvent;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.*;
import javafx.util.Duration;

/**
 *
 * @author patrick
 */
public class DesignerUI
{

	@FXML
	private ScrollPane spain;

	@FXML
	private Tooltip aa_regex_message;

	@FXML
	private BorderPane BorderPane;

	@FXML
	private Label alert_msg;

	@FXML
	private HBox aa_ctrl_regex;

	@FXML
	private VBox left_gutter;

	@FXML
	private Button stop_button;

	@FXML
	private Image add_tab_plus;

	@FXML
	private HBox tab_box;

	@FXML
	private TreeView<?> AATreeview;


	@FXML
	private HBox bottom_gutter;

	@FXML
	private Button aa_expand_panel;

	@FXML
	private SplitMenuButton open_btn;

	@FXML
	private TextField aa_regexer;

	@FXML
	private GridPane GridPane;

	@FXML
	private Button playback_button;

	@FXML
	private ImageView add_tab_icon;

	@FXML
	private Accordion accord;

	@FXML
	private HBox add_slider;

	@FXML
	private Pane gutter_shadow;

	@FXML
	private Pane hack_corner;


	@FXML
	private VBox aa_ctrl_panel;

	@FXML
	private TitledPane x2;

	@FXML
	private HBox msg_carrier;

	private boolean toolbox_status_visible = false;

	private Timeline toolbox_hider;

	private Map<String, FlowPane> toolbox_group = new HashMap<>();
	private DemoImpl infl;
	private DesignerMetadata meta;

	@FXML
	void initialize()
	{
		Timeline t = toolbox_hider = new Timeline();
		t.getKeyFrames().add(new KeyFrame(Duration.ZERO, new KeyValue(left_gutter.translateXProperty(), -266.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.millis(500), new KeyValue(left_gutter.translateXProperty(), 0.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.ZERO, new KeyValue(add_slider.minWidthProperty(), 0.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.millis(500), new KeyValue(add_slider.minWidthProperty(), 268.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.ZERO, new KeyValue(gutter_shadow.translateXProperty(), 0.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.millis(500), new KeyValue(gutter_shadow.translateXProperty(), 266.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.ZERO, new KeyValue(gutter_shadow.minWidthProperty(), 0.0)));
		t.getKeyFrames().add(new KeyFrame(Duration.millis(400), new KeyValue(gutter_shadow.minWidthProperty(), 30.0)));

		// toolbox clickoff support
		GridPane.addEventFilter(MouseEvent.MOUSE_PRESSED, (e) ->
						{
							if (clickoff_tbx == null)
							{
								return;
							}
							boolean cont = e != null;
							EventTarget q = e == null ? null : e.getTarget();

							while (q != null && cont)
							{
								if (q == left_gutter)
								{
									cont = false;
								}
								else
								{
									q = ((Node) q).getParent();
								}
							}
							if (q == null) // no parents found
							{
								clickoff_tbx.run();
							}

		});

		// toolbox item list change handler
		DepManager.getInstance().getToolboxControls().addListener(new ListChangeListener()
		{
			@Override
			public void onChanged(ListChangeListener.Change change)
			{
				//TODO: this assumes we only add items to the lists...
				while (change.next())
				{
					processToolboxList(change.getAddedSubList());

				}
			}
		});
		// add the intial toolbox items
		processToolboxList(DepManager.getInstance().getToolboxControls());
		
		infl = new DemoImpl();
		meta = new DesignerMetadata(new _Canvas_cmi(), infl, Main.class.getResource("res/DesignerOverlayControl.fxml")); // the root
		Node n = meta.getAssociatedView(meta.getRoot());
		spain.setContent(n);
		infl.runService();

		DepManager.getInstance().complete("build_ui", this);
	}

	private void processToolboxList(List<ControlMetaInfo> z)
	{
		if (!Platform.isFxApplicationThread())
			Platform.runLater(() -> processToolboxList(z));
		z.stream().forEach(x ->
		{
			final String name = x.getCategory();
			if (!toolbox_group.containsKey(name))
			{
				UiFragmentFactory.Pair<TitledPane, FlowPane> pp = UiFragmentFactory.toolboxAccordionPane(name);
				toolbox_group.put(name, pp.second);
				accord.getPanes().add(pp.first);
				Bindings.bindContentBidirectional(pp.second.getChildren(),
												  new MappedList<>(
														  DepManager.getInstance().getToolboxControls().
														  filtered(y -> y.getCategory().equals(name)),
														  y -> (Node)new ToolboxItem(y)
												  ));
			}
		});
	}

	@FXML
	void canvas_keyup(KeyEvent event)
	{

	}

	void hide_properties()
	{
		// TODO
	}

	@FXML
	void show_toolbox(ActionEvent event)
	{
		hide_properties();
		if (toolbox_status_visible)
		{
			return;
		}
		else
		{
			toolbox_status_visible = true;
		}
		toolbox_hider.setRate(1);
		toolbox_hider.playFromStart();
		register_toolbox_clickoff(() -> hide_toolbox(null));
	}

	private Runnable clickoff_tbx = null;

	void register_toolbox_clickoff(Runnable fnc)
	{
		clickoff_tbx = fnc;
	}

	@FXML
	void new_document(ActionEvent event)
	{

	}

	@FXML
	void open(ActionEvent event)
	{

	}

	@FXML
	void save(ActionEvent event)
	{

	}

	@FXML
	void save_as(ActionEvent event)
	{

	}

	@FXML
	void new_tab(ActionEvent event)
	{

	}

	@FXML
	void edit_settings(ActionEvent event)
	{

	}

	@FXML
	void run(ActionEvent event)
	{

	}

	@FXML
	void drag_drop(DragEvent event)
	{

	}

	@FXML
	void drag_over(DragEvent event)
	{

	}

	@FXML
	void canvas_click(MouseEvent event)
	{

	}


	@FXML
	void design(ActionEvent event)
	{

	}

	@FXML
	void do_playback_mode(ActionEvent event)
	{

	}

	@FXML
	void aa_add_all(ActionEvent event)
	{

	}

	@FXML
	void aa_toggle_panel(ActionEvent event)
	{

	}

	@FXML
	void show_data_sources(ActionEvent event)
	{

	}

	@FXML
	void hide_toolbox(ActionEvent event)
	{
		if (toolbox_status_visible == false)
		{
			return;
		}
		toolbox_status_visible = false;
		clickoff_tbx = null;
		toolbox_hider.setRate(-1);
		toolbox_hider.playFrom(toolbox_hider.getTotalDuration());
	}
}