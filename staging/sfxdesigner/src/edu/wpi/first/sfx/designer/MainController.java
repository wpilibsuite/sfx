/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package edu.wpi.first.sfx.designer;

import dashfx.controls.DataAnchorPane;
import dashfx.lib._private.rt._Canvas_blork;
import dashfx.lib.registers.ControlRegister;
import dashfx.lib.util.CTView;
import dashfx.lib.util.ControlTree;
import dashfx.lib.util.DemoImpl;
import dashfx.lib.util.DesignerMetadata;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ResourceBundle;
import java.util.stream.Collectors;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.scene.control.ListView;
import javafx.scene.control.SplitPane;
import javafx.scene.control.TreeItem;
import javafx.scene.control.TreeView;
import javafx.scene.input.*;

/**
 * load empty tree model
 * load jruby
 * load plugins
 * load controls
 * 
 * 
 * 
 */

/**
 *
 * @author patrick
 */
public class MainController implements Initializable
{

	@FXML
	private TreeView tree;
	@FXML
	private SplitPane par;
	@FXML
	private ListView<Class> list;
	private ControlTree ti;
	private ObservableList<Class> listi;
	private DemoImpl infl;
	private CTView aCanvas;
	private DesignerMetadata meta;
	
	@FXML
	void odd(DragEvent e)
	{
		System.out.println("completes! " + this.toString() + " .. " + e.toString() + " ??? " + e.isDropCompleted());
		tree.setRoot(remap(ti)); // TODO: observable
	}

	@FXML
	void grabItem2(MouseEvent event)
	{
		Dragboard db = list.startDragAndDrop(TransferMode.COPY);
		ClipboardContent content = new ClipboardContent();
		content.put(DataFormat.lookupMimeType("application/x-java-class"), list.getSelectionModel().getSelectedItem());
		db.setContent(content);
		event.consume();
	}

	@Override
	public void initialize(URL url, ResourceBundle rb)
	{
		infl = new DemoImpl();
		try
		{
			meta = new DesignerMetadata(new _Canvas_blork(), infl, new URL("file:/home/patrick/NetBeansProjects/sfx/lib/res/DesignerOverlayControl.fxml")); // the root
		}
		catch (MalformedURLException ex)
		{
			throw new RuntimeException(ex);
		}
		listi = FXCollections.observableArrayList(ControlRegister.getAll());
		list.setItems(listi);
		ti = meta.getRoot();
		tree.setRoot(remap(ti));
		par.getItems().add(1, meta.getAssociatedView(ti));
		infl.runService();
	}

	private TreeItem<String> remap(ControlTree ti)
	{
		TreeItem<String> treeItem = new TreeItem<>(ti.getControlType().getName());
		treeItem.getChildren().addAll(ti.getChildren().stream().map(child -> remap(child)).collect(Collectors.toList()));
		return treeItem;
	}

}
