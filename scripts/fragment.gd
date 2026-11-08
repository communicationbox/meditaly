class_name Fragment
extends RigidBody3D
## Pezzo di struttura staccato: corpo rigido reale. L'esito sul gioco lo decide il server.

var game: Node
var fid := 0
var age := 0.0
var first_hit := -1.0
var reported := false
var voxels: Dictionary = {}
var n := 0
var com := Vector3.ZERO
var coll_radius := 32.0


func setup(g: Node, id: int, data: PackedInt64Array) -> void:
	game = g
	fid = id
	var w: VoxelWorld = g.world
	for e in data:
		var p := w.pos_of(e >> Defs.EDIT_SHIFT)
		voxels[p] = e & Defs.EDIT_MASK
		com += Vector3(p) + Vector3(0.5, 0.5, 0.5)
	n = data.size()
	com /= n
	global_position = com
	coll_radius = 32.0 + pow(float(n), 0.4)
	w.activate_collision(com, coll_radius)
	freeze = not w.collision_ready(com, coll_radius)
	mass = clampf(n * 0.6, 4.0, 900.0)
	collision_layer = 2
	collision_mask = 3
	continuous_cd = n < 60
	contact_monitor = true
	max_contacts_reported = 2
	gravity_scale = 1.6
	# forme: griglia di scatole approssima la sagoma
	var cell := 3
	var cells := {}
	while true:
		cells.clear()
		for p: Vector3i in voxels:
			cells[Vector3i(p.x / cell, p.y / cell, p.z / cell)] = true
		if cells.size() <= 36:
			break
		cell *= 2
	for c: Vector3i in cells:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(cell, cell, cell) * 0.98
		cs.shape = box
		cs.position = (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cell - com
		add_child(cs)
	if DisplayServer.get_name() != "headless":
		var mi := MeshInstance3D.new()
		mi.mesh = VoxelWorld.mesh_fragment(voxels, com)
		mi.material_override = w.material
		add_child(mi)
	if not freeze:
		_kick()
	body_entered.connect(_on_hit)


## Rotazione iniziale: le torri devono ribaltarsi, non scendere dritte.
func _kick() -> void:
	var h := float(fid) * 12.9898
	angular_velocity = Vector3(sin(h) * 0.6, cos(h * 1.3) * 0.25, sin(h * 2.1) * 0.6)
	linear_velocity = Vector3(sin(h * 3.1), 0.2, cos(h * 1.7))


func _on_hit(_b: Node) -> void:
	if first_hit < 0.0:
		first_hit = age


func _physics_process(dt: float) -> void:
	if freeze:
		if game.world.collision_ready(com, coll_radius):
			freeze = false
			_kick()
		return
	age += dt
	if reported:
		return
	if global_position.y < Defs.SEA - 4.0 or age > 8.0 or (first_hit >= 0.0 and age > first_hit + 0.55):
		reported = true
		if game.is_server:
			game.sim.fragment_landed(fid, global_position)


func world_voxels_sample(count: int) -> Array:
	var out: Array = []
	var keys := voxels.keys()
	if keys.is_empty():
		return out
	var at := global_position
	var stepn := maxi(keys.size() / count, 1)
	var i := 0
	while i < keys.size() and out.size() < count:
		var p: Vector3i = keys[i]
		var rel := Vector3(p) - com
		out.append([at + global_transform.basis * rel, voxels[p]])
		i += stepn
	return out
