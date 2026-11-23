class_name VoxelWorld
extends Node3D
## Griglia voxel: dati, modifiche, supporto strutturale, meshing a thread, collisioni pigre.

const WX := Defs.WX
const WY := Defs.WY
const WZ := Defs.WZ
const CH := Defs.CHUNK
const LAYER_DY := WX * WZ
const CX := int(ceil(float(WX) / CH))
const CZ := int(ceil(float(WZ) / CH))
const AO_F: Array[float] = [0.52, 0.70, 0.86, 1.0]
const STEP_UP := 1.6

var vox := PackedByteArray()
var col_top := PackedByteArray()  # y massimo solido + 1 (0 = colonna vuota)
var col_sol := PackedByteArray()  # numero di voxel consecutivi solidi dal fondo
var walk_table := PackedByteArray()
var headless := false
var material: Material

var _inst: Array = []
var _bodies: Dictionary = {}
var _shapes: Dictionary = {}
var _collide: Dictionary = {}
var _dirty: Dictionary = {}
var _busy: Dictionary = {}
var _results: Array = []
var _mutex := Mutex.new()
var _pending_tasks: Array[int] = []

## Lontano si vede una copia semplificata del mondo: un gruppo di LOD_G x LOD_G chunk diventa
## una sola mesh a celle di LOD_S x LOD_S colonne (solo cime e fianchi). Oltre LOD_DIST dal
## centro del gruppo Godot mostra quella al posto dei chunk (visibility_parent, HLOD):
## meno triangoli e una draw call invece di sedici.
const LOD_G := 4
const LOD_S := 2
const LOD_DIST := 320.0
const GX := int(ceil(float(CX) / LOD_G))
const GZ := int(ceil(float(CZ) / LOD_G))
var _lod: Array = []
var _lod_dirty: Dictionary = {}
var _lod_busy: Dictionary = {}
var _lod_t: Dictionary = {}  # gruppo -> ultimo ricalcolo (s): sotto assedio basta uno al secondo
var _pre_lod_gid := -1
var _pre_lod_res: Array = []

# tabelle facce: per ogni direzione normale, 4 angoli, offset AO
static var _f_n: Array[Vector3] = []
static var _f_c: Array = []
static var _f_ao: Array = []
static var _f_off: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	vox.resize(WX * WY * WZ)
	col_top.resize(WX * WZ)
	col_sol.resize(WX * WZ)
	gen_touched.resize(WX * WZ)
	walk_table.resize(256)
	for m in 256:
		walk_table[m] = 1 if Defs.blocks_walk(m) else 0
	_setup_tables()


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.1
	material = mat
	_inst.resize(CX * CZ)
	if headless:
		return
	_lod.resize(GX * GZ)
	for g in GX * GZ:
		var lm := MeshInstance3D.new()
		lm.material_override = mat
		var gx := g % GX
		var gz := g / GX
		# il box fisso del gruppo: la distanza si misura dal suo centro anche prima della mesh
		lm.custom_aabb = AABB(Vector3(gx * LOD_G * CH, 0, gz * LOD_G * CH), Vector3(LOD_G * CH, WY, LOD_G * CH))
		lm.visibility_range_begin = LOD_DIST
		add_child(lm)
		_lod[g] = lm


static func _setup_tables() -> void:
	if not _f_n.is_empty():
		return
	var dirs: Array[Vector3i] = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
	for n in dirs:
		var u: Vector3i
		var v: Vector3i
		if n.x != 0:
			u = Vector3i(0,1,0); v = Vector3i(0,0,1)
		elif n.y != 0:
			u = Vector3i(1,0,0); v = Vector3i(0,0,1)
		else:
			u = Vector3i(1,0,0); v = Vector3i(0,1,0)
		# Godot: fronte in senso orario => (b-a)x(c-a) = -n
		var cr := Vector3(u).cross(Vector3(v))
		if cr.is_equal_approx(Vector3(n)):
			var t := u; u = v; v = t
		var base := Vector3i(maxi(n.x, 0), maxi(n.y, 0), maxi(n.z, 0))
		var corners: Array[Vector3] = [Vector3(base), Vector3(base + u), Vector3(base + u + v), Vector3(base + v)]
		_f_n.append(Vector3(n))
		_f_c.append(corners)
		var ao := PackedInt32Array()
		var signs := [[-1,-1],[1,-1],[1,1],[-1,1]]
		for s in signs:
			var a: Vector3i = n + u * int(s[0])
			var b: Vector3i = n + v * int(s[1])
			var c: Vector3i = n + u * int(s[0]) + v * int(s[1])
			ao.append(a.x + a.z * WX + a.y * LAYER_DY)
			ao.append(b.x + b.z * WX + b.y * LAYER_DY)
			ao.append(c.x + c.z * WX + c.y * LAYER_DY)
		_f_ao.append(ao)
		_f_off.append(n.x + n.z * WX + n.y * LAYER_DY)


