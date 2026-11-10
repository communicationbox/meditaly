class_name Fx
extends Node3D
## Effetti lato client: detriti, proiettili, frecce, forme di formaggio, cupole, scosse.

const MAX_DEBRIS := 2200
const GRAV := 30.0

var flying_king: Node3D = null  # il re in volo, seguito dall'inquadratura
var king_gone: Dictionary = {}  # castello -> fino a quando il gabinetto resta vuoto
var game: Node
var world: VoxelWorld
var sfx: Sfx
var dmm: MultiMesh
var dpos := PackedVector3Array()
var dvel := PackedVector3Array()
var dlife := PackedFloat32Array()
var dmaxl := PackedFloat32Array()
var dcol := PackedColorArray()
var dgrav := PackedFloat32Array()
var dsize := PackedFloat32Array()
var dn := 0
var projectiles: Dictionary = {}
var wheel_nodes: Dictionary = {}
var arrows: Array = []
var arrow_mm: MultiMesh
var shake := 0.0
var meshes: Dictionary = {}
var flash_pool: Array[OmniLight3D] = []
var flash_i := 0
var oils: Array = []
var quakes: Array = []
var models := UnitModels.new()


func setup(g: Node) -> void:
	game = g
	world = g.world
	sfx = Sfx.new()
	add_child(sfx)
	dpos.resize(MAX_DEBRIS); dvel.resize(MAX_DEBRIS); dlife.resize(MAX_DEBRIS); dmaxl.resize(MAX_DEBRIS)
	dcol.resize(MAX_DEBRIS); dgrav.resize(MAX_DEBRIS); dsize.resize(MAX_DEBRIS)
	dmm = MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.use_colors = true
	var box := BoxMesh.new()
	dmm.mesh = box
	dmm.instance_count = MAX_DEBRIS
	dmm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = dmm
	mi.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(Defs.WX + 200, 300, Defs.WZ + 200))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	# frecce
	arrow_mm = MultiMesh.new()
	arrow_mm.transform_format = MultiMesh.TRANSFORM_3D
	var ab := BoxMesh.new()
	ab.size = Vector3(0.09, 0.09, 1.3)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.2, 0.15, 0.1)
	ab.material = am
	arrow_mm.mesh = ab
	arrow_mm.instance_count = 400
	arrow_mm.visible_instance_count = 0
	var ami := MultiMeshInstance3D.new()
	ami.multimesh = arrow_mm
	ami.custom_aabb = mi.custom_aabb
	add_child(ami)
	for k in 8:
		var l := OmniLight3D.new()
		l.light_energy = 0.0
		l.omni_range = 26.0
		l.light_color = Color(1.0, 0.65, 0.3)
		add_child(l)
		flash_pool.append(l)
	var st := SphereMesh.new()
	st.radius = 0.8
	st.height = 1.6
	st.radial_segments = 6
	st.rings = 3
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.45, 0.43, 0.40)
	st.material = sm
	meshes[Defs.SHOT_STONE] = st
	var bm := SphereMesh.new()
	bm.radius = 0.55
	bm.height = 1.1
	var bmm := StandardMaterial3D.new()
	bmm.albedo_color = Color(0.12, 0.12, 0.14)
	bm.material = bmm
	meshes[Defs.SHOT_BALL] = bm
	var met := SphereMesh.new()
	met.radius = 2.2
	met.height = 4.4
	met.radial_segments = 8
	met.rings = 4
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1.0, 0.4, 0.1)
	mmat.emission_enabled = true
	mmat.emission = Color(1.0, 0.4, 0.08)
	mmat.emission_energy_multiplier = 4.0
	met.material = mmat
	meshes[Defs.SHOT_METEOR] = met
	meshes[Defs.SHOT_COW] = models.cow()
	var cowmat := StandardMaterial3D.new()
	cowmat.vertex_color_use_as_albedo = true
	cowmat.vertex_color_is_srgb = true
	meshes["cowmat"] = cowmat
	meshes["cheese"] = models.parmigiano(4.0)


func _spawn_debris(p: Vector3, v: Vector3, col: Color, life: float, grav := GRAV, size := 0.45) -> void:
	if dn >= MAX_DEBRIS:
		return
	var i := dn
	dn += 1
	dpos[i] = p
	dvel[i] = v
	dlife[i] = life
	dmaxl[i] = life
	dcol[i] = col
	dgrav[i] = grav
	dsize[i] = size


func debris_from_edits(edits: PackedInt64Array) -> void:
	var total := edits.size()
	if total == 0:
		return
	var stride := maxi(total / 90, 1)
	var i := 0
	var center := Vector3.ZERO
	var cnt := 0
	while i < total:
		var e: int = edits[i]
		i += stride
		if (e & Defs.EDIT_MASK) != 0:
			continue
		var idx: int = e >> Defs.EDIT_SHIFT
		var m: int = world.vox[idx]
		if m == 0:
			continue
		var pos: Vector3 = Vector3(world.pos_of(idx)) + Vector3(0.5, 0.5, 0.5)
		center += pos
		cnt += 1
		var c: Color = Defs.mat_color(m)
		var v := Vector3(randf_range(-7, 7), randf_range(4, 17), randf_range(-7, 7))
		_spawn_debris(pos, v, c, randf_range(1.4, 3.2), GRAV, randf_range(0.28, 0.75))


func debris_from_fragment(f: Fragment) -> void:
	var s := f.world_voxels_sample(120)
	for e: Array in s:
		var v := Vector3(randf_range(-9, 9), randf_range(3, 12), randf_range(-9, 9)) + f.linear_velocity * 0.25
		_spawn_debris(e[0], v, Defs.mat_color(e[1]), randf_range(1.5, 3.5), GRAV, randf_range(0.4, 0.95))
	for k in mini(f.n / 6, 26):
		var p := f.global_position + Vector3(randf_range(-4, 4), randf_range(-3, 3), randf_range(-4, 4))
		_spawn_debris(p, Vector3(randf_range(-3, 3), randf_range(3, 8), randf_range(-3, 3)), Color(0.74, 0.69, 0.6), randf_range(0.9, 2.0), -1.0, randf_range(0.5, 1.2))


func unit_died(u: Game.VU) -> void:
	var c: Color = Defs.HOUSES[u.team].color
	for k in 7:
		_spawn_debris(u.cur + Vector3(0, 1, 0), Vector3(randf_range(-4, 4), randf_range(3, 8), randf_range(-4, 4)), c if k % 2 == 0 else Color(0.5, 0.05, 0.04), randf_range(0.6, 1.3), GRAV, 0.26)
	if u.team >= 0 and randf() < 0.3:
		sfx.play("hit", u.cur, -12.0, 0.4)


