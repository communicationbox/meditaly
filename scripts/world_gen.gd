class_name WorldGen
extends RefCounted
## Genera in modo deterministico la penisola italiana in voxel, con castelli, borghi e monumenti.

const WX := Defs.WX
const WZ := Defs.WZ
const SEA := Defs.SEA
## Scala dei castelli (solo castelli e botteghe: terreno, borghi e soldati restano uguali).
## Avanzamento della generazione (0-1) e fase in corso, letti dalla schermata di caricamento.
## Li scrive il thread di generazione: sono numeri semplici, basta leggerli ogni fotogramma.
static var progress := 0.0
static var stage := 0

const CS := 2
const WALL_H := 14
const TOWER_H := 24
const R := 12 * CS
const WALL_T := 3  # spessore delle mura
## Centro degli spazi per le botteghe: di lato rispetto alla porta e un po' verso di lei.
const SLOT_SIDE := 15
const SLOT_DIR := 6
## Mastio: mezzo lato, altezza, arretramento dal centro.
const KEEP_K := 8
const KEEP_H := 30
const KEEP_BACK := 6

var w: VoxelWorld
var h := PackedInt32Array()      # quota del terreno (y del voxel più alto)
var sdf := PackedFloat32Array()  # >0 terra, <0 mare
var mtn := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var noise_a := FastNoiseLite.new()
var noise_b := FastNoiseLite.new()
var noise_c := FastNoiseLite.new()
var noise_d := FastNoiseLite.new()
var _bp: Variant = null  # registrazione blueprint castello
var _road := PackedByteArray()
var _no_tree := PackedByteArray()


static func generate(world: VoxelWorld, seed_value := 1453) -> Array:
	var g := WorldGen.new()
	g.w = world
	return g._run(seed_value)


func _run(seed_value: int) -> Array:
	rng.seed = seed_value
	noise_a.seed = seed_value
	noise_a.frequency = 0.012 / Defs.MAP_SCALE
	noise_a.fractal_octaves = 4
	noise_b.seed = seed_value + 1
	noise_b.frequency = 0.05 / sqrt(Defs.MAP_SCALE)
	noise_b.fractal_octaves = 3
	noise_c.seed = seed_value + 2
	noise_c.frequency = 0.022 / Defs.MAP_SCALE
	noise_c.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_c.fractal_octaves = 4
	noise_d.seed = seed_value + 3
	noise_d.frequency = 0.04
	_step(0, 0.02)
	h.resize(WX * WZ)
	mtn.resize(WX * WZ)
	_road.resize(WX * WZ)
	_no_tree.resize(WX * WZ)
	_rasterize_land()
	_step(1, 0.14)
	_stamp_mountains()
	_step(2, 0.24)
	_compute_heights()
	_step(3, 0.34)
	var cdefs := _flatten_castles()
	_draw_roads(cdefs)
	_step(4, 0.40)
	_fill_terrain()
	_step(5, 0.62)
	var castles: Array = []
	for i in cdefs.size():
		castles.append(_build_castle(i, cdefs[i]))
		progress = 0.62 + 0.14 * float(i + 1) / cdefs.size()
	# niente borghi: ogni casa, chiesa e bottega la costruiscono i giocatori
	_build_landmarks(cdefs)
	_step(6, 0.78)
	_plant_trees(cdefs)
	_step(7, 0.90)
	w.recompute_touched()
	_step(8, 1.0)
	return castles


static func _step(s: int, p: float) -> void:
	stage = s
	progress = p