# ---------------------------------------------------------------- accesso
func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and z >= 0 and y >= 0 and x < WX and z < WZ and y < WY

func index(x: int, y: int, z: int) -> int:
	return x + z * WX + y * LAYER_DY

func index_v(p: Vector3i) -> int:
	return p.x + p.z * WX + p.y * LAYER_DY

func pos_of(i: int) -> Vector3i:
	var y := i / LAYER_DY
	var r := i - y * LAYER_DY
	var z := r / WX
	return Vector3i(r - z * WX, y, z)

func get_v(x: int, y: int, z: int) -> int:
	if x < 0 or z < 0 or y < 0 or x >= WX or z >= WZ or y >= WY:
		return 0
	return vox[x + z * WX + y * LAYER_DY]

## Scrittura grezza (generazione): non aggiorna cache né mesh, segna solo la colonna in gen_touched.
func put(x: int, y: int, z: int, m: int) -> void:
	if x < 0 or z < 0 or y < 0 or x >= WX or z >= WZ or y >= WY:
		return
	vox[x + z * WX + y * LAYER_DY] = m
	gen_touched[x + z * WX] = 1

## Colonne scritte con put() dopo il riempimento del terreno: solo queste vanno ricalcolate.
var gen_touched := PackedByteArray()

func recompute_all() -> void:
	var gid := WorkerThreadPool.add_group_task(func(z: int):
		for x in WX:
			_recompute_col(x, z), WZ)
	WorkerThreadPool.wait_for_group_task_completion(gid)

## Fine generazione: col_top e col_sol del terreno li ha già scritti WorldGen, qui si
## ricalcolano solo le colonne toccate da put() (castelli, crateri, monumenti, alberi).
func recompute_touched() -> void:
	var gid := WorkerThreadPool.add_group_task(func(z: int):
		var r := z * WX
		for x in WX:
			if gen_touched[r + x] != 0:
				_recompute_col(x, z), WZ)
	WorkerThreadPool.wait_for_group_task_completion(gid)
	gen_touched.fill(0)

func _recompute_col(x: int, z: int) -> void:
	var top := 0
	var sol := -1
	var i := x + z * WX
	for y in WY:
		if vox[i] != 0:
			top = y + 1
		elif sol < 0:
			sol = y
		i += LAYER_DY
	if sol < 0:
		sol = WY
	col_top[x + z * WX] = top
	col_sol[x + z * WX] = sol