func smoke(p: Vector3, radius: float, n: int) -> void:
	for k in n:
		var o := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)) * radius
		var g := randf_range(0.62, 0.84)
		_spawn_debris(p + o, Vector3(o.x, randf_range(2, 5), o.z), Color(g, g * 0.95, g * 0.86), randf_range(0.7, 1.7), -1.5, randf_range(0.45, 1.05))


func fire(p: Vector3, radius: float, n: int) -> void:
	for k in n:
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)).normalized()
		var col := Color(1.8, randf_range(0.6, 1.2), 0.1)
		_spawn_debris(p + dir, dir * randf_range(radius, radius * 3.0), col, randf_range(0.25, 0.65), 4.0, randf_range(0.5, 1.2))


func flash(p: Vector3, energy: float) -> void:
	var l := flash_pool[flash_i]
	flash_i = (flash_i + 1) % flash_pool.size()
	l.global_position = p + Vector3(0, 2, 0)
	l.light_energy = energy


func _shake_at(p: Vector3, amount: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(p)
	shake = maxf(shake, amount * clampf(1.0 - d / 240.0, 0.0, 1.0))


## Eventi di gioco trasmessi dal server.
func event(kind: String, p: Vector3, a: float) -> void:
	match kind:
		"say":
			_say(int(a) / 1000, (int(a) % 1000) / 50, int(a) % 50, p)
		"special":
			_special_fx(p, int(a))
		"say_name":
			var who := (int(a) / 1000) % 100
			var named: String = game.hud._display_name(who) if game and game.hud else ""
			_say(int(a) / 100000, (int(a) % 1000) / 50, int(a) % 50, p, named)
		"taunt":
			var cam := get_viewport().get_camera_3d()
			if cam:
				sfx.play("boing", cam.global_position - cam.global_basis.z * 6.0, 0.0, 0.15)
		"porchetta":
			_porchetta(p, a)
		"bell":
			sfx.play("bell", p, 8.0, 0.05)
		"dance":
			if game.renderer:
				# se c'è la scena del re, il ballo comincia quando si torna sul castello
				var extra: float = game.ctrl.CINE_END if game.ctrl and game.ctrl.cine_castle() >= 0 else 0.0
				game.renderer.dances.append([p, int(a), Time.get_ticks_msec() / 1000.0 + 7.0 + extra])
				if game.renderer.dances.size() > 6:
					game.renderer.dances.pop_front()
		"palio":
			_palio(p, a)
		"palio_end":
			if palio_node and is_instance_valid(palio_node):
				for k in 80:
					var col: Color = Defs.HOUSES[maxi(int(a), 0)].color if k % 2 == 0 and int(a) >= 0 else Color(1, 0.9, 0.4)
					_spawn_debris(p + Vector3(randf_range(-2, 2), 8, randf_range(-2, 2)), Vector3(randf_range(-9, 9), randf_range(6, 16), randf_range(-9, 9)), col, randf_range(0.8, 1.6), 16.0, 0.3)
				sfx.play("horn", p, 6.0, 0.0)
				var node := palio_node
				var tw := create_tween()
				tw.tween_interval(2.0)
				tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.4)
				tw.tween_callback(node.queue_free)
		"boom":
			smoke(p, a * 0.6, 12)
			fire(p, 2.0, 12)
			flash(p, 4.0)
			_shake_at(p, 0.45)
			sfx.play("boom", p)
		"boom_big":
			smoke(p, a * 0.7, 26)
			fire(p, 4.5, 30)
			flash(p, 9.0)
			_shake_at(p, 1.0)
			sfx.play("boom_big", p, 4.0)
		"moo":
			smoke(p, a * 0.5, 10)
			fire(p, 3.0, 16)
			for k in 18:
				_spawn_debris(p, Vector3(randf_range(-10, 10), randf_range(6, 20), randf_range(-10, 10)), Color(0.95, 0.94, 0.9) if k % 2 == 0 else Color(0.08, 0.08, 0.1), randf_range(1, 2.2), GRAV, 0.45)
			flash(p, 4.0)
			_shake_at(p, 0.5)
			sfx.play("moo", p, 3.0, 0.3)
			sfx.play("boom", p)
		"crash":
			smoke(p, a * 0.8, 14)
			_shake_at(p, 0.6)
			sfx.play("crash", p, 2.0)
		"ram":
			smoke(p, 1.5, 4)
			_shake_at(p, 0.2)
			sfx.play("crash", p, -3.0, 0.3)
		"hit":
			sfx.play("hit", p, -6.0, 0.4)
		"whoosh":
			sfx.play("whoosh", p, -2.0)
		"cannon":
			smoke(p, 1.0, 10)
			fire(p, 2.0, 8)
			flash(p, 3.0)
			sfx.play("cannon", p, 2.0)
		"splash":
			for k in 22:
				_spawn_debris(p, Vector3(randf_range(-5, 5), randf_range(5, 15), randf_range(-5, 5)), Color(0.75, 0.9, 1.0), randf_range(0.5, 1.2), GRAV, 0.35)
			sfx.play("hit", p, -6.0, 0.5)
		"oil":
			oils.append({"pos": p, "t": a})
			sfx.play("whoosh", p, 0.0, 0.5)
		"wine":
			for k in 60:
				var o := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * a
				_spawn_debris(p + o, Vector3(0, randf_range(3, 9), 0), Color(0.72, 0.1, 0.32), randf_range(0.8, 2.2), -2.0, randf_range(0.3, 0.7))
			sfx.play("boing", p, 2.0, 0.3)
		"quake":
			quakes.append({"pos": p, "t": a})
			sfx.play("quake", p, 8.0, 0.05)
		"dome":
			_add_dome(p, a)
		"dome_hit":
			fire(p, 3.0, 14)
			sfx.play("hit", p, 0.0, 0.3)
			flash(p, 3.0)
		"repair":
			for k in 3:
				_spawn_debris(p + Vector3(randf_range(-11, 11), randf_range(2, 10), randf_range(-11, 11)), Vector3(0, 3, 0), Color(1.0, 0.9, 0.4), 0.7, -1.0, 0.25)
		"build":
			for k in 4:
				_spawn_debris(p + Vector3(randf_range(-5, 5), randf_range(0, 2), randf_range(-5, 5)), Vector3(randf_range(-2, 2), 4, randf_range(-2, 2)), Color(0.85, 0.75, 0.55), 0.6, -1.0, 0.3)
		"capture":
			sfx.play("horn", p, 6.0, 0.0)
			for k in 60:
				var col: Color = Defs.HOUSES[randi() % Defs.HOUSE_COUNT].color
				_spawn_debris(p + Vector3(randf_range(-6, 6), 12, randf_range(-6, 6)), Vector3(randf_range(-10, 10), randf_range(4, 15), randf_range(-10, 10)), col, randf_range(1.4, 3), 16.0, 0.3)
		"king_dead":
			_king_dead(p, int(a))
		"victory":
			sfx.play("horn", p, 10.0, 0.0)