# ---------------------------------------------------------------- forma dell'Italia
func _scan_polygon(poly: Array, mask: PackedByteArray) -> void:
	var pts: Array[Vector2] = []
	for p in poly:
		pts.append(Defs.geo(p[0], p[1]))
	for z in WZ:
		var xs: Array[float] = []
		var zf := z + 0.5
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= zf and b.y > zf) or (b.y <= zf and a.y > zf):
				xs.append(a.x + (zf - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		var i := 0
		while i + 1 < xs.size():
			for x in range(maxi(int(xs[i]), 0), mini(int(xs[i + 1]) + 1, WX)):
				mask[x + z * WX] = 1
			i += 2


func _rasterize_land() -> void:
	var mask := PackedByteArray()
	mask.resize(WX * WZ)
	for poly in [Defs.POLY_MAINLAND, Defs.POLY_SICILY, Defs.POLY_SARDINIA, Defs.POLY_CORSICA]:
		_scan_polygon(poly, mask)
	# distanza dalla costa (chamfer) in entrambi i versi
	sdf = _chamfer(mask, 1)
	var outside := _chamfer(mask, 0)
	for i in sdf.size():
		sdf[i] = sdf[i] - outside[i]


func _chamfer(mask: PackedByteArray, inside_val: int) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(WX * WZ)
	const BIG := 9999.0
	for i in d.size():
		d[i] = BIG if mask[i] == inside_val else 0.0
	const D1 := 1.0
	const D2 := 1.414
	for z in range(1, WZ - 1):
		for x in range(1, WX - 1):
			var i := x + z * WX
			if d[i] > 0.0:
				d[i] = minf(d[i], minf(d[i - 1] + D1, minf(d[i - WX] + D1, minf(d[i - WX - 1] + D2, d[i - WX + 1] + D2))))
	for z in range(WZ - 2, 0, -1):
		for x in range(WX - 2, 0, -1):
			var i := x + z * WX
			if d[i] > 0.0:
				d[i] = minf(d[i], minf(d[i + 1] + D1, minf(d[i + WX] + D1, minf(d[i + WX + 1] + D2, d[i + WX - 1] + D2))))
	return d


func _stamp_polyline(line: Array, radius: float, height: float) -> void:
	for s in range(line.size() - 1):
		var a := Defs.geo(line[s][0], line[s][1])
		var b := Defs.geo(line[s + 1][0], line[s + 1][1])
		var steps := int(a.distance_to(b) / (4.0 * Defs.MAP_SCALE)) + 1
		for t in steps:
			_stamp(a.lerp(b, float(t) / steps), radius, height)


func _stamp(c: Vector2, radius: float, height: float) -> void:
	radius *= Defs.MAP_SCALE  # le montagne crescono con la penisola, l'altezza no
	var r := int(radius)
	var x0 := clampi(int(c.x) - r, 0, WX - 1)
	var x1 := clampi(int(c.x) + r, 0, WX - 1)
	var z0 := clampi(int(c.y) - r, 0, WZ - 1)
	var z1 := clampi(int(c.y) + r, 0, WZ - 1)
	var r2 := radius * radius
	for z in range(z0, z1 + 1):
		var dz := z - c.y
		# solo la corda del cerchio su questa riga (+1 di margine: il test q < 1 resta quello di prima)
		var rest := r2 - dz * dz
		if rest <= 0.0:
			continue
		var half := sqrt(rest)
		for x in range(maxi(x0, int(c.x - half) - 1), mini(x1, int(c.x + half) + 1) + 1):
			var dx := x - c.x
			var q := (dx * dx + dz * dz) / r2
			if q < 1.0:
				var v := height * (1.0 - q) * (1.0 - q)
				var i := x + z * WX
				if v > mtn[i]:
					mtn[i] = v


func _stamp_mountains() -> void:
	_stamp_polyline(Defs.ALPS, 49.0, 32.0)
	_stamp_polyline(Defs.APENNINES, 29.0, 14.0)
	_stamp(Defs.geo(9.15, 40.2), 42.0, 9.0)   # Sardegna
	_stamp(Defs.geo(9.05, 42.2), 24.0, 11.0)  # Corsica
	_stamp(Defs.geo(14.2, 37.7), 42.0, 6.0)   # interno Sicilia
	_stamp(Defs.geo(15.8, 41.6), 16.0, 4.0)    # Gargano
	_stamp(Defs.geo(15.0, 37.75), 36.0, 32.0) # Etna
	_stamp(Defs.geo(14.42, 40.72), 16.0, 14.0)  # Vesuvio


func _compute_heights() -> void:
	var po := PackedByteArray()
	po.resize(WX * WZ)
	for s in range(Defs.PO.size() - 1):
		var a := Defs.geo(Defs.PO[s][0], Defs.PO[s][1])
		var b := Defs.geo(Defs.PO[s + 1][0], Defs.PO[s + 1][1])
		var steps := int(a.distance_to(b)) + 1
		for t in steps:
			var p := a.lerp(b, float(t) / steps)
			var wob := noise_a.get_noise_2d(p.x * 3.0, p.y * 3.0) * 7.0 * Defs.MAP_SCALE
			var ix := int(p.x)
			var iz := int(p.y + wob)
			for dz in range(0, 2):
				for dx in range(0, 2):
					if ix + dx >= 0 and ix + dx < WX and iz + dz >= 0 and iz + dz < WZ:
						po[ix + dx + (iz + dz) * WX] = 1
	for z in WZ:
		for x in WX:
			var i := x + z * WX
			var na := noise_a.get_noise_2d(x, z)
			var coast := sdf[i] + noise_b.get_noise_2d(x, z) * 3.5 + na * 3.0
			if coast <= 0.0:
				h[i] = clampi(int(SEA - 1 + coast * 0.45), 2, SEA - 1)
				continue
			var hills := (na + 0.45) * 3.2
			var m := mtn[i]
			var ridge := noise_c.get_noise_2d(x, z)
			var tall := m * (0.72 + 0.5 * ridge) if m > 0.0 else 0.0
			var v := SEA + minf(coast * 0.55, 1.0) + maxf(hills, 0.0) * minf(coast * 0.12, 1.0) + tall
			h[i] = int(v)
			if po[i] == 1 and h[i] < SEA + 6:
				h[i] = SEA - 1


func _flatten_castles() -> Array:
	var out: Array = []
	for def in Defs.CASTLES:
		var p := Defs.geo(def.lon, def.lat)
		var cx := int(p.x)
		var cz := int(p.y)
		var base := maxi(h[cx + cz * WX], SEA + 2)
		base = mini(base, SEA + 8)
		const INNER := R * 1.42 + 8.0
		const OUTER := R * 1.42 + 20.0
		for z in range(cz - int(OUTER), cz + int(OUTER) + 1):
			for x in range(cx - int(OUTER), cx + int(OUTER) + 1):
				if x < 0 or z < 0 or x >= WX or z >= WZ:
					continue
				var d := Vector2(x - cx, z - cz).length()
				if d >= OUTER:
					continue
				var i := x + z * WX
				if sdf[i] <= 0.0 and d > R + 6.0:
					continue
				if d < INNER:
					h[i] = base
					sdf[i] = maxf(sdf[i], 4.0)
				else:
					var t := (d - INNER) / (OUTER - INNER)
					h[i] = int(lerpf(float(base), float(h[i]), t * t * (3.0 - 2.0 * t)))
				_no_tree[i] = 1
		var gdir: int = def.gate
		var dir: Vector2i = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)][gdir]
		out.append({"name": def.name, "x": cx, "z": cz, "base": base, "dir": dir, "wall": def.wall, "house": def.house})
	return out


