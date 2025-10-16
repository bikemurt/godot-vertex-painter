@tool
extends CenterContainer
class_name VertexPainter

@onready var vertex_painter_3d = $VertexPainter3D
@onready var enable_check_box = $VBoxContainer/EnableCheckBox

var editor_interface: EditorInterface

func set_interface(_editor_interface: EditorInterface) -> void:
	editor_interface = _editor_interface

func set_screen_name(_screen: String) -> void:
	vertex_painter_3d.set_screen_name(_screen)

func _ready():
	vertex_painter_3d.set_interface(editor_interface)

func _enter_tree() -> void:
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)

func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_selection_changed)

func _selection_changed() -> void:
	vertex_painter_3d.disable()
	enable_check_box.button_pressed = false

func _on_enable_check_box_pressed():
	var target = find_target()
	
	if enable_check_box.button_pressed:
		if !is_instance_valid(target):
			enable_check_box.button_pressed = false
			vertex_painter_3d.err("You must select a MeshInstance3D to vertex paint.")
			return
		editor_interface.set_main_screen_editor("Script")
		editor_interface.set_main_screen_editor("3D")
		vertex_painter_3d.enable(target)
	else:
		vertex_painter_3d.disable()

func find_target() -> MeshInstance3D:
	var nodes := editor_interface.get_selection().get_selected_nodes()
	for n in nodes:
		if n is MeshInstance3D:
			return n
	return null

func is_enabled() -> bool:
	return enable_check_box.button_pressed