func _add_dome(p: Vector3, life: float) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 20.0
	sp.height = 40.0
	sp.radial_segments = 28
	sp.rings = 14
	mi.mesh = sp
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	float bands = 0.5 + 0.5 * sin(UV.y * 60.0 + TIME * 3.0);
	ALBEDO = vec3(1.0, 0.78, 0.3);
	ALPHA = rim * 0.5 + rim * bands * 0.1;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = p
	mi.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(life - 0.9, 0.0))
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(mi.queue_free)


func projectile_start(id: int, kind: int, p: Vector3, v: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[kind]
	if kind == Defs.SHOT_COW:
		mi.material_override = meshes["cowmat"]
		sfx.play("moo", p + Vector3(0, -40, 0), 2.0, 0.4)
	add_child(mi)
	mi.global_position = p
	projectiles[id] = {"node": mi, "pos": p, "vel": v, "kind": kind, "spin": Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))}


func projectile_end(id: int) -> void:
	var pr: Variant = projectiles.get(id)
	if pr == null:
		return
	projectiles.erase(id)
	(pr.node as Node).queue_free()


func update_wheels(data: PackedFloat32Array) -> void:
	var seen := {}
	var i := 0
	while i + 5 < data.size():
		var id := int(data[i])
		seen[id] = true
		var n: Dictionary = wheel_nodes.get(id, {})
		var p := Vector3(data[i + 1], data[i + 2], data[i + 3])
		if n.is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = meshes["cheese"]
			mi.material_override = meshes["cowmat"]
			add_child(mi)
			mi.global_position = p
			n = {"node": mi, "from": p, "to": p, "yaw": data[i + 4], "roll": data[i + 5], "t": 0.0, "last_y": p.y}
			wheel_nodes[id] = n
			sfx.play("boing", p, 6.0, 0.2)
		n.from = (n.node as Node3D).global_position
		n.to = p
		n.yaw = data[i + 4]
		n.roll = data[i + 5]
		n.t = 0.0
		if p.y - float(n.last_y) > 0.8:
			sfx.play("boing", p, 3.0, 0.3)
		n.last_y = p.y
		i += 6
	for id: int in wheel_nodes.keys():
		if not seen.has(id):
			(wheel_nodes[id].node as Node).queue_free()
			wheel_nodes.erase(id)


func add_arrows(data: PackedFloat32Array) -> void:
	var i := 0
	while i + 5 < data.size():
		var a := Vector3(data[i], data[i + 1], data[i + 2])
		var b := Vector3(data[i + 3], data[i + 4], data[i + 5])
		var dist := a.distance_to(b)
		arrows.append({"a": a, "b": b, "t": 0.0, "dur": maxf(dist / 55.0, 0.1)})
		i += 6
	if data.size() > 0 and randf() < 0.3:
		sfx.play("hit", Vector3(data[0], data[1], data[2]), -14.0, 0.5)


func _process(dt: float) -> void:
	_update_bubbles(dt)
	_update_debris(dt)
	_update_projectiles(dt)
	_update_wheels(dt)
	_update_arrows(dt)
	for l in flash_pool:
		if l.light_energy > 0.0:
			l.light_energy = maxf(l.light_energy - dt * 16.0, 0.0)
	shake = maxf(shake - dt * 2.2, 0.0)
	var i := oils.size() - 1
	while i >= 0:
		var o: Dictionary = oils[i]
		o.t -= dt
		for k in 3:
			var q: Vector3 = (o.pos as Vector3) + Vector3(randf_range(-6, 6), randf_range(0, 7), randf_range(-6, 6))
			_spawn_debris(q, Vector3(0, -4, 0), Color(1.5, randf_range(0.5, 0.9), 0.05), randf_range(0.3, 0.7), 10.0, randf_range(0.3, 0.6))
		if o.t <= 0.0:
			oils.remove_at(i)
		i -= 1
	i = quakes.size() - 1
	while i >= 0:
		var q: Dictionary = quakes[i]
		q.t -= dt
		_shake_at(q.pos, 0.75)
		for k in 4:
			var pos: Vector3 = (q.pos as Vector3) + Vector3(randf_range(-22, 22), 0, randf_range(-22, 22))
			pos.y = world.top_y(int(pos.x), int(pos.z))
			_spawn_debris(pos, Vector3(0, randf_range(1, 3), 0), Color(0.6, 0.5, 0.35), randf_range(0.6, 1.2), -0.5, randf_range(0.6, 1.3))
		if q.t <= 0.0:
			quakes.remove_at(i)
		i -= 1
	# bollicine dell'armata ubriaca
	var wine_budget := 6
	for u: Game.VU in game.vunits.values():
		if wine_budget <= 0:
			break
		if (u.flags & 8) != 0 and randf() < 0.05:
			wine_budget -= 1
			_spawn_debris(u.cur + Vector3(0, 2.4, 0), Vector3(randf_range(-0.5, 0.5), 2.2, randf_range(-0.5, 0.5)), Color(0.8, 0.15, 0.4), 0.8, -0.5, 0.2)


func _update_debris(dt: float) -> void:
	var i := 0
	var basis_i := Basis()
	while i < dn:
		dlife[i] -= dt
		if dlife[i] <= 0.0:
			dn -= 1
			dpos[i] = dpos[dn]; dvel[i] = dvel[dn]; dlife[i] = dlife[dn]; dmaxl[i] = dmaxl[dn]
			dcol[i] = dcol[dn]; dgrav[i] = dgrav[dn]; dsize[i] = dsize[dn]
			continue
		var v := dvel[i]
		v.y -= dgrav[i] * dt
		var p := dpos[i] + v * dt
		if dgrav[i] > 5.0 and v.y < 0.0:
			var ix := int(floor(p.x))
			var iy := int(floor(p.y))
			var iz := int(floor(p.z))
			if world.get_v(ix, iy, iz) != 0:
				p.y = iy + 1.02
				v.y *= -0.35
				v.x *= 0.55
				v.z *= 0.55
			elif p.y < Defs.SEA + 0.3:
				dlife[i] = 0.0
		dvel[i] = v
		dpos[i] = p
		var age := dlife[i] / dmaxl[i]
		var s := dsize[i] * minf(age * 3.0, 1.0)
		basis_i = Basis.from_euler(Vector3(dlife[i] * 5.0 + i, dlife[i] * 4.0, i * 0.7)).scaled(Vector3(s, s, s))
		dmm.set_instance_transform(i, Transform3D(basis_i, p))
		dmm.set_instance_color(i, dcol[i])
		i += 1
	dmm.visible_instance_count = dn