func _draw_roads(cdefs: Array) -> void:
	for pair in Defs.ROADS:
		var a: Dictionary = cdefs[pair[0]]
		var b: Dictionary = cdefs[pair[1]]
		var pa := Vector2(a.x, a.z)
		var pb := Vector2(b.x, b.z)
		var steps := int(pa.distance_to(pb))
		for t in steps:
			var f := float(t) / steps
			var side := (pb - pa).normalized().orthogonal()
			var p := pa.lerp(pb, f) + side * sin(f * PI) * noise_d.get_noise_2d(pa.x, pb.y) * 26.0 * Defs.MAP_SCALE
			for dz in range(-1, 1):
				for dx in range(-1, 1):
					var x := int(p.x) + dx
					var z := int(p.y) + dz
					if x >= 0 and z >= 0 and x < WX and z < WZ and h[x + z * WX] >= SEA:
						_road[x + z * WX] = 1
						_no_tree[x + z * WX] = 1


func _fill_terrain() -> void:
	var v := w.vox
	var ct := w.col_top
	var cs := w.col_sol
	var dy := VoxelWorld.LAYER_DY
	for z in range(0, WZ):
		for x in range(0, WX):
			var i := x + z * WX
			var hh := h[i]
			var top := Defs.GRASS
			var slope := 0
			if x > 0 and z > 0 and x < WX - 1 and z < WZ - 1:
				slope = maxi(absi(hh - h[i + 1]), maxi(absi(hh - h[i - 1]), maxi(absi(hh - h[i + WX]), absi(hh - h[i - WX]))))
			if hh < SEA:
				top = Defs.SAND
			elif hh <= SEA + 1 and sdf[i] < 3.0:
				top = Defs.SAND
			elif hh > SEA + 27:
				top = Defs.SNOW
			elif hh > SEA + 17 or slope >= 3:
				top = Defs.ROCK
			else:
				var n := noise_b.get_noise_2d(x * 0.8, z * 0.8)
				var patch := noise_d.get_noise_2d(x, z)
				if _road[i] == 1:
					top = Defs.ROAD
				elif hh < SEA + 6 and patch > 0.22:
					top = Defs.FARM if n > 0.0 else Defs.VINE
				elif n > 0.08:
					top = Defs.GRASS2
			# sotto la cima: sabbia sotto il mare, roccia in montagna, altrimenti roccia e 4 di terra
			var col := i
			if hh < SEA:
				for y in hh:
					v[col] = Defs.SAND
					col += dy
			elif hh > SEA + 9:
				for y in hh:
					v[col] = Defs.ROCK
					col += dy
			else:
				var dirt_from := hh - 4
				for y in hh:
					v[col] = Defs.ROCK if y < dirt_from else Defs.DIRT
					col += dy
			v[i + hh * dy] = top
			# colonna piena da 0 a hh: cache già pronte, senza rileggere i voxel
			ct[i] = hh + 1
			cs[i] = hh + 1
	# crateri
	_crater(Defs.geo(15.0, 37.75), 3, Defs.LAVA)
	_crater(Defs.geo(14.42, 40.72), 2, Defs.ROCK)


