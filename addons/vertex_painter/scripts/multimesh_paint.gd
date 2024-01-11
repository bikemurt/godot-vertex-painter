@tool
extends MultiMeshInstance3D

@export_group("Spacing")

## Lock in the current multimesh locations.
@export var lock := false:
	get: return lock
	set(value):
		lock = value

## The max number of instances to render.
@export var hard_limit := 500:
	get: return hard_limit
	set(value):
		hard_limit = value
		_update()

## The number of generated instances.
@export var generated_count := 100:
	get: return generated_count
	set(value):
		generated_count = value
		# display only - do NOT update here (recursion)

## Spacing level, integer value from 0 to 10
@export var spacing := 0:
	get: return spacing
	set(value):
		spacing = clampi(value, 0, 1000)
		_update()

## The y distance above/below the multimesh to search for the terrain.
@export var search_y := 50.0:
	get: return search_y
	set(value):
		search_y = value
		_update()

## Set the terrain mesh instance target.
@export_node_path("MeshInstance3D") var terrain_mesh_instance:
	get: return terrain_mesh_instance
	set(value):
		terrain_mesh_instance = value

## Manually set the normal direction of mesh instances.
## If [code]custom_normal[/code] is set to (0,0,0) then the
## normal of the terrain will be used by default.
## [br][br] This vector is automatically normalized.
@export var custom_normal := Vector3(0.0, 0.0, 0.0):
	get: return custom_normal
	set(value):
		custom_normal = value
		_update()

## At a value of 1.0, instances will scale uniformly in X, Y and Z.
## Only the [code]Min Random Size[/code] and [code]Max Random Size[/code]
## X components will be used for scaling in X, Y and Z
## [br][br] At a value of 0.0, each axis is scaled individually.
## [br][br] Values in between are interpolated between these two extremes.
@export var scale_uniformity : float = 0.0:
	get: return scale_uniformity
	set(value):
		scale_uniformity = clampf(value, 0.0, 1.0)
		_update()

## The physics collision mask that the instances should collide with.
@export_flags_3d_physics var collision_mask := 0x1:
	get: return collision_mask
	set(value):
		collision_mask = value
		_update()

@export_group("Instance Placement")

@export_subgroup("Offset")

## Add an offset to the placed instances.
@export var offset_position := Vector3(0.0, 0.0, 0.0):
	get: return offset_position
	set(value):
		offset_position = value
		_update()

## Add a rotation offset to the placed instances.
@export var offset_rotation := Vector3(0.0, 0.0, 0.0):
	get: return offset_rotation
	set(value):
		offset_rotation = value
		_update()

## Change the base scale of the instanced meshes.
@export var base_scale := Vector3(1.0, 1.0, 1.0):
	get: return base_scale
	set(value):
		base_scale = value.clamp(Vector3.ONE * 0.01, Vector3.ONE * 100.0)
		_update()

@export_subgroup("Random Offset")

## Add an offset to the placed instances.
@export var random_offset_min := Vector3(-1.0, 0.0, -1.0):
	get: return random_offset_min
	set(value):
		random_offset_min = value
		_update()

## Add a rotation offset to the placed instances.
@export var random_offset_max := Vector3(1.0, 0.0, 1.0):
	get: return random_offset_max
	set(value):
		random_offset_max = value
		_update()

@export_subgroup("Random Size")

## The minimum random size for each instance.
@export var min_random_size := Vector3(0.75, 0.75, 0.75):
	get: return min_random_size
	set(value):
		min_random_size = value.clamp(Vector3.ONE * 0.01, Vector3.ONE * 100.0)
		_update()

## The maximum random size for each instance.
@export var max_random_size := Vector3(1.25, 1.25, 1.25):
	get: return max_random_size
	set(value):
		max_random_size = value.clamp(Vector3.ONE * 0.01, Vector3.ONE * 100.0)
		_update()

@export_subgroup("Random Rotation")

