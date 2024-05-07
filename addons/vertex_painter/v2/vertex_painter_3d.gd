@tool
extends Node3D

const VERTEX_COLOR = preload("res://addons/vertex_painter/shaders/vertex_color.tres")

@onready var enable_check_box = $"../VBoxContainer/EnableCheckBox"
@onready var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
@onready var color_picker = $"../VBoxContainer/ColorPicker"
@onready var brush_line_edit = $"../VBoxContainer/BrushLineEdit"
@onready var mouse_camera_3d: Camera3D = $"../SubViewport/MouseCamera3D"
@onready var sub_viewport = $"../SubViewport"
@onready var debug: MeshInstance3D = $"../Debug"
@onready var show_debug_check_box = $"../VBoxContainer/ShowDebugCheckBox"

var editor_interface: EditorInterface
var screen := ""
var mesh_i: MeshInstance3D = null
var error := false
var click_active := false
var active_mdt := MeshDataTool.new()
var pre_mat
var brush_size := 1
var working := false

func set_interface(_editor_interface: EditorInterface) -> void:
	editor_interface = _editor_interface

func set_screen_name(_screen: String) -> void:
	screen = _screen

func err(message: String) -> void:
	print("Vertex painter [ERROR]: " + message)

func msg(message: String) -> void:
	print("Vertex painter [INFO]: " + message)

# OLD ALGORITHM
func click_raycast():
	var viewport = editor_interface.get_editor_viewport_3d(0)
	var mouse_pos = viewport.get_mouse_position()
	var camera = viewport.get_camera_3d()
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 100
	
	var rayQuery := PhysicsRayQueryParameters3D.new()
	rayQuery.from = from
	rayQuery.to = to
	
	var result = space.intersect_ray(rayQuery)
	return result

# NEW ALGORITHM - Does not require a collider
func click_raycast2(offset := Vector2(0,0)) -> Vector3:
	var viewport = editor_interface.get_editor_viewport_3d(0)
	var mouse_pos = viewport.get_mouse_position() + offset
	var camera = viewport.get_camera_3d()
	
	#var from = camera.project_ray_origin(mouse_pos)
	#var to = from + camera.project_ray_normal(mouse_pos) * 2.0
	
	var src_pos: Vector3 = camera.project_ray_origin(mouse_pos)
	#var src_pos: Vector3 = from
	var direction: Vector3 = camera.project_ray_normal(mouse_pos).normalized()
	#var direction: Vector3 = from.direction_to(to)
	
	mouse_camera_3d.global_position = src_pos - direction
	
	var point: Vector3
	if is_zero_approx((direction - Vector3(0, -1, 0)).length_squared()):
		mouse_camera_3d.rotation_degrees = Vector3(-90, 0, 0)
		point = src_pos
	else:
		mouse_camera_3d.look_at(mouse_camera_3d.global_position + direction, Vector3.UP)
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var vp_tex: ViewportTexture = sub_viewport.get_texture()
		var vp_img := vp_tex.get_image()
		
		var screen_depth = vp_img.get_pixel(0, 0).srgb_to_linear()
		
		var screen_rg = Vector2(screen_depth.r, screen_depth.g)
		var normalized_distance: float = screen_rg.dot(Vector2(1, 1.0 / 255.0))
		#print(normalized_distance)
		if (is_zero_approx(normalized_distance)):
			return Vector3(-INF, -INF, -INF)
		
		if (normalized_distance > 0.9999):
			normalized_distance = 1.0
		
		var depth: float = normalized_distance * mouse_camera_3d.far
		point = mouse_camera_3d.global_position + direction * depth
	
	debug.global_position = point
	return point

func start_paint(event: InputEvent) -> void:
	mouse_camera_3d.show()
	if show_debug_check_box.button_pressed:
		debug.show()
	mesh_i.set_meta("_edit_lock_", true)
	mouse_camera_3d.show()
	
	var click_location := click_raycast2()
	if click_location.is_finite():
		#print(click_location)
		active_mdt.create_from_surface(mesh_i.mesh, 0)
		mesh_i.mesh = ArrayMesh.new()
		active_mdt.commit_to_surface(mesh_i.mesh)
		pre_mat = mesh_i.get_surface_override_material(0)
		mesh_i.set_surface_override_material(0, VERTEX_COLOR)
		process_move(event)
		click_active = true

func start_paint_legacy(event: InputEvent) -> void:
	mesh_i.create_trimesh_collision()
	mesh_i.get_children()[0].hide()
	mesh_i.set_meta("_edit_lock_", true)
	
	var click_location = click_raycast()
	if click_location:
		active_mdt.create_from_surface(mesh_i.mesh, 0)
		mesh_i.mesh = ArrayMesh.new()
		active_mdt.commit_to_surface(mesh_i.mesh)
		pre_mat = mesh_i.get_surface_override_material(0)
		mesh_i.set_surface_override_material(0, VERTEX_COLOR)
		process_move(event)
		click_active = true