## Altezza del primo voxel libero sopra l'ultimo pieno della colonna.
func top_y(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= WX or z >= WZ:
		return 0
	return col_top[x + z * WX]

## Applica modifiche [indice<<8 | materiale]. Aggiorna cache e segna i chunk.
var all_built := false
var _pre_gid := -1
var _pre_i := 0
var _pre_res: Array = []


func apply_edits(edits: PackedInt64Array) -> void:
	var cols := {}
	for e in edits:
		var i: int = e >> Defs.EDIT_SHIFT
		vox[i] = e & Defs.EDIT_MASK
		cols[i % LAYER_DY] = true
	for c: int in cols:
		var x: int = c % WX
		var z: int = c / WX
		_recompute_col(x, z)
		_mark(x, z)

func _mark(x: int, z: int) -> void:
	var cx := x / CH
	var cz := z / CH
	_dirty[cx + cz * CX] = true
	var lx := x % CH
	var lz := z % CH
	if lx == 0 and cx > 0: _dirty[cx - 1 + cz * CX] = true
	if lx == CH - 1 and cx < CX - 1: _dirty[cx + 1 + cz * CX] = true
	if lz == 0 and cz > 0: _dirty[cx + (cz - 1) * CX] = true
	if lz == CH - 1 and cz < CZ - 1: _dirty[cx + (cz + 1) * CX] = true
	if not headless:
		_lod_dirty[_lod_group(x / LOD_S * LOD_S, z / LOD_S * LOD_S)] = true
		# una cella sul bordo cambia anche il fianco del gruppo vicino
		_lod_dirty[_lod_group(mini(x + LOD_S, WX - 1), z)] = true
		_lod_dirty[_lod_group(maxi(x - LOD_S, 0), z)] = true
		_lod_dirty[_lod_group(x, mini(z + LOD_S, WZ - 1))] = true
		_lod_dirty[_lod_group(x, maxi(z - LOD_S, 0))] = true

func _lod_group(x: int, z: int) -> int:
	return x / (CH * LOD_G) + z / (CH * LOD_G) * GX

func hash_world() -> int:
	return hash(vox)

# ---------------------------------------------------------------- navigazione
## Dato un piede a quota fy, restituisce la quota del suolo camminabile in (fx,fz)
## oppure -1000 se la colonna è bloccata (muro). Il mare è camminabile: si va in barca.
func walk_y(fx: float, fy: float, fz: float, pass_gate := false) -> float:
	var ix := int(fx)
	var iz := int(fz)
	if ix < 1 or iz < 1 or ix >= WX - 1 or iz >= WZ - 1:
		return -1000.0
	var base := ix + iz * WX
	var y := int(fy + STEP_UP - 0.01)
	if y >= WY - 3:
		y = WY - 4
	if y < 0:
		y = 0
	var start := y
	while y >= 0:
		var m := vox[base + y * LAYER_DY]
		if walk_table[m] == 1 and not (pass_gate and m == Defs.GATE):
			break
		y -= 1
	var foot := y + 1
	if foot <= Defs.SEA:
		return float(Defs.SEA) + 0.35
	# spazio per la testa
	var h1 := vox[base + (foot) * LAYER_DY]
	var h2 := vox[base + (foot + 1) * LAYER_DY]
	if (walk_table[h1] == 1 and not (pass_gate and h1 == Defs.GATE)) or (walk_table[h2] == 1 and not (pass_gate and h2 == Defs.GATE)):
		return -1000.0
	if y == start:
		# anche il voxel subito sopra la soglia di salita deve essere libero
		var h3 := vox[base + (foot + 2) * LAYER_DY]
		if walk_table[h3] == 1 and not (pass_gate and h3 == Defs.GATE):
			return -1000.0
	return float(foot)

func is_struct(x: int, y: int, z: int) -> bool:
	return get_v(x, y, z) >= Defs.STRUCT_MIN

## Raggio che attraversa i voxel (Amanatides & Woo). Colpisce anche il piano del mare.
func raycast(from: Vector3, dir: Vector3, max_d: float = 2000.0) -> Dictionary:
	dir = dir.normalized()
	var p := from
	# porta l'origine dentro la fascia di altezza del mondo
	if p.y > WY and dir.y < 0.0:
		var t0 := (float(WY) - 0.01 - p.y) / dir.y
		p += dir * t0
		max_d -= t0
	var x := int(floor(p.x)); var y := int(floor(p.y)); var z := int(floor(p.z))
	var sx := 1 if dir.x > 0 else -1
	var sy := 1 if dir.y > 0 else -1
	var sz := 1 if dir.z > 0 else -1
	var tdx: float = abs(1.0 / dir.x) if dir.x != 0 else 1e30
	var tdy: float = abs(1.0 / dir.y) if dir.y != 0 else 1e30
	var tdz: float = abs(1.0 / dir.z) if dir.z != 0 else 1e30
	var tx: float = ((x + maxi(sx, 0)) - p.x) / dir.x if dir.x != 0 else 1e30
	var ty: float = ((y + maxi(sy, 0)) - p.y) / dir.y if dir.y != 0 else 1e30
	var tz: float = ((z + maxi(sz, 0)) - p.z) / dir.z if dir.z != 0 else 1e30
	var t := 0.0
	var n := Vector3i.ZERO
	while t < max_d:
		if y < Defs.SEA and sy < 0:
			var pt := p + dir * t
			if get_v(x, y, z) == 0:
				return {"hit": true, "water": true, "point": Vector3(pt.x, Defs.SEA + 0.35, pt.z), "voxel": Vector3i(x, y, z), "normal": Vector3i.UP}
		if get_v(x, y, z) != 0:
			return {"hit": true, "water": false, "point": p + dir * t, "voxel": Vector3i(x, y, z), "normal": n}
		if tx < ty and tx < tz:
			x += sx; t = tx; tx += tdx; n = Vector3i(-sx, 0, 0)
		elif ty < tz:
			y += sy; t = ty; ty += tdy; n = Vector3i(0, -sy, 0)
		else:
			z += sz; t = tz; tz += tdz; n = Vector3i(0, 0, -sz)
		if y < 0 or (y >= WY and sy > 0):
			break
	return {"hit": false}

# ---------------------------------------------------------------- supporto strutturale
## Dai voxel seme trova i gruppi di struttura staccati dal terreno.
## Restituisce un Array di PackedInt32Array di indici.
func find_unsupported(seeds: PackedInt32Array, max_comp := 14000) -> Array:
	var out: Array = []
	var state := {}  # indice -> 1 sostenuto, 2 staccato
	var offs := [1, -1, WX, -WX, -LAYER_DY, LAYER_DY]
	for s in seeds:
		if s < 0 or s >= vox.size() or vox[s] < Defs.STRUCT_MIN or state.has(s):
			continue
		var stack := PackedInt32Array([s])
		var comp := PackedInt32Array()
		var seen := {s: true}
		var supported := false
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			comp.append(i)
			if comp.size() > max_comp:
				supported = true
				break
			for k in 6:
				var j: int = i + offs[k]
				if j < 0 or j >= vox.size():
					continue
				var m := vox[j]
				if m == 0:
					continue
				if m < Defs.STRUCT_MIN:
					supported = true
					break
				var st: int = state.get(j, 0)
				if st == 1:
					supported = true
					break
				if st == 0 and not seen.has(j):
					seen[j] = true
					stack.append(j)
			if supported:
				break
		var val := 1 if supported else 2
		for i in comp:
			state[i] = val
		if not supported:
			out.append(comp)
	return out

# ---------------------------------------------------------------- meshing
func build_all_blocking() -> void:
	# il menu ha già costruito tutto (vedi prebuild_step): restano solo i pezzi cambiati dopo
	var keys: Array = _dirty.keys() if all_built else range(CX * CZ)
	var count := keys.size()
	if count == 0:
		return
	var res: Array = []
	res.resize(count)
	var gid := WorkerThreadPool.add_group_task(func(n: int): res[n] = _mesh_chunk(int(keys[n]) % CX, int(keys[n]) / CX), count)
	var lod_res: Array = []
	var lod_gid := -1
	if not headless and not all_built:
		lod_res.resize(GX * GZ)
		lod_gid = WorkerThreadPool.add_group_task(func(g: int): lod_res[g] = _mesh_lod(g), GX * GZ)
	WorkerThreadPool.wait_for_group_task_completion(gid)
	if lod_gid >= 0:
		WorkerThreadPool.wait_for_group_task_completion(lod_gid)
		for g in GX * GZ:
			_install_lod(g, lod_res[g])
		_lod_dirty.clear()
	for n in count:
		_install(int(keys[n]), res[n])
		if all_built:
			_dirty.erase(keys[n])


## Costruisce tutto il mondo senza fermare il gioco: i worker preparano le mesh e qui si
## installano a piccole dosi. Va chiamata a ogni fotogramma; ritorna true quando ha finito.
func prebuild_step(budget_ms := 10) -> bool:
	if all_built:
		return true
	var count := CX * CZ
	if _pre_gid < 0 and _pre_i == 0:
		_dirty.clear()  # d'ora in poi ci pensa questa funzione a tutti i pezzi
		_pre_res = []
		_pre_res.resize(count)
		_pre_gid = WorkerThreadPool.add_group_task(_pre_mesh, count)
		if not headless:
			_pre_lod_res = []
			_pre_lod_res.resize(GX * GZ)
			_pre_lod_gid = WorkerThreadPool.add_group_task(_pre_lod, GX * GZ)
		return false
	if _pre_gid >= 0:
		if not WorkerThreadPool.is_group_task_completed(_pre_gid):
			return false
		if _pre_lod_gid >= 0 and not WorkerThreadPool.is_group_task_completed(_pre_lod_gid):
			return false
		WorkerThreadPool.wait_for_group_task_completion(_pre_gid)
		_pre_gid = -1
		if _pre_lod_gid >= 0:
			WorkerThreadPool.wait_for_group_task_completion(_pre_lod_gid)
			_pre_lod_gid = -1
			for g in GX * GZ:
				_install_lod(g, _pre_lod_res[g])
			_pre_lod_res = []
			_lod_dirty.clear()
	var t0 := Time.get_ticks_msec()
	while _pre_i < count and Time.get_ticks_msec() - t0 < budget_ms:
		_install(_pre_i, _pre_res[_pre_i])
		_pre_i += 1
	if _pre_i < count:
		return false
	_pre_res = []
	all_built = true
	return true


func _pre_mesh(k: int) -> void:
	_pre_res[k] = _mesh_chunk(k % CX, k / CX)

func _pre_lod(g: int) -> void:
	_pre_lod_res[g] = _mesh_lod(g)

## Mesh semplificata di un gruppo: per ogni cella LOD_S x LOD_S la colonna più alta dà quota e
## colore della cima; dove la cella vicina è più bassa scende un fianco fino alla sua quota.
## Le celle di fondale profondo non si disegnano, come nei chunk: l'acqua lì è opaca.
func _mesh_lod(g: int) -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var inds := PackedInt32Array()
	var ctop := col_top
	var vx := vox
	var pal := Defs.PALETTE.duplicate()
	var f_c := _f_c.duplicate(true)
	var f_n := _f_n.duplicate()
	var x0 := (g % GX) * LOD_G * CH
	var z0 := (g / GX) * LOD_G * CH
	var x1 := mini(x0 + LOD_G * CH, WX)
	var z1 := mini(z0 + LOD_G * CH, WZ)
	# come nei chunk: sotto SEA - 5 l'acqua è opaca e il fondale non si disegna
	var floor_y := Defs.SEA - 5
	var vc := 0
	for z in range(z0, z1, LOD_S):
		for x in range(x0, x1, LOD_S):
			var h := _lod_h(ctop, x, z)
			if h <= floor_y:
				continue
			# la colonna più alta della cella: il suo voxel di cima dà il colore
			var bx := x
			var bz := z
			for dz in LOD_S:
				for dx in LOD_S:
					if x + dx < WX and z + dz < WZ and ctop[x + dx + (z + dz) * WX] == h:
						bx = x + dx
						bz = z + dz
			var m: int = vx[bx + bz * WX + (h - 1) * LAYER_DY]
			var c0: Color = Defs.HOUSES[m - Defs.TEAM0].color if m >= Defs.TEAM0 else pal[m]
			var hv: int = (bx * 73856093 ^ (h - 1) * 19349663 ^ bz * 83492791) & 255
			var vary := 0.93 + float(hv) / 255.0 * 0.14
			if m == Defs.GRASS or m == Defs.GRASS2:
				vary = 0.86 + float(hv) / 255.0 * 0.24
			var top_c := Color(c0.r * vary, c0.g * vary, c0.b * vary)
			var side_c := Color(top_c.r * 0.7, top_c.g * 0.7, top_c.b * 0.7)
			var w := mini(LOD_S, WX - x)
			var dpt := mini(LOD_S, WZ - z)
			# d: 0 +x, 1 -x, 2 su, 4 +z, 5 -z (come _f_c / _f_n)
			for d: int in [2, 0, 1, 4, 5]:
				var low := floor_y
				if d == 0: low = maxi(_lod_h(ctop, x + LOD_S, z), floor_y)
				elif d == 1: low = maxi(_lod_h(ctop, x - LOD_S, z), floor_y)
				elif d == 4: low = maxi(_lod_h(ctop, x, z + LOD_S), floor_y)
				elif d == 5: low = maxi(_lod_h(ctop, x, z - LOD_S), floor_y)
				if d == 2:
					low = h - 1
				elif low >= h:
					continue
				var o := Vector3(x, low, z)
				var size := Vector3(w, h - low, dpt)
				var cs: Array = f_c[d]
				var nrm: Vector3 = f_n[d]
				var c := top_c if d == 2 else side_c
				for k in 4:
					verts.append(o + (cs[k] as Vector3) * size)
					norms.append(nrm)
					cols.append(c)
				inds.append(vc); inds.append(vc + 1); inds.append(vc + 2)
				inds.append(vc); inds.append(vc + 2); inds.append(vc + 3)
				vc += 4
	return {"v": verts, "n": norms, "c": cols, "i": inds}

## Quota della cella che comincia in (x, z): la colonna più alta; 0 fuori dal mondo.
static func _lod_h(ctop: PackedByteArray, x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= WX or z >= WZ:
		return 0
	x = x / LOD_S * LOD_S
	z = z / LOD_S * LOD_S
	var h := 0
	for dz in LOD_S:
		for dx in LOD_S:
			if x + dx < WX and z + dz < WZ:
				h = maxi(h, ctop[x + dx + (z + dz) * WX])
	return h

func _install_lod(g: int, data: Dictionary) -> void:
	var lm: MeshInstance3D = _lod[g]
	var verts: PackedVector3Array = data.v
	if verts.is_empty():
		lm.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_INDEX] = data.i
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	lm.mesh = am

func _mesh_chunk(cx: int, cz: int, want_faces := false) -> Dictionary:
	var faces := PackedVector3Array()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var inds := PackedInt32Array()
	var vc := 0
	var x0 := cx * CH
	var z0 := cz * CH
	var x1 := mini(x0 + CH, WX)
	var z1 := mini(z0 + CH, WZ)
	# copie locali: le tabelle condivise lette da tutti i worker a ogni faccia si contendono
	# il contatore dei riferimenti; una copia per chunk costa poco e rende i worker indipendenti
	var vx := vox
	var ctop := col_top
	var csol := col_sol
	var wt := walk_table
	var f_off := _f_off.duplicate()
	var f_ao := _f_ao.duplicate(true)
	var f_c := _f_c.duplicate(true)
	var f_n := _f_n.duplicate()
	var aof := PackedFloat64Array(AO_F)
	var sz := vx.size()
	var pal := Defs.PALETTE.duplicate()
	var deep := Defs.SEA - 5
	var a := PackedInt32Array([0, 0, 0, 0])
	for z in range(z0, z1):
		for x in range(x0, x1):
			var ci := x + z * WX
			var top: int = ctop[ci]
			if top == 0:
				continue
			# parti dal livello più basso che può avere facce visibili
			var ymin: int = csol[ci]
			if x > 0: ymin = mini(ymin, csol[ci - 1])
			if x < WX - 1: ymin = mini(ymin, csol[ci + 1])
			if z > 0: ymin = mini(ymin, csol[ci - WX])
			if z < WZ - 1: ymin = mini(ymin, csol[ci + WX])
			ymin = maxi(ymin - 1, 0)
			for y in range(ymin, top):
				var i := ci + y * LAYER_DY
				var m: int = vx[i]
				if m == 0:
					continue
				var colored := false
				var r := 0.0
				var g := 0.0
				var b := 0.0
				for d in 6:
					# fondale profondo: l'acqua lì è opaca (environment.gd, ALPHA a 1 oltre 4,5 di
					# profondità), quindi niente grafica; resta solo il piano per le collisioni
					if y < deep:
						if d == 2 and want_faces and wt[m] == 1 and (i + LAYER_DY >= sz or vx[i + LAYER_DY] == 0):
							var o0 := Vector3(x, y, z)
							var cs0: Array = f_c[2]
							faces.append(o0 + (cs0[0] as Vector3)); faces.append(o0 + (cs0[1] as Vector3)); faces.append(o0 + (cs0[2] as Vector3))
							faces.append(o0 + (cs0[0] as Vector3)); faces.append(o0 + (cs0[2] as Vector3)); faces.append(o0 + (cs0[3] as Vector3))
						continue
					var ni: int = i + f_off[d]
					if ni >= 0 and ni < sz and vx[ni] != 0:
						continue
					# bordi del mondo: niente facce
					if (d == 0 and x == WX - 1) or (d == 1 and x == 0) or (d == 4 and z == WZ - 1) or (d == 5 and z == 0) or (d == 3 and y == 0):
						continue
					if not colored:
						# il colore serve solo ai voxel con almeno una faccia visibile
						colored = true
						var c0: Color = Defs.HOUSES[m - Defs.TEAM0].color if m >= Defs.TEAM0 else pal[m]
						var hv: int = (x * 73856093 ^ y * 19349663 ^ z * 83492791) & 255
						var vary := 0.93 + float(hv) / 255.0 * 0.14
						if m == Defs.GRASS or m == Defs.GRASS2:
							vary = 0.86 + float(hv) / 255.0 * 0.24
						r = c0.r * vary
						g = c0.g * vary
						b = c0.b * vary
					var ao: PackedInt32Array = f_ao[d]
					var cs: Array = f_c[d]
					var nrm: Vector3 = f_n[d]
					for k in 4:
						var a1: int = i + ao[k * 3]
						var a2: int = i + ao[k * 3 + 1]
						var a3: int = i + ao[k * 3 + 2]
						var s1 := 1 if a1 >= 0 and a1 < sz and vx[a1] != 0 else 0
						var s2 := 1 if a2 >= 0 and a2 < sz and vx[a2] != 0 else 0
						var s3 := 1 if a3 >= 0 and a3 < sz and vx[a3] != 0 else 0
						var lvl := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + s3)
						a[k] = lvl
						var f: float = aof[lvl]
						var cv: Vector3 = cs[k]
						verts.append(Vector3(x + cv.x, y + cv.y, z + cv.z))
						norms.append(nrm)
						cols.append(Color(r * f, g * f, b * f))
					if a[0] + a[2] >= a[1] + a[3]:
						inds.append(vc); inds.append(vc + 1); inds.append(vc + 2)
						inds.append(vc); inds.append(vc + 2); inds.append(vc + 3)
					else:
						inds.append(vc + 1); inds.append(vc + 2); inds.append(vc + 3)
						inds.append(vc + 1); inds.append(vc + 3); inds.append(vc)
					if want_faces and wt[m] == 1:
						var o := Vector3(x, y, z)
						var c0v: Vector3 = o + (cs[0] as Vector3)
						var c1v: Vector3 = o + (cs[1] as Vector3)
						var c2v: Vector3 = o + (cs[2] as Vector3)
						var c3v: Vector3 = o + (cs[3] as Vector3)
						faces.append(c0v); faces.append(c1v); faces.append(c2v)
						faces.append(c0v); faces.append(c2v); faces.append(c3v)
					vc += 4
	return {"v": verts, "n": norms, "c": cols, "i": inds, "f": faces}

