@tool
extends EditorPlugin

var dock

func _enter_tree():
	dock = preload("res://addons/vertex_painter/vertex_painter.tscn").instantiate()
	
	var ei = get_editor_interface()
	dock.init(ei)
	
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, dock)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()