func _crater(c: Vector2, radius: int, m: int) -> void:
	var cx := int(c.x)
	var cz := int(c.y)
	var hh := h[cx + cz * WX]
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + z * z > radius * radius:
				continue
			var i := cx + x + (cz + z) * WX
			var y := h[i]
			while y > hh - 2:
				w.put(cx + x, y, cz + z, Defs.AIR)
				y -= 1
			w.put(cx + x, y, cz + z, m)


# ---------------------------------------------------------------- castello
func _p(x: int, y: int, z: int, m: int) -> void:
	w.put(x, y, z, m)
	if _bp != null:
		_bp[w.index(x, y, z)] = m


func _box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, m: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				_p(x, y, z, m)


func _build_castle(id: int, c: Dictionary) -> Dictionary:
	_bp = {}
	var cx: int = c.x
	var cz: int = c.z
	var b: int = c.base + 1
	var wm: int = c.wall
	var dir: Vector2i = c.dir
	var accent: int = Defs.STONE2 if wm != Defs.STONE2 else Defs.STONE
	var banners := PackedInt32Array()
	var towers: Array = []
	var slots: Array = []
	# mura spesse WALL_T, con merli ghibellini 2x2 sul bordo esterno
	for dz in range(-R, R + 1):
		for dx in range(-R, R + 1):
			var ring := maxi(absi(dx), absi(dz))
			if ring <= R - WALL_T:
				continue
			var x := cx + dx
			var z := cz + dz
			for y in range(b, b + WALL_H):
				_p(x, y, z, wm if (y - b) != WALL_H - 3 else accent)
			if ring >= R - 1:
				var along := dx + dz
				if posmod(floori(along / 2.0), 2) == 0:
					_p(x, b + WALL_H, z, accent)
					_p(x, b + WALL_H + 1, z, accent)
	# torri d'angolo
	const TR := 6
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var tx := cx + sx * R
			var tz := cz + sz * R
			for dz in range(-TR, TR + 1):
				for dx in range(-TR, TR + 1):
					var d2 := dx * dx + dz * dz
					if d2 > TR * TR + 4:
						continue
					for y in range(b, b + TOWER_H):
						_p(tx + dx, y, tz + dz, wm if (y - b) % 8 != 7 else accent)
					if d2 >= (TR - 1) * (TR - 1) and posmod(floori((dx + dz) / 2.0), 2) == 0:
						_p(tx + dx, b + TOWER_H, tz + dz, accent)
						_p(tx + dx, b + TOWER_H + 1, tz + dz, accent)
			# stendardo della torre
			for y in range(b + TOWER_H, b + TOWER_H + 8):
				_p(tx, y, tz, Defs.WOOD)
			for k in range(1, 5):
				for y in range(b + TOWER_H + 4, b + TOWER_H + 8):
					var bx := tx + sx * k
					var i := w.index(bx, y, tz)
					banners.append(i)
					_p(bx, y, tz, Defs.TEAM0 + int(c.house))
			towers.append(Vector3(tx + 0.5, b + TOWER_H + 1, tz + 0.5))
	# porta: larga 9, alta 9; il portone sta sul filo esterno, dietro si passa
	var side := Vector2i(dir.y, dir.x)
	for k in range(-4, 5):
		var hgt := 9 if absi(k) < 4 else 8
		for t in WALL_T:
			var ox := dir.x * (R - t) + side.x * k
			var oz := dir.y * (R - t) + side.y * k
			for y in range(b, b + hgt):
				_erase(cx + ox, y, cz + oz)
				if t == 0:
					_p(cx + ox, y, cz + oz, Defs.GATE)
	# mastio: pianterreno libero (lì siede il re), finestre, piani ogni 10
	var kc := Vector2i(cx - dir.x * KEEP_BACK, cz - dir.y * KEEP_BACK)
	const K := KEEP_K
	const KH := KEEP_H
	for dz in range(-K, K + 1):
		for dx in range(-K, K + 1):
			var edge := maxi(absi(dx), absi(dz))
			for y in range(b, b + KH):
				var is_win: bool = edge == K and (y - b) % 10 >= 5 and (y - b) % 10 <= 6 and (absi(dx) == 4 or absi(dz) == 4 or absi(dx) == 3 or absi(dz) == 3)
				if is_win and y - b > 8:
					continue
				# porta del mastio verso il cortile: di là c'è il re, seduto sul gabinetto
				var door: bool = y - b < 5 and absi(dx * dir.y + dz * dir.x) <= 2 and dx * dir.x + dz * dir.y == K
				if door:
					continue
				if edge == K or (y - b) % 10 == 9:
					_p(kc.x + dx, y, kc.y + dz, wm if (y - b) % 12 != 11 else accent)
			if edge == K and posmod(floori((dx + dz) / 2.0), 2) == 0:
				_p(kc.x + dx, b + KH, kc.y + dz, accent)
				_p(kc.x + dx, b + KH + 1, kc.y + dz, accent)
	# gonfalone del mastio
	for y in range(b + KH - 1, b + KH + 10):
		_p(kc.x, y, kc.y, Defs.WOOD)
	for k in range(1, 9):
		for y in range(b + KH + 5, b + KH + 10):
			var bx := kc.x + k
			var i := w.index(bx, y, kc.y)
			banners.append(i)
			_p(bx, y, kc.y, Defs.TEAM0 + int(c.house))
	# postazioni sul cammino di ronda (al centro dello spessore delle mura)
	var walk := R - 1
	for t in range(-R + 6, R - 5, 3):
		for s: Vector2i in [Vector2i(t, walk), Vector2i(t, -walk), Vector2i(walk, t), Vector2i(-walk, t)]:
			slots.append(Vector3(cx + s.x + 0.5, b + WALL_H, cz + s.y + 0.5))
	var blueprint := PackedInt64Array()
	for i: int in _bp:
		blueprint.append((i << Defs.EDIT_SHIFT) | int(_bp[i]))
	blueprint.sort()
	_bp = null
	var center := Vector3(cx + 0.5, b, cz + 0.5)
	return {
		"id": id, "name": c.name, "center": center, "dir": Vector3(dir.x, 0, dir.y), "base": b,
		"gate_out": center + Vector3(dir.x, 0, dir.y) * (R + 5), "gate_in": center + Vector3(dir.x, 0, dir.y) * (R - WALL_T - 2),
		"rally": center + Vector3(dir.x, 0, dir.y) * 12.0, "keep": Vector3(kc.x + 0.5, b, kc.y + 0.5),
		# il re siede al pianterreno del mastio, di fronte alla porta; chi lo attacca entra di lì
		"king": Vector3(kc.x + 0.5, b, kc.y + 0.5) + Vector3(dir.x, 0, dir.y) * 3.0,
		"king_door": Vector3(kc.x + 0.5, b, kc.y + 0.5) + Vector3(dir.x, 0, dir.y) * (KEEP_K + 2.0),
		"towers": towers, "slots": slots, "banners": banners, "blueprint": blueprint,
		"start_house": c.house,
		# la signoria minore che tiene il castello all'inizio (vedi Defs.CASTLES)
		"lord": String(Defs.CASTLES[id].get("lord", "")), "lord_of": String(Defs.CASTLES[id].get("lord_of", "")),
		"lord_title": String(Defs.CASTLES[id].get("lord_title", "")), "trait": String(Defs.CASTLES[id].get("trait", "")), "lord_color": Defs.CASTLES[id].get("lord_color", Defs.HOUSES[Defs.NEUTRAL].color),
	}


