@tool
extends Node3D

# This node 3D is needed in order to get access to the world 3d
# communicates via signals to get_editor_camera.gd

@onready var _space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

signal update_colors

var _mesh_data_array := {}

func _ready():
	get_parent().connect("project_mouse", _color_mesh)
	get_parent().connect("lock", _lock)
	get_parent().connect("bucket_fill", _bucket_fill)
	get_parent().connect("update_mesh_data", _update_mesh_data)

func _update_mesh_data(mesh_id, mdt):
	# debug
	#print("Vertex tool updating mdt " + str(mesh_id))
	_mesh_data_array[mesh_id] = mdt

func _get_mdt(mesh_i: MeshInstance3D):
	var mesh_id := mesh_i.get_instance_id()
	if not _mesh_data_array.has(mesh_id):
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh_i.mesh, 0)
		_mesh_data_array[mesh_id] = mdt
	
	return _mesh_data_array[mesh_id]

func _bucket_fill(mesh_i: MeshInstance3D):
	var mdt = _get_mdt(mesh_i)
	update_colors.emit(mdt, range(mdt.get_vertex_count()), mesh_i)

func _lock(node, state):
	for child in node.get_children():
		if child is Node3D:
			if state == false:
				state = null
			child.set_meta("_edit_lock_", state)
			
		_lock(child, state)

func _color_mesh(from, to, n=1):
	var ray := PhysicsRayQueryParameters3D.create(
		from, to, 0x1)
	
	var hit := _space.intersect_ray(ray)
	if hit.is_empty(): return
	
	var mesh_i := _find_mesh(hit.collider)
	mesh_i.set_owner(get_tree().edited_scene_root)
	
	var m_origin = mesh_i.global_transform.origin
	var mdt = _get_mdt(mesh_i)
	var idxs = _get_n_closest_vertices(mdt, m_origin, hit.position, n)
	update_colors.emit(mdt, idxs, mesh_i)

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

func _process(delta):
	pass
