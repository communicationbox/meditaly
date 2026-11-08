class_name UnitRenderer
extends Node3D
## Disegna centinaia di soldati con MultiMesh; l'animazione è nel vertex shader.

const UNIT_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert;
uniform vec3 team_colors[9];
varying vec3 v_col;
void vertex() {
	float part = floor(UV.x * 10.0 + 0.5);
	float pivot = UV.y;
	float phase = INSTANCE_CUSTOM.r;
	float moving = INSTANCE_CUSTOM.g;
	float attack = INSTANCE_CUSTOM.b;
	float info = INSTANCE_CUSTOM.a;
	float drunk = step(10.0, info);
	int team = int(info - 10.0 * drunk + 0.5);
	float t = TIME * 11.0 + phase;
	float ang = 0.0;
	if (part == 1.0) ang = sin(t) * 0.75 * moving;
	else if (part == 2.0) ang = -sin(t) * 0.75 * moving;
	else if (part == 3.0) ang = -sin(t) * 0.5 * moving;
	else if (part == 4.0) ang = sin(t) * 0.5 * moving + attack * (sin(TIME * 12.0 + phase) * 1.0 - 0.7);
	else if (part == 6.0) ang = -attack * max(0.0, sin(TIME * 3.0 + phase)) * 1.5;
	vec3 v = VERTEX;
	if (part == 6.0) { v.z -= 0.35; }
	if (ang != 0.0) {
		float c = cos(ang), s = sin(ang);
		float y = v.y - pivot;
		v.y = pivot + y * c - v.z * s;
		v.z = y * s + v.z * c;
		float ny = NORMAL.y * c - NORMAL.z * s;
		NORMAL.z = NORMAL.y * s + NORMAL.z * c;
		NORMAL.y = ny;
	}
	if (part == 5.0) { v.z += attack * sin(TIME * 7.0 + phase) * 0.8; }
	// parte 8: la bandierina del re, sventolata a destra e sinistra attorno alla spalla
	if (part == 8.0 || part == 9.0) {
		float a8 = (0.25 + 0.75 * attack) * sin(TIME * 9.0 + phase) * 0.55;
		vec2 q = v.xy - vec2(0.5, pivot);
		float c8 = cos(a8), s8 = sin(a8);
		v.xy = vec2(0.5, pivot) + vec2(q.x * c8 - q.y * s8, q.x * s8 + q.y * c8);
		// il panno (parte 9) sbatte in profondità, di più verso la punta
		if (part == 9.0) { v.z += sin(TIME * 14.0 + v.x * 6.0 + phase) * 0.07 * max(v.x - 0.5, 0.0) * 2.0; }
	}
	if (part == 7.0) { v.x += sin(TIME * 5.0 + VERTEX.x * 3.0 + phase) * 0.06 * (VERTEX.x + 1.0); }
	v.y += abs(sin(t)) * 0.09 * moving;
	if (drunk > 0.5) {
		v.x += sin(TIME * 3.0 + phase) * v.y * 0.2;
		v.z += cos(TIME * 2.3 + phase) * v.y * 0.1;
	}
	VERTEX = v;
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	if (COLOR.a < 0.5) {
		c *= pow(team_colors[team], vec3(2.2));
	}
	v_col = c;
}
void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.25;
}
"""

const BOAT := Defs.UNIT_TYPES
const MAX_PER := 700

var game: Node
var mm: Array[MultiMesh] = []
var counts: Array[int] = []
var ring_mm: MultiMesh
var bar_mm: MultiMesh
var king_mm: MultiMesh  # un re per castello, sul gabinetto nel mastio
var worker_mm: Array[MultiMesh] = []  # personaggi delle botteghe, uno per tipo di edificio
var pip_mm: MultiMesh  # da lontano: rombo sopra ogni soldato, visibile anche tra gli alberi
var selected: Dictionary = {}
## Balli di vittoria in corso: [centro, casata, fino a quando]. Solo grafica, lato client.
var dances: Array = []
var unit_meshes: Array[ArrayMesh] = []
var unit_material: ShaderMaterial


func setup(g: Node) -> void:
	game = g
	var m := UnitModels.new()
	var meshes: Array[ArrayMesh] = [m.fante(), m.balestriere(), m.cavaliere(), m.ariete(), m.catapulta(), m.bombarda(), m.frate(), m.nonna(), m.menestrello(), m.barca()]
	var sh := Shader.new()
	sh.code = UNIT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var colors := PackedVector3Array()
	for h: Dictionary in Defs.HOUSES:
		var c: Color = h.color
		colors.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("team_colors", colors)
	unit_meshes = meshes
	unit_material = mat
	for mesh in meshes:
		var mu := MultiMesh.new()
		mu.transform_format = MultiMesh.TRANSFORM_3D
		mu.use_custom_data = true
		mu.mesh = mesh
		mu.instance_count = MAX_PER
		mu.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mu
		mi.material_override = mat
		mi.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(Defs.WX + 200, 200, Defs.WZ + 200))
		add_child(mi)
		mm.append(mu)
		counts.append(0)
	king_mm = MultiMesh.new()
	king_mm.transform_format = MultiMesh.TRANSFORM_3D
	king_mm.use_custom_data = true
	king_mm.mesh = m.re()
	king_mm.instance_count = maxi(game.castles.size(), 1)
	var kmi := MultiMeshInstance3D.new()
	kmi.multimesh = king_mm
	kmi.material_override = mat
	kmi.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(Defs.WX + 200, 200, Defs.WZ + 200))
	add_child(kmi)
	for k in Defs.BUILDING_COUNT:
		var wm := MultiMesh.new()
		wm.transform_format = MultiMesh.TRANSFORM_3D
		wm.use_custom_data = true
		wm.mesh = meshes[Defs.FRATE] if k == Defs.B_CHIESA else m.worker(k - 1)
		wm.instance_count = 8 * Buildings.MAX_PER_HOUSE
		wm.visible_instance_count = 0
		var wmi := MultiMeshInstance3D.new()
		wmi.multimesh = wm
		wmi.material_override = mat
		wmi.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(Defs.WX + 200, 200, Defs.WZ + 200))
		add_child(wmi)
		worker_mm.append(wm)
	# anelli di selezione e barre vita
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 16
	torus.ring_segments = 4
	ring_mm = _overlay_mm(torus, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	bar_mm = _overlay_mm(quad, true)
	var pip := QuadMesh.new()
	pip.size = Vector2(1, 1)
	pip_mm = _overlay_mm(pip, true, 1800)
	var pm := pip_mm_instance.material_override as StandardMaterial3D
	pm.no_depth_test = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.render_priority = 2
	pm.disable_fog = true


var pip_mm_instance: MultiMeshInstance3D


func _overlay_mm(mesh: Mesh, _colored: bool, n := 800) -> MultiMesh:
	var mu := MultiMesh.new()
	mu.transform_format = MultiMesh.TRANSFORM_3D
	mu.use_colors = true
	mu.mesh = mesh
	mu.instance_count = n
	mu.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mu
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-100, -50, -100), Vector3(Defs.WX + 200, 200, Defs.WZ + 200))
	add_child(mi)
	pip_mm_instance = mi
	return mu


## Posizione interpolata tra gli ultimi due snapshot.
func view_pos(u: Game.VU, f: float) -> Vector3:
	return u.prev.lerp(u.cur, f)


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var f := clampf((now - game.snap_time) / 0.1, 0.0, 1.0)
	for k in counts.size():
		counts[k] = 0
	var cam := get_viewport().get_camera_3d()
	var rings := 0
	var bars := 0
	var cam_basis := cam.global_transform.basis if cam else Basis.IDENTITY
	var pips := 0
	# da lontano i soldati sono più piccoli di un pixel: il rombo resta di dimensione costante a schermo
	var cdist: float = game.ctrl.dist if game.get("ctrl") != null else 95.0
	var pip_a := clampf((cdist - 75.0) / 50.0, 0.0, 1.0)
	var pip_s := cdist * 0.0085
	for u: Game.VU in game.vunits.values():
		var p: Vector3 = u.prev.lerp(u.cur, f)
		var yaw := lerp_angle(u.prev_yaw, u.yaw, f)
		var water := (u.flags & 4) != 0
		var bucket := BOAT if water else u.type
		if bucket >= mm.size():
			continue
		var c := counts[bucket]
		if c >= MAX_PER:
			continue
		for dn: Array in dances:
			if u.team == int(dn[1]) and now < float(dn[2]) and p.distance_squared_to(dn[0]) < 1600.0:
				# saltelli e giravolte, ognuno col suo tempo
				p.y += absf(sin(now * 7.0 + u.phase * 6.0)) * 0.9
				yaw += sin(now * 3.0 + u.phase * 4.0) * 2.5
		var bas := Basis(Vector3.UP, yaw)
		if (u.flags & 64) != 0:
			bas = bas * Basis(Vector3.RIGHT, 0.45)  # frate addormentato, testa ciondoloni
		var mu := mm[bucket]
		if water:
			p.y += sin(now * 1.6 + u.phase) * 0.12
			bas = bas * Basis(Vector3(0, 0, 1), sin(now * 1.1 + u.phase) * 0.07)
		mu.set_instance_transform(c, Transform3D(bas, p))
		var moving := 1.0 if (u.flags & 1) != 0 else 0.0
		var attack := 1.0 if (u.flags & 2) != 0 else 0.0
		var drunk := 10.0 if (u.flags & 8) != 0 else 0.0
		mu.set_instance_custom_data(c, Color(u.phase, moving, attack, float(u.team) + drunk))
		counts[bucket] = c + 1
		var tcol: Color = Defs.HOUSES[u.team].color
		var mine: bool = u.team == game.my_house
		if pip_a > 0.0 and pips < 1798 and cam:
			var hh2 := 3.0 if u.type < Defs.CAVALIERE else 4.5
			var ps := pip_s * (1.25 if mine else 1.0)
			var at := p + Vector3(0, hh2 + ps, 0)
			# rombo: quadrato ruotato di 45° verso la camera, bordo scuro (dorato per i propri) e interno colorato
			var rot := Basis(cam_basis.z, PI * 0.25)
			var bo := rot * Basis(cam_basis.x * ps * 1.35, cam_basis.y * ps * 1.35, cam_basis.z)
			var edge := Color(1.0, 0.85, 0.3) if mine else Color(0.05, 0.04, 0.03)
			edge.a = pip_a
			pip_mm.set_instance_transform(pips, Transform3D(bo, at))
			pip_mm.set_instance_color(pips, edge)
			pips += 1
			var bi := rot * Basis(cam_basis.x * ps, cam_basis.y * ps, cam_basis.z)
			var fill := tcol
			fill.a = pip_a
			pip_mm.set_instance_transform(pips, Transform3D(bi, at + cam_basis.z * 0.05))
			pip_mm.set_instance_color(pips, fill)
			pips += 1
		var is_sel: bool = selected.has(u.id)
		if is_sel and rings < 800:
			var size := 1.0 if u.type < Defs.CAVALIERE else (1.5 if u.type == Defs.CAVALIERE else 2.6)
			ring_mm.set_instance_transform(rings, Transform3D(Basis().scaled(Vector3(size, 0.5, size)), p + Vector3(0, 0.15, 0)))
			ring_mm.set_instance_color(rings, Color(0.4, 1.0, 0.4) if u.team == game.my_house else Color(1, 0.3, 0.3))
			rings += 1
		if u.hp < 0.995 and bars < 396 and cam:
			var hh := 3.3 if u.type < Defs.CAVALIERE else 4.8
			var top := p + Vector3(0, hh, 0)
			var w := 1.3 if u.type < Defs.CAVALIERE else 2.4
			var bg := Basis(cam_basis.x * w, cam_basis.y * 0.17, cam_basis.z)
			bar_mm.set_instance_transform(bars, Transform3D(bg, top))
			bar_mm.set_instance_color(bars, Color(0.05, 0.05, 0.05))
			bars += 1
			var fw := w * u.hp
			var fg := Basis(cam_basis.x * fw, cam_basis.y * 0.11, cam_basis.z)
			var offset: Vector3 = -cam_basis.x * (w - fw) * 0.5 + cam_basis.z * 0.02
			bar_mm.set_instance_transform(bars, Transform3D(fg, top + offset))
			bar_mm.set_instance_color(bars, Defs.HOUSES[u.team].color if u.hp > 0.35 else Color(0.9, 0.15, 0.1))
			bars += 1
	_draw_kings()
	for k in counts.size():
		mm[k].visible_instance_count = counts[k]
	ring_mm.visible_instance_count = rings
	bar_mm.visible_instance_count = bars
	pip_mm.visible_instance_count = pips


## Il re di ogni castello: quando lo colpiscono sventola la Gazzetta, furioso.
func _draw_kings() -> void:
	var n := 0
	var now := Time.get_ticks_msec() / 1000.0
	var cine_c: int = game.ctrl.cine_castle() if game.ctrl else -1
	for c: Dictionary in game.castles:
		var close_up: bool = c.id == cine_c and float(game.ctrl.cine.t) < game.ctrl.CINE_CLOSE
		if game.fx and float(game.fx.king_gone.get(c.id, 0.0)) > now and not close_up:
			continue  # è appena volato via: il gabinetto resta vuoto per un po'
		var o: int = game.castle_owner(c.id)
		var hurt: bool = c.id == cine_c
		if not game.state.is_empty():
			hurt = hurt or float(game.state[0][c.id][1]) > 0.0
		var dir: Vector3 = c.dir
		var bas := Basis(Vector3.UP, atan2(dir.x, dir.z))
		king_mm.set_instance_transform(n, Transform3D(bas, c.king))
		king_mm.set_instance_custom_data(n, Color(float(c.id) * 1.7, 0.0, 1.0 if hurt else 0.0, float(o)))
		n += 1
	king_mm.visible_instance_count = n
	_draw_workers()


## Il personaggio di ogni bottega finita e in piedi, davanti alla porta, sempre un po' indaffarato.
func _draw_workers() -> void:
	var counts: Array[int] = []
	counts.resize(Defs.BUILDING_COUNT)
	counts.fill(0)
	for bd: Array in game.buildings():
		var type: int = bd[1]
		if not bool(bd[9]):
			continue
		var fr: Array = Buildings.front(Vector2i(bd[3], bd[4]), int(bd[5]), Vector2i(bd[6], bd[7]))
		var face: Vector3 = fr[1]
		var wm := worker_mm[type]
		if counts[type] >= wm.instance_count:
			continue
		# in scala con le botteghe: si capisce chi sono
		wm.set_instance_transform(counts[type], Transform3D(Basis(Vector3.UP, atan2(face.x, face.z)).scaled(Vector3.ONE * WorldGen.CS), fr[0]))
		wm.set_instance_custom_data(counts[type], Color(float(bd[0]) * 1.3, 0.0, 1.0, float(bd[2])))
		counts[type] += 1
	for k in Defs.BUILDING_COUNT:
		worker_mm[k].visible_instance_count = counts[k]