func _erase(x: int, y: int, z: int) -> void:
	w.put(x, y, z, Defs.AIR)
	if _bp != null:
		_bp.erase(w.index(x, y, z))


func _inner_house(x: int, z: int, b: int) -> void:
	_box(x - 4, b, z - 3, x + 4, b + 4, z + 3, Defs.PLASTER)
	_box(x - 4, b + 5, z - 3, x + 4, b + 5, z + 3, Defs.ROOF)
	_box(x - 4, b + 6, z - 1, x + 4, b + 7, z + 1, Defs.ROOF)


# ---------------------------------------------------------------- borghi e monumenti
func _build_village(c: Dictionary) -> void:
	var cx: int = c.x
	var cz: int = c.z
	var dir: Vector2i = c.dir
	var b: int = c.base + 1
	for n in 22:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(R + 10.0, R + 18.0)
		var x := cx + int(cos(ang) * dist)
		var z := cz + int(sin(ang) * dist)
		# lascia libera la strada davanti alla porta
		var gate_vec := Vector2(dir).normalized()
		if Vector2(x - cx, z - cz).normalized().dot(gate_vec) > 0.8:
			continue
		var hw := rng.randi_range(1, 2)
		var hd := rng.randi_range(1, 2)
		var hh := rng.randi_range(2, 4)
		_house_at(x, z, b, hw, hd, hh)