func _install(k: int, data: Dictionary) -> void:
	var verts: PackedVector3Array = data.v
	if _collide.has(k) and not (data.f as PackedVector3Array).is_empty():
		_set_collision(k, data)
	elif _collide.has(k) and not _bodies.has(k):
		_set_collision(k, data)
	if headless:
		return
	var mi: MeshInstance3D = _inst[k]
	if verts.is_empty():
		if mi:
			mi.mesh = null
		return
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = material
		add_child(mi)
		_inst[k] = mi
		if not _lod.is_empty():
			# visibile solo finché il gruppo semplificato è nascosto perché la camera è vicina;
			# i gruppi tutti di mare non hanno copia semplificata: lì i chunk restano sempre
			var lm: MeshInstance3D = _lod[_lod_group(k % CX * CH, k / CX * CH)]
			if lm.mesh != null:
				mi.visibility_parent = mi.get_path_to(lm)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = data.n
	arrays[Mesh.ARRAY_COLOR] = data.c
	arrays[Mesh.ARRAY_INDEX] = data.i
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = am

func _set_collision(k: int, data: Dictionary) -> void:
	var faces: PackedVector3Array = data.f
	var body: StaticBody3D = _bodies.get(k)
	if body == null:
		body = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		_bodies[k] = body
		_shapes[k] = shape
	(_shapes[k] as ConcavePolygonShape3D).set_faces(faces)