func _update_projectiles(dt: float) -> void:
	for id: int in projectiles:
		var pr: Dictionary = projectiles[id]
		var v: Vector3 = pr.vel
		var p: Vector3 = (pr.pos as Vector3) + v * dt + Vector3(0, -0.5 * Sim.GRAVITY * dt * dt, 0)
		v.y -= Sim.GRAVITY * dt
		pr.pos = p
		pr.vel = v
		var n: Node3D = pr.node
		n.global_position = p
		var sp: Vector3 = pr.spin
		n.rotate_x(sp.x * dt)
		n.rotate_y(sp.y * dt)
		n.rotate_z(sp.z * dt)
		if pr.kind == Defs.SHOT_METEOR:
			_spawn_debris(p, Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), Color(1.6, randf_range(0.4, 0.9), 0.08), randf_range(0.2, 0.45), -2.0, randf_range(0.4, 0.9))
			if randf() < 0.2:
				var g := randf_range(0.5, 0.7)
				_spawn_debris(p, Vector3(0, 2, 0), Color(g, g, g), randf_range(0.6, 1.2), -1.0, randf_range(0.5, 1.0))
		elif pr.kind == Defs.SHOT_STONE and randf() < 0.3:
			_spawn_debris(p, Vector3.ZERO, Color(0.75, 0.7, 0.62), 0.5, -1.0, 0.35)


func _update_wheels(dt: float) -> void:
	for id: int in wheel_nodes:
		var n: Dictionary = wheel_nodes[id]
		n.t = minf(float(n.t) + dt / 0.1, 1.0)
		var node: Node3D = n.node
		var pos := (n.from as Vector3).lerp(n.to, n.t)
		var b := Basis(Vector3.UP, float(n.yaw)) * Basis(Vector3.RIGHT, float(n.roll))
		node.global_transform = Transform3D(b, pos)
		if randf() < 0.5:
			_spawn_debris(pos + Vector3(randf_range(-2, 2), -3.2, randf_range(-2, 2)), Vector3(randf_range(-3, 3), randf_range(1, 6), randf_range(-3, 3)), Color(0.96, 0.85, 0.45), randf_range(0.4, 1.0), GRAV, 0.3)


func _update_arrows(dt: float) -> void:
	var i := arrows.size() - 1
	var c := 0
	while i >= 0:
		var a: Dictionary = arrows[i]
		a.t = float(a.t) + dt
		var f: float = float(a.t) / float(a.dur)
		if f >= 1.0:
			arrows.remove_at(i)
		elif c < 400:
			var from: Vector3 = a.a
			var to: Vector3 = a.b
			var pos := from.lerp(to, f) + Vector3(0, sin(f * PI) * 1.5, 0)
			var dir := to - from
			if dir.length() > 0.1:
				var b := Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
				arrow_mm.set_instance_transform(c, Transform3D(b, pos))
				c += 1
		i -= 1
	arrow_mm.visible_instance_count = c


## Re ucciso: a = vecchio padrone + 16 * chi l'ha ucciso. Chi è coinvolto se lo gode in primo piano.
func _king_dead(p: Vector3, a: int) -> void:
	var was := a % 16
	var by := (a / 16) % 16
	var variant := a / 256
	var cid := -1
	var bd := 1e9
	for c: Dictionary in game.castles:
		var d := (c.king as Vector3).distance_to(p)
		if d < bd:
			bd = d
			cid = c.id
	var delay := 0.0
	if cid >= 0 and game.my_house >= 0 and (game.my_house == was or game.my_house == by) and game.ctrl:
		game.ctrl.king_cinematic(game.castles[cid], was, variant)
		delay = game.ctrl.CINE_CLOSE
	if cid >= 0:
		king_gone[cid] = Time.get_ticks_msec() / 1000.0 + delay + 3.2
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_king_exits.bind(p, was, variant, cid))
	else:
		_king_exits(p, was, variant, cid)


