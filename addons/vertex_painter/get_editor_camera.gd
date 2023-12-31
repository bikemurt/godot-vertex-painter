@tool
extends Control

signal project_mouse
signal delete_debug_mesh
signal lock
signal bucket_fill

const NODE_3D_VIEWPORT_CLASS_NAME = "Node3DEditorViewport"
const SHADER_PATH = "res://addons/vertex_painter/shaders"

var _editor_interface : EditorInterface
var _editor_viewports : Array = []
var _editor_cameras : Array = []

var _debug_mesh := false

var _red := 1.0
var _green := 1.0
var _blue := 1.0

var _enable_painting := false
var _brush_size : int = 5
var _move_coloring := false
var _coloring = false
var _last_position := Vector2(0,0)

var _last_3d_node : Node3D

var _mats = {}

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
		
		project_mouse.emit(from, to, node, _brush_size, _debug_mesh)
		
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

func _update_mesh(mesh_i: MeshInstance3D, mdt: MeshDataTool):
	mesh_i.mesh.clear_surfaces()
	mdt.commit_to_surface(mesh_i.mesh)
	
	get_tree().call_group("vertex_painter", "_update")
	
	var mi_id = mesh_i.get_instance_id()
	get_tree().call_group("vertex_painter", "_update_mesh_data", mi_id, mdt)


func _update_colors(mdt, idxs, mesh_i: MeshInstance3D):
	var color = Color(_red, _green, _blue)
	for idx in idxs:
		mdt.set_vertex_color(idx, color)

	_update_mesh(mesh_i, mdt)

###   UI   ###

# SHOW COLORS
func _on_check_box_toggled(button_pressed):
	if _last_3d_node is MeshInstance3D:
		var mesh = _last_3d_node.mesh
		var id = mesh.get_instance_id()
		
		if button_pressed:
			if id not in _mats:
				var mat : Material = _last_3d_node.get_surface_override_material(0)
				if mat != null:
					_mats[id] = mat.resource_path

			var material = load(SHADER_PATH + "/vertex_color.tres")		
			var shader = load(SHADER_PATH + "/vertex_color.gdshader")
			material.set_shader(shader)
			
			_last_3d_node.set_surface_override_material(int(0), material)
		else:
			if _last_3d_node.get_surface_override_material(0) == null:
				return
			if id in _mats:
				var mat = load(_mats[id])
				_last_3d_node.set_surface_override_material(int(0), mat)
				_mats.erase(id)
			else:
				_last_3d_node.set_surface_override_material(0, null)
				printerr("failed to revert material for " + str(_last_3d_node))
			
# DEBUG MESH
func _on_check_box_toggled2(button_pressed):
	_debug_mesh = button_pressed
	if not button_pressed:
		delete_debug_mesh.emit()

# R, G, B INPUTS
func _on_line_edit_text_submitted(new_text, color):
	var val = clampf(float(new_text), 0, 1)
	if color == "Red":
		_red = val
	if color == "Green":
		_green = val
	if color == "Blue":
		_blue = val
	
	var line_edit = get_node(color + "LineEdit")
	line_edit.text = str(val)

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

# BUCKET FILL
func _on_button_pressed():
	if _last_3d_node is MeshInstance3D:
		bucket_fill.emit(_last_3d_node)
