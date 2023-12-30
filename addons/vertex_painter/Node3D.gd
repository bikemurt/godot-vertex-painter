@tool
extends Node3D

# This node 3D is needed in order to get access to the world 3d
# communicates via signals to get_editor_camera.gd

@onready var _space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

var _mesh_data_array := {}

signal update_colors

func _ready():
	get_parent().connect("mouse_3d", calc_hit)
	get_parent().connect("delete_debug_mesh", delete_debug_mesh)
	get_parent().connect("lock", lock)

func lock(node, state):
	for child in node.get_children():
		if child is Node3D:
			if state == false:
				state = null
			child.set_meta("_edit_lock_", state)
			
		lock(child, state)

var m : MeshInstance3D = null
func calc_hit(from, to, active_node: Node3D, n=1, debug=false):
	var ray := PhysicsRayQueryParameters3D.create(
		from, to, 0x1)
	
	var hit := _space.intersect_ray(ray)
	if hit.is_empty(): return
	
	var mesh_i := _find_mesh(hit.collider)
	mesh_i.set_owner(get_tree().edited_scene_root)
	
	var mesh_id := mesh_i.get_instance_id()
	if not _mesh_data_array.has(mesh_id):
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh_i.mesh, 0)
		_mesh_data_array[mesh_id] = mdt
	
	var m_origin = mesh_i.global_transform.origin
	var mdt = _mesh_data_array[mesh_id]
	var idxs = _get_n_closest_vertices(mdt, m_origin, hit.position, n)
	update_colors.emit(mdt, idxs, mesh_i)
	
	if debug:
		if m == null:
			m = MeshInstance3D.new()
			m.name = "DebugMesh"
			m.mesh = BoxMesh.new()
			active_node.get_parent().add_child(m)
			m.set_owner(get_tree().edited_scene_root)
			
		m.position = hit.position

func _find_mesh(node: Node) -> MeshInstance3D:
	var p := node.get_parent()
	if p == null: return p
	return p if p is MeshInstance3D else _find_mesh(p)

func _get_n_closest_vertices(mdt: MeshDataTool, mesh_pos: Vector3, hit_pos: Vector3, n: int):
	var vertices = []
	for v in range(mdt.get_vertex_count()):
		var v_pos := mdt.get_vertex(v) + mesh_pos
		var dist = hit_pos.distance_squared_to(v_pos)
		
		if len(vertices) < n:
			# fill with the first n vertices
			vertices.append([v, dist])
		else:
			# after array fill, determine if largest should be replaced
			var changes = []
			var furthest_dist = 0
			var furthest_index = -1
			for index in range(len(vertices)):
				var vertex = vertices[index]
				var dist_2 = vertex[1]
				
				if dist_2 > furthest_dist:
					furthest_dist = dist_2
					furthest_index = index
			
			# largest element gets kicked out for this one
			if dist < furthest_dist:
				vertices[furthest_index] = [v, dist]
	
	# extract indices (idx)
	var v_indices = []
	for vertex in vertices:
		v_indices.append(vertex[0])
	return v_indices
	
func delete_debug_mesh():
	if m != null:
		m.get_parent().remove_child(m)
		m = null

func _process(delta):
	pass