## L'uscita di scena: il volo col gabinetto, o una delle altre.
func _king_exits(p: Vector3, house: int, variant: int, cid: int) -> void:
	if variant <= 0 or cid < 0:
		_king_flies(p, house)
		return
	var c: Dictionary = game.castles[cid]
	var col: Color = Defs.HOUSES[clampi(house, 0, Defs.HOUSES.size() - 1)].color
	var mi := MeshInstance3D.new()
	mi.mesh = UnitModels.new().re_scena(col, variant)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mi.material_override = mat
	add_child(mi)
	mi.scale = Vector3.ONE * 2.2
	flying_king = mi
	var gate: Vector3 = c.gate_out
	var dir: Vector3 = c.dir
	var ground := func(q: Vector3) -> float:
		return float(game.world.top_y(int(q.x), int(q.z)))
	var face := atan2(dir.x, dir.z)
	# quota addolcita: i gradini dei voxel e il muro del portone facevano saltare la telecamera
	var height: Array = [ground.call(gate + dir * 3.0)]
	var smooth := func(q: Vector3) -> float:
		var want: float = ground.call(q)
		if want - float(height[0]) < 3.0:
			height[0] = lerpf(float(height[0]), want, 0.2)
		return float(height[0])
	var dur := Controller.exit_time(variant)
	var side := Vector3(-dir.z, 0.0, dir.x)
	var extras: Array = []  # figure di contorno da togliere alla fine
	var extra_fig := func(m: Mesh, sc: float) -> MeshInstance3D:
		var n := MeshInstance3D.new()
		n.mesh = m
		n.material_override = mat
		add_child(n)
		n.scale = Vector3.ONE * sc
		extras.append(n)
		return n
	var tw := create_tween()
	match variant:
		1:  # la botte rotola fuori, si sfascia e lui riparte barcollando
			sfx.play("boing", gate, 4.0, 0.0)
			var end_roll := gate + dir * 49.0
			tw.tween_method(func(t: float) -> void:
				var q := gate + dir * (t * 46.0 + 3.0)
				mi.global_position = Vector3(q.x, smooth.call(q) + 1.8 + absf(sin(t * 12.0)) * 0.9, q.z)
				mi.rotation = Vector3(t * 20.0, face, 0.0), 0.0, 1.0, dur * 0.6)
			tw.tween_callback(func() -> void:
				sfx.play("crash", mi.global_position, 3.0, 0.1)
				smoke(mi.global_position, 2.0, 12)
				for k in 14:
					_spawn_debris(mi.global_position + Vector3(0, 2, 0), Vector3(randf_range(-9, 9), randf_range(7, 15), randf_range(-9, 9)), Color(0.55, 0.34, 0.16), 2.0)
				mi.mesh = UnitModels.new().re_ubriaco(col)
				_shout(mi, "Hic!", Color(0.72, 0.16, 0.5)))
			tw.tween_method(func(t: float) -> void:
				var q := end_roll + dir * (t * 9.0) + side * sin(t * 9.0) * 3.0
				mi.global_position = Vector3(q.x, smooth.call(q), q.z)
				mi.rotation = Vector3(0.0, face + sin(t * 9.0) * 0.7, sin(t * 11.0) * 0.26), 0.0, 1.0, dur * 0.4)
		2:  # il trono a molla lo spara in cielo; il trono resta sul mastio
			mi.mesh = UnitModels.new().re_volante(col)
			var throne := MeshInstance3D.new()
			throne.mesh = UnitModels.new().re_trono()
			throne.material_override = mat
			add_child(throne)
			throne.global_position = p + Vector3(0, WorldGen.KEEP_H + 2.0, 0)
			throne.rotation = Vector3(0.0, face, 0.0)
			throne.scale = Vector3.ONE * 2.2
			tw.finished.connect(throne.queue_free)
			sfx.play("boing", p, 8.0, 0.0)
			sfx.play("horn", p, 0.0, 0.3)
			if game.ctrl and game.ctrl.cine_castle() == cid:
				# chi guarda la scena lo segue fin lassù
				var roof := p + Vector3(0, WorldGen.KEEP_H + 2.0, 0)
				var top: Vector3 = game.ctrl.sky_king_end()
				var poses: Array = [UnitModels.new().re_volante(col, 0), UnitModels.new().re_volante(col, 1)]
				sfx.play_flat("scream", 2.0)
				var yell := Label3D.new()
				yell.text = "AAAAAH!"
				yell.font = UiStyle.comic_font()
				yell.font_size = 72
				yell.outline_size = 18
				yell.pixel_size = 0.00042
				yell.offset = Vector2(0, 90)  # sopra il re, sullo schermo: a qualunque distanza non lo copre
				yell.fixed_size = true
				yell.no_depth_test = true
				yell.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				yell.modulate = Color(0.78, 0.1, 0.08)
				yell.outline_modulate = Color(1, 0.97, 0.88)
				mi.add_child(yell)
				tw.tween_method(func(t: float) -> void:
					mi.global_position = roof.lerp(top, pow(t, 2.2))
					mi.mesh = poses[int(t * Controller.SKY_TIME * 9.0) % 2]
					yell.text = "A".repeat(4 + int(t * 5.0)) + "H!"
					mi.rotation = Vector3(t * 3.0, t * 6.0, sin(t * 11.0) * 0.5), 0.0, 1.0, Controller.SKY_TIME)
				tw.tween_callback(mi.queue_free)
				return
			var far := Vector3(dir.z, 0, -dir.x) * 70.0
			tw.tween_method(func(t: float) -> void:
				mi.global_position = p + far * t * t + Vector3(0, WorldGen.KEEP_H + 2.0 + 150.0 * t - 60.0 * t * t, 0)
				mi.rotation = Vector3(t * 2.0, t * 7.0, sin(t * 9.0) * 0.5), 0.0, 1.0, 2.4)
		3:  # la moglie se lo porta via per un orecchio, e lui saltella
			sfx.play("voice", gate, 6.0, 0.3)
			_shout(mi, "Ahi ahi ahi!", Color(0.78, 0.1, 0.08))
			tw.tween_method(func(t: float) -> void:
				var q := gate + dir * (t * 50.0 + 3.0)
				mi.global_position = Vector3(q.x, smooth.call(q) + absf(sin(t * 34.0)) * 0.7, q.z)
				mi.rotation = Vector3(0.0, face, sin(t * 34.0) * 0.1), 0.0, 1.0, dur)
		6:  # la mamma lo insegue col mestolo fino a sparire
			sfx.play("voice", gate, 6.0, 0.3)
			mi.mesh = UnitModels.new().re_scena(col, 6, false)
			var mum: MeshInstance3D = extra_fig.call(UnitModels.new().re_mamma(), 2.2)
			_shout(mum, "A casa!", Color(0.16, 0.26, 0.6))
			var mum_h: Array = [ground.call(gate)]
			tw.tween_method(func(t: float) -> void:
				var q := gate + dir * (t * 56.0 + 13.0)
				mi.global_position = Vector3(q.x, smooth.call(q) + absf(sin(t * 44.0)) * 0.6, q.z)
				mi.rotation = Vector3(0.14, face, sin(t * 44.0) * 0.08)
				var m := gate + dir * (t * 56.0 + 3.0)
				mum_h[0] = lerpf(float(mum_h[0]), float(ground.call(m)), 0.2)
				mum.global_position = Vector3(m.x, float(mum_h[0]) + absf(sin(t * 30.0)) * 0.4, m.z)
				mum.rotation = Vector3(sin(t * 26.0) * 0.16, face, 0.0), 0.0, 1.0, dur)
		4:  # rema fuori dal portone lungo un canale, poi la tinozza affonda con dignità
			mi.mesh = UnitModels.new().re_scena(col, 4, false)
			var oar := MeshInstance3D.new()
			oar.mesh = UnitModels.new().re_remo()
			oar.material_override = mat
			mi.add_child(oar)
			oar.position = Vector3(0.0, 1.16, 0.4)
			# il canale parte dal portone: altezza presa dal punto più alto del percorso
			const CANAL_LEN := 46.0
			var water_y := 0.0
			for k in 6:
				water_y = maxf(water_y, float(ground.call(gate + dir * (4.0 + k * 8.0))))
			var pool := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(17.0, 0.12, CANAL_LEN)
			pool.mesh = box
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.25, 0.58, 0.9)
			pool.material_override = pm
			add_child(pool)
			pool.global_position = Vector3(gate.x, water_y + 0.2, gate.z) + dir * (2.0 + CANAL_LEN * 0.5)
			pool.rotation = Vector3(0.0, face, 0.0)
			const ROW_END := 0.68  # poi smette di remare e affonda
			var duration: float = Controller.exit_time(4)
			tw.tween_method(func(t: float) -> void:
				var row := minf(t / ROW_END, 1.0)
				var sink := maxf(t - ROW_END, 0.0) / (1.0 - ROW_END)
				var q := gate + dir * (4.0 + row * 34.0)
				mi.global_position = Vector3(q.x, water_y + 0.2 - sink * sink * 5.0 + sin(t * 26.0) * 0.1, q.z)
				mi.rotation = Vector3(sin(t * 18.0) * 0.05 + sink * 0.4, face, sin(t * 24.0) * 0.09 + sink * 0.5)
				var stroke := sin(t * duration * 7.0) if row < 1.0 else 0.0
				oar.rotation = Vector3(0.0, stroke * 0.55, stroke * 0.28), 0.0, 1.0, duration)
			tw.tween_callback(pool.queue_free)
		5:  # giro del castello in camicia da notte, col cane ben staccato dietro: si guarda dall'alto
			sfx.play("voice", gate, 6.0, 0.3)
			mi.mesh = UnitModels.new().re_scena(col, 5, false)
			var pup: MeshInstance3D = extra_fig.call(UnitModels.new().re_cane(), 2.2)
			var yell_k := _shout(mi, "Aiuto!", Color(0.78, 0.1, 0.08))
			var yell_d := _shout(pup, "Bau!", Color(0.3, 0.18, 0.08))
			yell_d.visible = false  # all'uscita sono vicini: le due scritte si accavallerebbero
			var center: Vector3 = c.center
			var ring: float = Sim.R + 20.0
			var a0 := atan2(dir.z, dir.x)
			var ring_p := center + Vector3(cos(a0), 0.0, sin(a0)) * ring
			const RUN_OUT := 0.2  # fino a qui corre dritto fuori dal portone
			const LAPS := 1.3
			const DOG_LAG := 0.1  # il cane esce dopo e resta ben staccato
			# dove si trova chi corre, alla frazione s del percorso
			var along := func(s: float) -> Array:
				if s < RUN_OUT:
					return [gate.lerp(ring_p, s / RUN_OUT), dir]
				var ang := a0 + TAU * LAPS * (s - RUN_OUT) / (1.0 - RUN_OUT)
				return [center + Vector3(cos(ang), 0.0, sin(ang)) * ring, Vector3(-sin(ang), 0.0, cos(ang))]
			var place := func(n: Node3D, s: float, hop: float, sc: float) -> void:
				var r: Array = along.call(s)
				var q: Vector3 = r[0]
				var d: Vector3 = r[1]
				n.global_position = Vector3(q.x, float(ground.call(q)) + hop, q.z)
				n.rotation = Vector3(0.1, atan2(d.x, d.z), 0.0)
				n.scale = Vector3.ONE * sc
			pup.visible = false
			tw.tween_method(func(t: float) -> void:
				var sc := lerpf(2.2, 4.2, smoothstep(0.26, 0.5, t))  # dall'alto si devono vedere
				place.call(mi, t, absf(sin(t * 110.0)) * 0.8, sc)
				yell_k.scale = Vector3.ONE * (1.6 / sc)  # le figure ingrandite non devono gonfiare le scritte
				yell_d.scale = Vector3.ONE * (1.6 / sc)
				yell_d.visible = t >= 0.3
				pup.visible = t >= DOG_LAG
				if pup.visible:
					place.call(pup, t - DOG_LAG, absf(sin(t * 130.0)) * 0.6, sc), 0.0, 1.0, dur)
		7:  # lo starnuto è già avvenuto nella sala: qui corre fuori in boxer
			mi.mesh = UnitModels.new().re_boxer()
			_shout(mi, "Non guardate!", Color(0.78, 0.1, 0.08))
			tw.tween_method(func(t: float) -> void:
				var q := gate + dir * (t * 56.0 + 3.0)
				mi.global_position = Vector3(q.x, smooth.call(q) + absf(sin(t * 36.0)) * 0.7, q.z)
				mi.rotation = Vector3(0.1, face, sin(t * 36.0) * 0.1), 0.0, 1.0, dur)
		8:  # senza corona, a testa bassa, con una nuvoletta che piove solo su di lui
			mi.mesh = UnitModels.new().re_scena(col, 8, false)
			var cloud: MeshInstance3D = extra_fig.call(UnitModels.new().re_nuvola(), 2.0)
			var drop_mat := StandardMaterial3D.new()
			drop_mat.albedo_color = Color(0.45, 0.68, 0.98)
			drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var drops: Array = []
			for k in 9:
				var dr := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(0.08, 0.36, 0.08)
				dr.mesh = bx
				dr.material_override = drop_mat
				cloud.add_child(dr)
				drops.append(dr)
			_shout(cloud, "Sigh", Color(0.3, 0.3, 0.42))
			tw.tween_method(func(t: float) -> void:
				var q := gate + dir * (t * 19.0 + 3.0)
				var y: float = smooth.call(q)
				mi.global_position = Vector3(q.x, y + absf(sin(t * 18.0)) * 0.14, q.z)
				mi.rotation = Vector3(0.26, face, sin(t * 18.0) * 0.03)
				cloud.global_position = Vector3(q.x, y + 9.5, q.z)
				for k in drops.size():
					var ph := fposmod(t * dur * 2.6 + float(k) * 0.37, 1.0)
					(drops[k] as Node3D).position = Vector3(-0.9 + float(k) * 0.22, -ph * 3.4, sin(float(k) * 2.1) * 0.34), 0.0, 1.0, dur)
		9:  # il rotolo del conto si srotola a perdita d'occhio e lui sviene
			var at := gate + dir * 10.0
			at.y = ground.call(at)
			mi.mesh = UnitModels.new().re_scena(col, 9, false)
			mi.global_position = at
			mi.rotation = Vector3(0.0, face, 0.0)
			var clerk: MeshInstance3D = extra_fig.call(UnitModels.new().re_ragioniere(), 2.2)
			clerk.global_position = at + side * 4.0
			clerk.rotation = Vector3(0.0, face, 0.0)
			_shout(clerk, "Questo è solo gennaio", Color(0.16, 0.16, 0.22))
			var paper := MeshInstance3D.new()
			var pbox := BoxMesh.new()
			pbox.size = Vector3(2.4, 0.08, 1.0)
			paper.mesh = pbox
			var pm2 := StandardMaterial3D.new()
			pm2.albedo_color = Color(0.95, 0.9, 0.74)
			paper.material_override = pm2
			add_child(paper)
			extras.append(paper)
			paper.rotation = Vector3(0.0, face, 0.0)
			var from := at + side * 2.0 + dir * 2.0 + Vector3(0, 0.4, 0)
			tw.tween_method(func(t: float) -> void:
				var l := 2.0 + 96.0 * minf(t / 0.62, 1.0)
				paper.scale.z = l
				paper.global_position = from + dir * (l * 0.5)
				mi.rotation = Vector3(-smoothstep(0.62, 0.78, t) * PI * 0.5, face, 0.0), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		smoke(mi.global_position, 2.0, 10)
		mi.queue_free()
		for n: Node in extras:
			if is_instance_valid(n):
				n.queue_free())