## Rotate each instance by a random amount between
## [code]-random_rotation[/code] and +[code]random_rotation[/code].
@export var random_rotation := Vector3(0.0, 0.0, 0.0):
	get: return random_rotation
	set(value):
		random_rotation = value.clamp(Vector3.ONE * 0.00, Vector3.ONE * 180.0)
		_update()

@export_group("Seed Settings")

## Click to randomize the seed.
@export var randomize_seed := false:
	get: return randomize_seed
	set(value):
		seed = randi()
		randomize_seed = false

## A seed to feed for the random number generator if randomize seed is false.
@export var seed := 0:
	get: return seed
	set(value):
		seed = value
		_rng.seed = value
		_update()

@export_group("Constraints")

@export_subgroup("Face Angle")

## If enabled the scattering will only happen where the collision angle is above the specified threshold.
## This has a non-negligible impact on scattering speed but no impact once the scattering is done.
## This will result in less instances than the set [code]count[/code].
## (Those instances are actually just scaled to 0)
@export var use_angle: bool = false:
	get: return use_angle
	set(value):
		use_angle = value
		_update()

## The minimum angle at which instances can be placed.
@export_range(0, 90, 1, "degrees") var angle_degrees := 90:
	get: return angle_degrees
	set(value):
		angle_degrees = value
		_update()

@export_subgroup("Vertex Color")

## Scatter threshold for the red channel.
@export_range(0, 1, 0) var r_channel = 1.0:
	get: return r_channel
	set(value):
		r_channel = value
		_update()

## Scatter threshold for the green channel.
@export_range(0, 1, 0) var g_channel = 1.0:
	get: return g_channel
	set(value):
		g_channel = value
		_update()

## Scatter threshold for the blue channel.
@export_range(0, 1, 0) var b_channel = 1.0:
	get: return b_channel
	set(value):
		b_channel = value
		_update()

var _mesh_data_array := {}
var _last_pos: Vector3
var _is_updating := false
var _updating_mdt := false
var _rng := RandomNumberGenerator.new()
var _primes := []

@onready var _space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

func _init() -> void:
	_ensure_has_mm()

func _ready() -> void:
	if not Engine.is_editor_hint():
		set_notify_transform(false)
		set_ignore_transform_notification(true)
	
	_load_primes()
	_update()

func _load_primes():
	var path := "res://addons/vertex_painter/scripts/primes.txt"
	var script_file = FileAccess.open(path, FileAccess.READ)
	
	var line = script_file.get_line()
	
	var primes = line.split(',')
	for p in primes:
		_primes.append(int(p))

func _notification(what: int) -> void:
	if !is_inside_tree(): return

	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			_update()

func _ensure_has_mm() -> bool:
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
	return multimesh.mesh != null

func _update() -> void:
	if !_space: return
	if not _is_updating:
		_is_updating = true
		
		await get_tree().create_timer(1.0).timeout
		
		# debug
		#print("scattering " + name)
		scatter()
		
		_is_updating = false

func _update_mesh_data(mesh_id, mdt):
	if not _updating_mdt:
		_updating_mdt = true
		
		await get_tree().create_timer(1.0).timeout
		
		# debug
		#print("updating mdt " + str(mesh_id))
		_mesh_data_array[mesh_id] = mdt
		
		_updating_mdt = false

