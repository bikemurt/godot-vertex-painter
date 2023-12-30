@tool
extends Control

signal mouse_3d
signal delete_debug_mesh
signal lock

const NODE_3D_VIEWPORT_CLASS_NAME = "Node3DEditorViewport"
const MAT_CACHE = "res://addons/vertex_painter/mat_cache"
const SHADER_PATH = "res://addons/vertex_painter/shaders"

var _editor_interface : EditorInterface
var _editor_viewports : Array = []
var _editor_cameras : Array = []

var _debug_mesh := false
var _color_vals := {
	"Red": 1.0,
	"Green": 1.0,
	"Blue": 1.0
}
var _enable_painting := false
var _brush_size : int = 5
var _move_coloring := false
var _coloring = false
var _last_position := Vector2(0,0)

var _last_3d_node : Node3D

func init(editor_interface : EditorInterface):
	_editor_interface = editor_interface
	_last_position = Vector2(0,0)

@onready var node_3d = $Node3D
func _ready():
	_find_viewports(_editor_interface.get_base_control())
	for v in _editor_viewports:
		_find_cameras(v)
	
	node_3d.connect("update_colors", _update_colors)

func _find_viewports(n : Node):
	if n.get_class() == NODE_3D_VIEWPORT_CLASS_NAME:
		_editor_viewports.append(n)
	
	for c in n.get_children():
		_find_viewports(c)


func _find_cameras(n : Node):
	if n is Camera3D:
		_editor_cameras.append(n)
		return
	
	for c in n.get_children():
		_find_cameras(c)

func color(event):
	var selection = _editor_interface.get_selection()
	if len(selection.get_selected_nodes()) == 0: return
	var node = selection.get_selected_nodes()[0]
	if node is Node3D:
		var camera = _editor_cameras[0]
		
		var offset = _editor_interface.get_editor_main_screen().global_position
		# the 30 is a magical offset number
		offset.y += 30
		#print(offset)
		var mouse_coords = event.position - offset
		var from = camera.project_ray_origin(mouse_coords)
		var to = from + camera.project_ray_normal(mouse_coords) * 1_000
		
		mouse_3d.emit(from, to, node, _brush_size, _debug_mesh)
		
func _input(event):
	if event is InputEventMouseButton:
		var selection = _editor_interface.get_selection()
		if len(selection.get_selected_nodes()) > 0:
			var node = selection.get_selected_nodes()[0]
			if node is Node3D:
				_last_3d_node = node
	
	if not _enable_painting: return
	
	# capture left button mouse click and start coloring
	if event is InputEventMouseButton:
		var ms = _editor_interface.get_editor_main_screen()
		var pos = ms.global_position
		if event.position.x < pos.x or \
			event.position.y < pos.y + 30 or \
			event.position.x > pos.x + ms.size.x or \
			event.position.y > pos.y + ms.size.y:
				return
		
		if event.button_index == 1:
			if event.pressed:
				color(event)
				_coloring = true
			else:
				_coloring = false
				get_tree().call_group("vertex_painter", "_update()")
			
			_move_coloring = false
	
	# if coloring, continue to coloring while mouse is moving
	if event is InputEventMouse:
		if event.position != _last_position:
			if _coloring and not _move_coloring:
				_move_coloring = true
				var store_event = event
				
				# this buffers the calls to "color" by a small amount
				# should help paint strokes be more even
				await get_tree().create_timer(0.01).timeout
				
				color(store_event)
				
				_move_coloring = false
		
		_last_position = event.position

func _update_colors(mdt, idxs, mesh_i: MeshInstance3D):
	var red = _color_vals["Red"]
	var green = _color_vals["Green"]
	var blue = _color_vals["Blue"]
	var color = Color(red, green, blue)
	for idx in idxs:
		mdt.set_vertex_color(idx, color)

	mesh_i.mesh.clear_surfaces()
	mdt.commit_to_surface(mesh_i.mesh)
	
	get_tree().call_group("vertex_painter", "_update")
	
	var mi_id = mesh_i.get_instance_id()
	get_tree().call_group("vertex_painter", "_update_mesh_data", mi_id, mdt)


###   UI   ###

# SHOW COLORS
func _on_check_box_toggled(button_pressed):
	if _last_3d_node is MeshInstance3D:
		var mesh = _last_3d_node.mesh
		var id = mesh.get_instance_id()
		
		var cache_path = MAT_CACHE + "/m_" + str(id) + ".tres"
		var da = DirAccess.open(MAT_CACHE)
		if button_pressed:
			if not da.file_exists(cache_path):
				var current_mat : Material = _last_3d_node.get_surface_override_material(0)
				ResourceSaver.save(current_mat, cache_path)
			
			var material = load(SHADER_PATH + "/vertex_color.tres")		
			var shader = load(SHADER_PATH + "/vertex_color.gdshader")
			material.set_shader(shader)
			
			_last_3d_node.set_surface_override_material(int(0), material)
		else:
			if da.file_exists(cache_path):
				var prev_mat = load(cache_path)
				_last_3d_node.set_surface_override_material(int(0), prev_mat)
			else:
				printerr("cached material for " + str(_last_3d_node) + " does not exist")

# DEBUG MESH
func _on_check_box_toggled2(button_pressed):
	_debug_mesh = button_pressed
	if not button_pressed:
		delete_debug_mesh.emit()

# R, G, B INPUTS
func _on_line_edit_text_submitted(new_text, color):
	_color_vals[color] = clampf(float(new_text), 0, 1)
	
	var line_edit = get_node(color + "LineEdit")
	line_edit.text = str(_color_vals[color])

# ENABLE PAINTING
func _on_enable_painting_toggled(button_pressed):
	_enable_painting = button_pressed
	
	lock.emit(_editor_interface.get_edited_scene_root(), button_pressed)
	
	if _enable_painting:
		_editor_interface.set_main_screen_editor("3D")

# BRUSH SIZE
func _on_brush_size_text_submitted(new_text):
	_brush_size = clampi(int(new_text), 1, 100)
	
	var line_edit = get_node("BrushSizeLineEdit")
	line_edit.text = str(_brush_size)