## Il nome del potere che sale dal punto colpito.
func _special_fx(p: Vector3, house: int) -> void:
	sfx.play("boing", p, 5.0, 0.1)
	smoke(p + Vector3(0, 2, 0), 2.0, 10)
	var l := Label3D.new()
	l.text = String(Defs.HOUSE_POWERS[clampi(house, 0, Defs.HOUSE_POWERS.size() - 1)].name) + "!"
	l.font = UiStyle.comic_font()
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.0006
	l.fixed_size = true
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Defs.HOUSES[clampi(house, 0, Defs.HOUSES.size() - 1)].color.lerp(Color.BLACK, 0.2)
	l.outline_modulate = Color(1, 0.97, 0.88)
	add_child(l)
	l.global_position = p + Vector3(0, 8, 0)
	var tw := create_tween()
	tw.tween_property(l, "global_position", p + Vector3(0, 22, 0), 2.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(1.8)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.8).set_delay(1.8)
	tw.tween_callback(l.queue_free)


## Scritta che resta sopra una figura, a qualunque distanza si guardi.
func _shout(n: Node3D, text: String, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UiStyle.comic_font()
	l.font_size = 72
	l.outline_size = 18
	l.pixel_size = 0.00042
	l.position = Vector3(0, 3.4, 0)  # sopra la testa
	l.fixed_size = true
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_modulate = Color(1, 0.97, 0.88)
	n.add_child(l)
	return l


## Il re ucciso schizza fuori dal tetto del mastio, gabinetto compreso, girando su se stesso.
func _king_flies(p: Vector3, house: int) -> void:
	sfx.play("boing", p, 6.0, 0.0)
	sfx.play("horn", p, 0.0, 0.3)
	var mi := MeshInstance3D.new()
	mi.mesh = UnitModels.new().re(Defs.HOUSES[clampi(house, 0, Defs.HOUSES.size() - 1)].color, false)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mi.material_override = mat
	add_child(mi)
	mi.global_position = p
	mi.scale = Vector3.ONE * 2.2
	flying_king = mi
	var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 40.0
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		# parte dal tetto del mastio (il buco da cui esce), sale e ricade lontano
		mi.global_position = p + side * t + Vector3(0, WorldGen.KEEP_H + 2.0 + 50.0 * t - 40.0 * t * t, 0)
		mi.rotation = Vector3(t * 9.0, t * 13.0, t * 5.0), 0.0, 1.6, 2.4)
	tw.chain().tween_callback(func() -> void:
		smoke(mi.global_position, 2.0, 10)
		mi.queue_free())
	for k in 30:
		_spawn_debris(p + Vector3(0, 18, 0), Vector3(randf_range(-6, 6), randf_range(8, 18), randf_range(-6, 6)), Color(0.97, 0.97, 0.95), randf_range(0.5, 1.0), 6.0, 0.6)