func scatter() -> void:

	if lock:
		return

	if not _ensure_has_mm():
		printerr("[MultiMeshScatter]: The MultiMeshInstance3D doesn't have an assigned mesh.")
		return

	_rng.state = 0
	_rng.seed = seed

	multimesh.instance_count = 0
	
	var mesh_i : MeshInstance3D
	if terrain_mesh_instance != null:
		mesh_i = get_node(terrain_mesh_instance)
	else:
		# new version - run a single ray cast from above the multimesh
		# location downward to find the terrain
		var pos := global_position
		var ray := PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * search_y,
			pos + Vector3.DOWN * search_y,
			collision_mask)
		
		var hit := _space.intersect_ray(ray)
		if hit.is_empty():
			printerr("[multimesh_paint] No terrain was found")
			return
	
		mesh_i = _find_mesh(hit.collider)
	
	if not mesh_i:
		printerr("[multimesh_paint] No terrain mesh instance was found.")
		return
	
	var mesh_id := mesh_i.get_instance_id()
	if not _mesh_data_array.has(mesh_id):
		var mdt_temp := MeshDataTool.new()
		mdt_temp.create_from_surface(mesh_i.mesh, 0)
		_mesh_data_array[mesh_id] = mdt_temp

	var mdt : MeshDataTool = _mesh_data_array[mesh_id]

	# next extract all vertices matching color requirements
	var vert_positions = []
	var vert_normals = []
	var target_color = Color(r_channel, g_channel, b_channel)
	for v in range(mdt.get_vertex_count()):
		
		# density algorithm uses prime numbers
		var skip = false
		for p_index in range(spacing):
			var p = _primes[p_index]
			if v % p == 0: skip = true
		
		if skip: continue
		
		# Vertex color constraints
		var c : Color = mdt.get_vertex_color(v)
		var valid_color = (c.r * r_channel) + (c.g * g_channel) + (c.b * b_channel)
		if valid_color >= 0.1:
			var v_pos := mdt.get_vertex(v) + mesh_i.global_position
			var v_nrm := mdt.get_vertex_normal(v)
			
			# Angle constraints
			if use_angle:
				var off: float = rad_to_deg((abs(v_nrm.x) + abs(v_nrm.z)) / 2.0)
				if not off < angle_degrees:
					continue
			
			vert_positions.append(v_pos)
			vert_normals.append(v_nrm)
	
	var l = clampi(len(vert_positions), 0, hard_limit)
	
	multimesh.instance_count = l
	
	for i in range(l):
		var v_pos = vert_positions[i]
		var v_nrm = vert_normals[i]
		
		if not custom_normal.is_zero_approx():
			v_nrm = custom_normal.normalized()
		
		var t := Transform3D(
			Basis(
				v_nrm.cross(global_transform.basis.z),
				v_nrm,
				global_transform.basis.x.cross(v_nrm),
			).orthonormalized()
		)
		
		var scale_x := _rng.randf_range(min_random_size.x, max_random_size.x)
		var scale_y := _rng.randf_range(min_random_size.y, max_random_size.y)
		var scale_z := _rng.randf_range(min_random_size.z, max_random_size.z)

		# Change y and z scaling based on the x scaling, weighted by the scale uniformity factor
		scale_y = scale_uniformity * scale_x + (1.0 - scale_uniformity) * scale_y
		scale_z = scale_uniformity * scale_x + (1.0 - scale_uniformity) * scale_z
		
		var rand_scale = Vector3(scale_x, scale_y, scale_z)
		
		var rand_offset = Vector3(0,0,0)
		rand_offset.x += _rng.randf_range(random_offset_min.x, random_offset_max.x)
		rand_offset.y += _rng.randf_range(random_offset_min.y, random_offset_max.y)
		rand_offset.z += _rng.randf_range(random_offset_min.z, random_offset_max.z)
		
		# the random offset should be scaled by the scale amount
		v_pos += rand_offset# / rand_scale
		
		t = t\
			.scaled(base_scale)\
			.scaled(rand_scale)\
			.rotated(Vector3.RIGHT, deg_to_rad(_rng.randf_range(-random_rotation.x, random_rotation.x) + offset_rotation.x))\
			.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-random_rotation.y, random_rotation.y) + offset_rotation.y))\
			.rotated(Vector3.FORWARD, deg_to_rad(_rng.randf_range(-random_rotation.z, random_rotation.z) + offset_rotation.z))
		
		t.origin = v_pos - global_position + offset_position

		multimesh.set_instance_transform(i, t)
	
	generated_count = l

func _find_mesh(node: Node) -> MeshInstance3D:
	var p := node.get_parent()
	if p == null: return p
	return p if p is MeshInstance3D else _find_mesh(p)
