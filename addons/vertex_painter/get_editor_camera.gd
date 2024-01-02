@tool
extends Control

signal project_mouse
signal delete_debug_mesh
signal lock
signal bucket_fill
signal update_mesh_data

const NODE_3D_VIEWPORT_CLASS_NAME = "Node3DEditorViewport"
const SHADER_PATH = "res://addons/vertex_painter/shaders"

var _editor_interface : EditorInterface
var _editor_viewports : Array = []
var _editor_cameras : Array = []

## UI DEFAULTS

var _enable_painting := false
var _red := 1.0
var _green := 0.0
var _blue := 0.0
var _brush_size : int = 5

##

var _move_coloring := false
var _coloring = false
var _last_position := Vector2(0,0)

var _last_mesh_i : MeshInstance3D

var _mats = {}

func init(editor_interface : EditorInterface):
	_editor_interface = editor_interface
	_last_position = Vector2(0,0)

@onready var node_3d = $Node3D
@onready var active_mesh_instance = $ActiveMeshInstance
@onready var mesh_instance_path = $MeshInstancePath

func _ready():
	_find_viewports(_editor_interface.get_base_control())
	for v in _editor_viewports:
		_find_cameras(v)
	
	_coloring = false
	_move_coloring = false
	_mats = {}
	
	$EnablePaintingCheckBox.button_pressed = _enable_painting
	$RedLineEdit.text = str(_red)
	$GreenLineEdit.text = str(_green)
	$BlueLineEdit.text = str(_blue)
	$BrushSizeLineEdit.text = str(_brush_size)
	
	node_3d.connect("update_colors", _update_colors)

###

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

func _color(event):
	var camera = _editor_cameras[0]
	
	var offset = _editor_interface.get_editor_main_screen().global_position
	# the 30 is a magical offset number
	offset.y += 30
	#print(offset)
	var mouse_coords = event.position - offset
	var from = camera.project_ray_origin(mouse_coords)
	var to = from + camera.project_ray_normal(mouse_coords) * 1_000
	
	project_mouse.emit(from, to, _brush_size)
		
func _input(event):
	if event is InputEventMouseButton:
		var selection = _editor_interface.get_selection()
		if len(selection.get_selected_nodes()) > 0:
			var node = selection.get_selected_nodes()[0]
			if node is MeshInstance3D:
				_last_mesh_i = node
				active_mesh_instance.text = _last_mesh_i.name
	
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
				_color(event)
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
				
				_color(store_event)
				
				_move_coloring = false
		
		_last_position = event.position

func _update_mesh(mesh_i: MeshInstance3D, mdt: MeshDataTool):
	mesh_i.mesh.clear_surfaces()
	mdt.commit_to_surface(mesh_i.mesh)
	
	_notify_plugins(mesh_i, mdt)

func _notify_plugins(mesh_i: MeshInstance3D, mdt: MeshDataTool):
	var mi_id = mesh_i.get_instance_id()
	get_tree().call_group("vertex_painter", "_update_mesh_data", mi_id, mdt)
	
	get_tree().call_group("vertex_painter", "_update")

func _update_colors(mdt, idxs, mesh_i: MeshInstance3D):
	var color = Color(_red, _green, _blue)
	for idx in idxs:
		mdt.set_vertex_color(idx, color)

	_update_mesh(mesh_i, mdt)

func _set_vertex_color_mat(node: MeshInstance3D, nullmat = false):
	var mat : Material = node.get_surface_override_material(0)
	if mat != null:
		_mats[node.get_path()] = mat
	else:
		_mats[node.get_path()] = "nullmat"
	
	var material = load(SHADER_PATH + "/vertex_color.tres")		
	var shader = load(SHADER_PATH + "/vertex_color.gdshader")
	material.set_shader(shader)
	
	node.set_surface_override_material(0, material)

func _set_cached_material(node: MeshInstance3D):
	var mat = _mats[node.get_path()]
	if mat is String and mat == "nullmat":
		node.set_surface_override_material(0, null)
	else:
		node.set_surface_override_material(0, mat)
		_mats.erase(node.get_path())

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

func _bump_first_node3d(node):
	if node is Node3D:
		node.translate(Vector3(0, 0, 0))
	else:
		for child in node.get_children():
			_bump_first_node3d(child)

# ENABLE PAINTING
func _on_enable_painting_toggled(button_pressed):
	_enable_painting = button_pressed
	
	lock.emit(_editor_interface.get_edited_scene_root(), button_pressed)
	
	_bump_first_node3d(_editor_interface.get_edited_scene_root())
	
	if _enable_painting:
		_editor_interface.set_main_screen_editor("3D")

# BRUSH SIZE
func _on_brush_size_text_submitted(new_text):
	_brush_size = clampi(int(new_text), 1, 100)
	
	var line_edit = get_node("BrushSizeLineEdit")
	line_edit.text = str(_brush_size)

# BUCKET FILL
func _on_button_pressed():
	bucket_fill.emit(_last_mesh_i)

# VERTEX COLOR VISUALIZATION
func _on_toggle_vertex_color_pressed():
	var mat : Material = _last_mesh_i.get_surface_override_material(0)
	if mat != null:
		if mat.resource_path == SHADER_PATH + "/vertex_color.tres":
			_set_cached_material(_last_mesh_i)
		else:
			_set_vertex_color_mat(_last_mesh_i)
	else:
		_set_vertex_color_mat(_last_mesh_i, true)

# COPY VERTEX COLORS
func _on_copy_vertex_colorto_active_button_pressed():
	var mesh = load(mesh_instance_path.text)
	if mesh is Mesh:
		var active_mesh_i = _last_mesh_i
		var active_mdt = MeshDataTool.new()
		active_mdt.create_from_surface(active_mesh_i.mesh, 0)
		
		var mdt = MeshDataTool.new()
		mdt.create_from_surface(mesh, 0)
		
		for v in range(mdt.get_vertex_count()):
			active_mdt.set_vertex_color(v, mdt.get_vertex_color(v))
		
		update_mesh_data.emit(active_mesh_i.get_instance_id(), active_mdt)
		_update_mesh(active_mesh_i, active_mdt)
	else:
		printerr("Failed to load mesh from " + mesh_instance_path.text)
	pass # Replace with function body.

func _on_save_mesh_to_path_pressed():
	ResourceSaver.save(_last_mesh_i.mesh, mesh_instance_path.text)