## Crea le collisioni fisiche dei chunk attorno a un punto (servono solo ai crolli).
func activate_collision(center: Vector3, radius: float) -> void:
	var cx0 := clampi(int(center.x - radius) / CH, 0, CX - 1)
	var cx1 := clampi(int(center.x + radius) / CH, 0, CX - 1)
	var cz0 := clampi(int(center.z - radius) / CH, 0, CZ - 1)
	var cz1 := clampi(int(center.z + radius) / CH, 0, CZ - 1)
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var k := cx + cz * CX
			if not _collide.has(k):
				_collide[k] = true
				_dirty[k] = true

## Vero quando le collisioni dell'area sono state costruite dai worker.
func collision_ready(center: Vector3, radius: float) -> bool:
	var cx0 := clampi(int(center.x - radius) / CH, 0, CX - 1)
	var cx1 := clampi(int(center.x + radius) / CH, 0, CX - 1)
	var cz0 := clampi(int(center.z - radius) / CH, 0, CZ - 1)
	var cz1 := clampi(int(center.z + radius) / CH, 0, CZ - 1)
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			if not _bodies.has(cx + cz * CX):
				return false
	return true

func _process(_dt: float) -> void:
	# installa i risultati pronti
	_mutex.lock()
	var ready_res := _results
	_results = []
	_mutex.unlock()
	for r: Array in ready_res:
		if r[0] < 0:
			var g: int = -1 - r[0]
			_lod_busy.erase(g)
			_install_lod(g, r[1])
			continue
		_busy.erase(r[0])
		_install(r[0], r[1])
	var i := _pending_tasks.size() - 1
	while i >= 0:
		if WorkerThreadPool.is_task_completed(_pending_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_pending_tasks[i])
			_pending_tasks.remove_at(i)
		i -= 1
	# avvia nuovi lavori di meshing
	var launched := 0
	for k: int in _dirty.keys():
		if launched >= 6:
			break
		if _busy.has(k):
			continue
		_dirty.erase(k)
		_busy[k] = true
		launched += 1
		_pending_tasks.append(WorkerThreadPool.add_task(_mesh_task.bind(k, _collide.has(k))))
	# i gruppi semplificati cambiati: al più uno per fotogramma e ognuno al più una volta al secondo
	if all_built and not _lod_dirty.is_empty():
		var now := Time.get_ticks_msec() / 1000.0
		for g: int in _lod_dirty.keys():
			if _lod_busy.has(g) or now - float(_lod_t.get(g, -10.0)) < 1.0:
				continue
			_lod_dirty.erase(g)
			_lod_busy[g] = true
			_lod_t[g] = now
			_pending_tasks.append(WorkerThreadPool.add_task(_lod_task.bind(g)))
			break