func _house_at(x: int, z: int, b: int, hw: int, hd: int, hh: int) -> void:
	if h[x + z * WX] != b - 1:
		return
	for y in range(b, b + hh):
		for dz in range(-hd, hd + 1):
			for dx in range(-hw, hw + 1):
				w.put(x + dx, y, z + dz, Defs.PLASTER if (absi(dx) == hw or absi(dz) == hd) else Defs.AIR)
	for dz in range(-hd, hd + 1):
		for dx in range(-hw - 0, hw + 1):
			w.put(x + dx, b + hh, z + dz, Defs.ROOF)
	for dx in range(-hw, hw + 1):
		w.put(x + dx, b + hh + 1, z, Defs.ROOF)


func _build_landmarks(cdefs: Array) -> void:
	# Colosseo vicino a Roma
	var roma: Dictionary = cdefs[7]
	_colosseo(roma.x - 28 * CS - 6, roma.z - 4 * CS, roma.base + 1)
	# Torre di Pisa
	var pisa := Defs.geo(10.45, 43.72)
	_pisa(int(pisa.x), int(pisa.y))
	# Cupola di Santa Maria del Fiore
	var fi: Dictionary = cdefs[5]
	_dome(fi.x + 18 * CS + 6, fi.z + 14 * CS, fi.base + 1)
	# Campanile di San Marco
	var ve: Dictionary = cdefs[2]
	_campanile(ve.x - 20 * CS - 4, ve.z - 12 * CS, ve.base + 1)
	# Duomo di Milano
	var mi: Dictionary = cdefs[1]
	_duomo(mi.x + 20 * CS + 6, mi.z - 13 * CS, mi.base + 1)


func _colosseo(cx: int, cz: int, b: int) -> void:
	for z in range(-10, 11):
		for x in range(-10, 11):
			var d := Vector2(x, z * 1.2).length()
			if d > 9.5 or d < 5.5:
				continue
			var ground := h[cx + x + (cz + z) * WX] + 1
			for y in range(ground, b + 8):
				var arch := posmod(x + z, 3) == 0 and (y - b) % 3 != 2 and d > 8.5
				if not arch and (d > 8.5 or y - b < 4):
					w.put(cx + x, y, cz + z, Defs.MARBLE)


