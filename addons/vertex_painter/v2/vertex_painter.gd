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

func _on_enable_check_box_pressed():
	if enable_check_box.button_pressed:
		editor_interface.set_main_screen_editor("Script")
		editor_interface.set_main_screen_editor("3D")