func stop_paint() -> void:
	mouse_camera_3d.hide()
	debug.hide()
	if pre_mat == null:
		pre_mat = VERTEX_COLOR
		mesh_i.set_surface_override_material(0, pre_mat)
	
	mesh_i.set_meta("_edit_lock_", false)
	
	# legacy - remove static body children
	#for c in mesh_i.get_children():
	#	c.queue_free()
	
	click_active = false

func process_click(event: InputEvent) -> void:
	var mb_event: InputEventMouseButton = event

	if mb_event.button_index == 1:
		
		# get first mesh instanced selected node
		var nodes := editor_interface.get_selection().get_selected_nodes()
		mesh_i = null
		for n in nodes:
			if n is MeshInstance3D:
				mesh_i = n
				break
		
		if mesh_i and mesh_i.name == "Debug":
			mesh_i = null
		
		error = false
		if mesh_i == null:
			err("You must select a MeshInstance3D to vertex paint.")
			error = true
		if len(nodes) > 1:
			err("Only select one mesh instance in the scene tree for painting.")
			error = true
		
		if not error:
			if mb_event.pressed:
				start_paint(event)
			
			if not mb_event.pressed:
				stop_paint()

func paint() -> void:
		var result2 = click_raycast2()
		if result2.is_finite():
			var vertices := get_n_closest_vertices(active_mdt, mesh_i.global_position, \
				result2, brush_size)
			for idx in vertices:
				active_mdt.set_vertex_color(idx, color_picker.color)
				mesh_i.mesh.clear_surfaces()
				active_mdt.commit_to_surface(mesh_i.mesh)

func legacy_paint() -> void:
	var result = click_raycast()
	if "position" in result:
		var vertices := get_n_closest_vertices(active_mdt, mesh_i.global_position, \
			result.position, brush_size)
		for idx in vertices:
			active_mdt.set_vertex_color(idx, color_picker.color)
			mesh_i.mesh.clear_surfaces()
			active_mdt.commit_to_surface(mesh_i.mesh)

func process_move(event: InputEvent) -> void:
	if not working:
		working = true
		
		paint()
		
		# STATIC MESH LEGACY
		#legacy_paint()
		
		await get_tree().create_timer(0.05).timeout
		working = false
	
func get_n_closest_vertices(mdt: MeshDataTool, mesh_pos: Vector3, \
	hit_pos: Vector3, n: int) -> Array[int]:
	
	var vertices := []
	for v in range(mdt.get_vertex_count()):
		var v_pos := mdt.get_vertex(v) + mesh_pos
		var dist := hit_pos.distance_squared_to(v_pos)
		
		if len(vertices) < n:
			# fill with the first n vertices
			vertices.append([v, dist])
		else:
			# after array fill, determine if largest should be replaced
			var changes := []
			var furthest_dist := 0
			var furthest_index := -1
			for index in range(len(vertices)):
				var vertex: Variant = vertices[index]
				var dist_2: float = vertex[1]
				
				if dist_2 > furthest_dist:
					furthest_dist = dist_2
					furthest_index = index
			
			# largest element gets kicked out for this one
			if dist < furthest_dist:
				vertices[furthest_index] = [v, dist]
	
	# extract indices (idx)
	var v_indices: Array[int] = []
	for vertex in vertices:
		v_indices.append(vertex[0])
	return v_indices

func get_closest_vertex(mdt: MeshDataTool, mesh_pos: Vector3, hit_pos: Vector3) -> int:
	var closest_dist := INF
	var closest_index := -1
	for v in range(mdt.get_vertex_count()):
		var v_pos := mdt.get_vertex(v) + mesh_pos
		var dist := hit_pos.distance_squared_to(v_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_index = v
	
	return closest_index

func set_brush_size() -> void:
	var brush_s = brush_line_edit.text
	
	var brush_s_f = float(brush_s)
	
	brush_size = int(round(brush_s_f))
	
	brush_line_edit.text = str(brush_size)
	msg("Brush size = " + str(brush_size))

func _ready() -> void:
	set_brush_size()

func _input(event: InputEvent) -> void:
	if not enable_check_box.button_pressed: return
	
	if screen != "3D": return
	
	if not (event is InputEventMouseButton) and \
		not (event is InputEventMouseMotion): return
	
	# check within viewport bounds
	var evnp: Vector2 = event.position
	var scrn := editor_interface.get_editor_main_screen()
	var s_pos := scrn.global_position
	var s_size := scrn.size
	if evnp.x > s_pos.x \
		and evnp.y > s_pos.y + 30 \
		and evnp.x < s_pos.x + s_size.x \
		and evnp.y < s_pos.y + s_size.y:
		if event is InputEventMouseButton:
			process_click(event)
			
		if event is InputEventMouseMotion:
			if click_active and not error:
				process_move(event)
		
func _on_brush_line_edit_text_submitted(new_text):
	set_brush_size()

func _on_brush_line_edit_focus_exited():
	set_brush_size()