func _pisa(cx: int, cz: int) -> void:
	var b := h[cx + cz * WX] + 1
	for y in 17:
		var off := int(y * 0.22)
		for z in range(-2, 3):
			for x in range(-2, 3):
				var d2 := x * x + z * z
				if d2 > 6:
					continue
				if d2 >= 4 and y % 3 != 2 and posmod(x + z + y, 2) == 0:
					continue
				w.put(cx + x + off, b + y, cz + z, Defs.MARBLE)
	_no_tree_area(cx, cz, 5)


func _dome(cx: int, cz: int, b: int) -> void:
	_cyl(cx, cz, b, b + 5, 5, Defs.MARBLE)
	for y in 7:
		var r := sqrt(maxf(0.0, 36.0 - y * y))
		for z in range(-6, 7):
			for x in range(-6, 7):
				if x * x + z * z <= r * r:
					w.put(cx + x, b + 6 + y, cz + z, Defs.DOME)
	w.put(cx, b + 13, cz, Defs.MARBLE)
	w.put(cx, b + 14, cz, Defs.MARBLE)


func _campanile(cx: int, cz: int, b: int) -> void:
	for y in range(b, b + 16):
		for z in range(-1, 2):
			for x in range(-1, 2):
				w.put(cx + x, y, cz + z, Defs.BRICK)
	for y in range(0, 3):
		w.put(cx, b + 16 + y, cz, Defs.CYPRESS)


func _duomo(cx: int, cz: int, b: int) -> void:
	for y in range(b, b + 6):
		for z in range(-5, 6):
			for x in range(-3, 4):
				w.put(cx + x, y, cz + z, Defs.MARBLE)
	for z in range(-5, 6, 2):
		for x: int in [-3, 0, 3]:
			var extra := 3 if x == 0 else 1
			for y in range(b + 6, b + 6 + extra):
				w.put(cx + x, y, cz + z, Defs.MARBLE)


func _cyl(cx: int, cz: int, y0: int, y1: int, r: int, m: int) -> void:
	for y in range(y0, y1):
		for z in range(-r, r + 1):
			for x in range(-r, r + 1):
				if x * x + z * z <= r * r:
					w.put(cx + x, y, cz + z, m)


func _no_tree_area(cx: int, cz: int, r: int) -> void:
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x >= 0 and z >= 0 and x < WX and z < WZ:
				_no_tree[x + z * WX] = 1


# ---------------------------------------------------------------- alberi
func _plant_trees(_cdefs: Array) -> void:
	for z in range(2, WZ - 2, 6):
		for x in range(2, WX - 2, 6):
			var px := x + rng.randi_range(-1, 1)
			var pz := z + rng.randi_range(-1, 1)
			var i := px + pz * WX
			if _no_tree[i] == 1 or h[i] <= SEA + 1 or h[i] > SEA + 16:
				continue
			var forest := noise_a.get_noise_2d(px * 2.5 + 300.0, pz * 2.5)
			if forest < 0.02:
				continue
			var y := h[i] + 1
			var lat_band := float(pz) / WZ
			if lat_band > 0.28 and lat_band < 0.6 and rng.randf() < 0.65:
				_cypress(px, y, pz)
			elif lat_band >= 0.6 and rng.randf() < 0.6:
				_olive(px, y, pz)
			else:
				_pine(px, y, pz)


func _cypress(x: int, y: int, z: int) -> void:
	w.put(x, y, z, Defs.TRUNK)
	var hh := rng.randi_range(4, 6)
	for k in range(1, hh):
		w.put(x, y + k, z, Defs.CYPRESS)
	if hh > 4:
		for n: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			w.put(x + n.x, y + 2, z + n.y, Defs.CYPRESS)


func _olive(x: int, y: int, z: int) -> void:
	w.put(x, y, z, Defs.TRUNK)
	w.put(x, y + 1, z, Defs.TRUNK)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			w.put(x + dx, y + 2, z + dz, Defs.OLIVE)
	w.put(x, y + 3, z, Defs.OLIVE)


func _pine(x: int, y: int, z: int) -> void:
	for k in 3:
		w.put(x, y + k, z, Defs.TRUNK)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) + absi(dz) <= 3:
				w.put(x + dx, y + 3, z + dz, Defs.LEAF)
			if absi(dx) + absi(dz) <= 1:
				w.put(x + dx, y + 4, z + dz, Defs.LEAF)