# ---------------------------------------------------------------- fumetti e sagre
const MAX_BUBBLES := 2
## Fra un fumetto e l'altro, e prima che la stessa frase torni: meglio poche battute ma lette.
var bubble_cooldown := 5.0
var bubble_repeat := 150.0
var _bubble_wait := 0.0
var _bubble_seen := {}  # testo -> istante in cui si potrà ripetere
const BUBBLE_GAP := 4.0
const BUBBLE_MAX_PUSH := 130.0
var bubbles: Array = []
var bubble_layer: CanvasLayer


## Fumetto sopra il soldato che parla: segue l'unità, entra con un piccolo salto e sfuma.
## Solo se è in vista e non troppo lontano, altrimenti nessuno lo legge comunque.
func _say(id: int, cat: int, line: int, p: Vector3, named := "") -> void:
	if cat < 0 or cat >= Defs.SAY.size():
		return
	var lines: Array = Defs.SAY[cat]
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(p) or cam.global_position.distance_to(p) > 190.0:
		return
	var sp := cam.unproject_position(p)
	var vs := get_viewport().get_visible_rect().size
	if sp.x < -40 or sp.y < -40 or sp.x > vs.x + 40 or sp.y > vs.y + 40:
		return
	var text := String(lines[line % lines.size()]).format({"n": named})
	var now := Time.get_ticks_msec() / 1000.0
	if cat != Defs.SAY_SFOTTO:  # gli sfottò li manda chi gioca: quelli passano sempre
		var waiting := now < _bubble_wait and named == ""  # le frasi col tuo nome saltano la fila
		if waiting or (bubbles.size() >= MAX_BUBBLES and named == "") or now < float(_bubble_seen.get(text, 0.0)):
			return
	_bubble_wait = now + bubble_cooldown
	_bubble_seen[text] = now + bubble_repeat
	while bubbles.size() >= MAX_BUBBLES:
		(bubbles.pop_front().node as Node).queue_free()
	if bubble_layer == null:
		bubble_layer = CanvasLayer.new()
		bubble_layer.layer = 0  # sotto l'interfaccia, sopra il mondo
		add_child(bubble_layer)
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiStyle.comic_font())
	l.add_theme_font_size_override("font_size", 20)
	var ink: Color = Defs.SAY_COLORS[cat]
	l.add_theme_color_override("font_color", ink)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.82, 0.42, 0.97) if cat == Defs.SAY_SFOTTO else Color(0.99, 0.95, 0.84, 0.97)
	sb.border_color = ink.darkened(0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(2, 3)
	l.add_theme_stylebox_override("normal", sb)
	bubble_layer.add_child(l)
	l.size = l.get_combined_minimum_size()
	l.pivot_offset = l.size * 0.5
	l.rotation = randf_range(-0.04, 0.04)  # storti quanto basta, come in una striscia
	l.visible = false  # lo posiziona _update_bubbles, così non compare per un frame nell'angolo
	sfx.play("voice", p, 0.0, 0.3)
	bubbles.append({"node": l, "id": id, "t": 0.0, "pos": p, "off": NAN, "life": 2.6 + l.text.length() * 0.03})


## Impagina i fumetti sullo schermo, in pixel: i più vecchi restano sopra la testa di chi parla,
## i nuovi salgono finché trovano posto. Se dovrebbero salire troppo restano nascosti.
func _update_bubbles(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if bubble_layer:
		bubble_layer.visible = game == null or game.ctrl == null or game.ctrl.cine_castle() < 0
	var vs := get_viewport().get_visible_rect().size
	var placed: Array[Rect2] = []
	var k := 0
	while k < bubbles.size():
		var b: Dictionary = bubbles[k]
		var l: Label = b.node
		b.t = float(b.t) + dt
		var t: float = b.t
		if t >= float(b.life):
			l.queue_free()
			bubbles.remove_at(k)
			continue
		k += 1
		var u = game.vunits.get(int(b.id)) if game else null
		if u != null:
			b.pos = u.cur
		var head: Vector3 = (b.pos as Vector3) + Vector3(0, 3.6, 0)
		if cam == null or cam.is_position_behind(head):
			l.visible = false
			continue
		var sp := cam.unproject_position(head)
		var sz := l.size
		var base_y := clampf(sp.y - sz.y, 8.0, maxf(vs.y - sz.y - 8.0, 8.0))
		var r := Rect2(clampf(sp.x - sz.x * 0.5, 8.0, maxf(vs.x - sz.x - 8.0, 8.0)), base_y, sz.x, sz.y)
		var moved := true
		var guard := 0
		while moved and guard < 16:
			moved = false
			guard += 1
			for o: Rect2 in placed:
				if r.grow(BUBBLE_GAP * 0.5).intersects(o.grow(BUBBLE_GAP * 0.5)):
					r.position.y = o.position.y - sz.y - BUBBLE_GAP
					moved = true
		if base_y - r.position.y > BUBBLE_MAX_PUSH or r.position.y < 0.0:
			l.visible = false
			continue
		placed.append(r)
		var want := r.position.y - base_y
		b.off = want if is_nan(float(b.off)) else lerpf(float(b.off), want, minf(dt * 16.0, 1.0))
		l.position = Vector2(r.position.x, base_y + float(b.off))
		l.visible = true
		l.scale = Vector2.ONE * (1.0 + 0.25 * maxf(0.0, 1.0 - t / 0.18))
		l.modulate.a = clampf((float(b.life) - t) / 0.4, 0.0, 1.0)


func _pbox(root: Node3D, sz: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	root.add_child(mi)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


## Banco della porchetta: tavolo, maiale allo spiedo che gira, insegna e fumo. Poi sparisce.
func _porchetta(p: Vector3, life: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	var wood := _mat(Color(0.45, 0.28, 0.14))
	var pink := _mat(Color(0.92, 0.6, 0.55))
	var crust := _mat(Color(0.66, 0.34, 0.12))
	var cloth := _mat(Color(0.85, 0.12, 0.1))
	_pbox(root, Vector3(6, 0.3, 2.4), Vector3(0, 1.4, 0), cloth)
	for x: float in [-2.7, 2.7]:
		for z: float in [-1.0, 1.0]:
			_pbox(root, Vector3(0.3, 1.4, 0.3), Vector3(x, 0.7, z), wood)
	for x: float in [-3.4, 3.4]:
		_pbox(root, Vector3(0.3, 4.2, 0.3), Vector3(x, 2.1, 0), wood)
	_pbox(root, Vector3(7.4, 0.15, 0.15), Vector3(0, 4.0, 0), wood)
	var spit := Node3D.new()
	spit.position = Vector3(0, 4.0, 0)
	root.add_child(spit)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 1.0
	cm.height = 4.4
	body.mesh = cm
	body.material_override = crust
	body.rotation = Vector3(0, 0, PI / 2)
	spit.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.5
	head.mesh = sm
	head.material_override = pink
	head.position = Vector3(2.4, 0.1, 0)
	spit.add_child(head)
	for z: float in [-0.45, 0.45]:
		_pbox(spit, Vector3(0.3, 0.5, 0.35), Vector3(2.5, 0.85, z), pink)
	var apple := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = 0.32
	am.height = 0.64
	apple.mesh = am
	apple.material_override = _mat(Color(0.9, 0.1, 0.08))
	apple.position = Vector3(3.15, -0.05, 0)
	spit.add_child(apple)
	var sign := Label3D.new()
	sign.text = "PORCHETTA\ngratis!"
	sign.font = UiStyle.title_font()
	sign.font_size = 64
	sign.outline_size = 14
	sign.modulate = Color(1.0, 0.85, 0.35)
	sign.outline_modulate = Color(0.25, 0.08, 0.02)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.016
	sign.position = Vector3(0, 9.5, 0)
	root.add_child(sign)
	sfx.play("horn", p, 4.0, 0.0)
	root.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var spin := create_tween().set_loops(int(life / 1.6) + 1)
	spin.tween_property(spit, "rotation:x", TAU, 1.6).from(0.0)
	var smoke_t := create_tween().set_loops(int(life / 0.7))
	smoke_t.tween_callback(func(): smoke(p + Vector3(randf_range(-1, 1), 4.5, 0), 0.6, 2)).set_delay(0.7)
	var end := create_tween()
	end.tween_interval(life)
	end.tween_property(root, "scale", Vector3.ONE * 0.01, 0.5)
	end.tween_callback(func():
		spin.kill()
		smoke_t.kill()
		root.queue_free())


## Traguardo del Palio: pali, drappo a scacchi che sventola, scritta. Sparisce a fine corsa.
var palio_node: Node3D
func _palio(p: Vector3, life: float) -> void:
	if palio_node and is_instance_valid(palio_node):
		palio_node.queue_free()
	var root := Node3D.new()
	add_child(root)
	root.global_position = p
	palio_node = root
	var wood := _mat(Color(0.45, 0.28, 0.14))
	for x: float in [-4.0, 4.0]:
		_pbox(root, Vector3(0.4, 9.0, 0.4), Vector3(x, 4.5, 0), wood)
	var cloth := Node3D.new()
	cloth.position = Vector3(0, 8.0, 0)
	root.add_child(cloth)
	var white := _mat(Color(0.95, 0.95, 0.9))
	var black := _mat(Color(0.1, 0.08, 0.08))
	for i in 8:
		for j in 3:
			_pbox(cloth, Vector3(1.0, 0.8, 0.12), Vector3(-3.5 + i, -j * 0.8, 0), white if (i + j) % 2 == 0 else black)
	var sign := Label3D.new()
	sign.text = "TRAGUARDO"
	sign.font = UiStyle.title_font()
	sign.font_size = 64
	sign.outline_size = 14
	sign.modulate = Color(1.0, 0.85, 0.35)
	sign.outline_modulate = Color(0.25, 0.08, 0.02)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.016
	sign.position = Vector3(0, 11.0, 0)
	root.add_child(sign)
	root.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wave := create_tween().set_loops(int(life / 1.2) + 1)
	wave.tween_property(cloth, "rotation:x", 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	wave.tween_property(cloth, "rotation:x", -0.15, 0.6).set_trans(Tween.TRANS_SINE)
	var end := create_tween()
	end.tween_interval(life)
	end.tween_callback(func():
		wave.kill()
		if is_instance_valid(root):
			root.queue_free())
