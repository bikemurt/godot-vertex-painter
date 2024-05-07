@tool
extends EditorPlugin

#var dock
const MAIN_SCREEN = preload("res://addons/vertex_painter/v2/vertex_painter.tscn")

var main_panel_instance: VertexPainter

func _enter_tree():
	main_panel_instance = MAIN_SCREEN.instantiate()
	
	main_panel_instance.set_interface(get_editor_interface())
	main_screen_changed.connect(main_panel_instance.set_screen_name)
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UR, main_panel_instance)
	
	
func _exit_tree():
	remove_control_from_docks(main_panel_instance)
	main_panel_instance.free()