## I worker leggono i dati del mondo: vanno attesi prima che il nodo venga liberato.
func _exit_tree() -> void:
	if _pre_gid >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_pre_gid)
		_pre_gid = -1
	if _pre_lod_gid >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_pre_lod_gid)
		_pre_lod_gid = -1
	for t in _pending_tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_pending_tasks.clear()

func _lod_task(g: int) -> void:
	var data := _mesh_lod(g)
	_mutex.lock()
	_results.append([-1 - g, data])
	_mutex.unlock()

func _mesh_task(k: int, want_faces: bool) -> void:
	var data := _mesh_chunk(k % CX, k / CX, want_faces)
	_mutex.lock()
	_results.append([k, data])
	_mutex.unlock()

## Mesh per un gruppo di voxel staccati (coordinate relative all'origine data).
static func mesh_fragment(voxels: Dictionary, origin: Vector3) -> ArrayMesh:
	_setup_tables()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var inds := PackedInt32Array()
	var dirs: Array[Vector3i] = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
	var vc := 0
	for p: Vector3i in voxels:
		var c := Defs.mat_color(voxels[p])
		var hv: int = (p.x * 73856093 ^ p.y * 19349663 ^ p.z * 83492791) & 255
		var vary := 0.93 + float(hv) / 255.0 * 0.14
		c = Color(c.r * vary, c.g * vary, c.b * vary)
		var base := Vector3(p) - origin
		for d in 6:
			if voxels.has(p + dirs[d]):
				continue
			var cs: Array = _f_c[d]
			var nrm: Vector3 = _f_n[d]
			for k in 4:
				verts.append(base + (cs[k] as Vector3))
				norms.append(nrm)
				cols.append(c)
			inds.append(vc); inds.append(vc + 1); inds.append(vc + 2)
			inds.append(vc); inds.append(vc + 2); inds.append(vc + 3)
			vc += 4
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = inds
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am
