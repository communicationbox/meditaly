class_name Buildings
extends RefCounted
## Edifici costruibili fuori dalle mura, in voxel: si possono abbattere, e chi li perde perde il
## vantaggio. Disegno a risoluzione base: lx da -2 a 2 lungo la facciata, lz da 0 (facciata) a 4
## (retro), y da 0; ogni voxel del disegno diventa un cubo CS x CS x CS.

const W := 2
const D := 4
const H := 15
## Lato dell'area occupata, in voxel di mondo.
const FOOT := (W * 2 + 1) * WorldGen.CS
## Quanto lontano da un proprio castello si può costruire, e distanza minima dalle mura e fra edifici.
const RANGE := WorldGen.R + 75.0
const WALL_GAP := WorldGen.R + 21.0  # attorno alle mura resta un anello libero per aggirare il castello
const SPACING := FOOT + 9.0  # fra un edificio e l'altro si passa comodi
const MAX_PER_HOUSE := 16
const GATE_LANE := FOOT / 2.0 + 10.0


## Indice di mondo -> materiale: fondazione livellata (terra e lastricato) e l'edificio sopra.
## Le celle dell'area che non fanno parte dell'edificio diventano AIR (via alberi e terreno in più).
static func voxels(world: VoxelWorld, ctr: Vector2i, base: int, face: Vector2i, type: int) -> Dictionary:
	var local := _shape(type) if type >= 0 else {}
	var out := {}
	var cs := WorldGen.CS
	for z in range(0, FOOT):
		for x in range(-W * cs, (W + 1) * cs):
			var wp := cell(ctr, face, x, z)
			var top := ground_y(world, wp.x, wp.y)
			for y in range(mini(top, base - 1), base):
				out[world.index(wp.x, y, wp.y)] = Defs.ROAD if y == base - 1 else Defs.DIRT
			for y in range(0, mini((H + 1) * cs, Defs.WY - 1 - base)):
				var key := Vector3i(floori(float(x) / cs), y / cs, z / cs)
				var m: int = local.get(key, Defs.AIR)
				var i := world.index(wp.x, base + y, wp.y)
				if m != Defs.AIR or world.vox[i] != Defs.AIR:
					out[i] = m
	return out


## Cella di mondo per (x lungo la facciata, z in profondità dalla facciata).
static func cell(ctr: Vector2i, face: Vector2i, x: int, z: int) -> Vector2i:
	var across := Vector2i(-face.y, face.x)
	return ctr + across * x - face * (z - FOOT / 2)


## Dove sta il personaggio della bottega (davanti alla facciata) e verso dove guarda.
static func front(ctr: Vector2i, base: int, face: Vector2i) -> Array:
	var f := Vector3(face.x, 0, face.y)
	var c := Vector3(ctr.x + 0.5, base, ctr.y + 0.5)
	return [c + f * (FOOT / 2.0 + 2.5), f]


## Primo voxel d'aria sopra il terreno, ignorando alberi e foglie.
static func ground_y(world: VoxelWorld, x: int, z: int) -> int:
	var y := world.top_y(x, z)
	while y > 1:
		var m := world.get_v(x, y - 1, z)
		if m != Defs.TRUNK and m != Defs.LEAF and m != Defs.CYPRESS and m != Defs.OLIVE:
			break
		y -= 1
	return y


## La facciata guarda il proprio castello più vicino (una delle 4 direzioni).
static func face_toward(p: Vector3, target: Vector3) -> Vector2i:
	var d := Vector2(target.x - p.x, target.z - p.z)
	if absf(d.x) > absf(d.y):
		return Vector2i(signi(int(signf(d.x))), 0)
	return Vector2i(0, signi(int(signf(d.y))))


## Perché non si può costruire qui ("" = si può). owners[i] = padrone del castello i;
## others = centri [x, z] degli altri edifici.
static func check_spot(world: VoxelWorld, castles: Array, owners: Array, others: Array, team: int, p: Vector3) -> String:
	var m := FOOT + 2
	if p.x < m or p.z < m or p.x > Defs.WX - m or p.z > Defs.WZ - m:
		return "Troppo vicino al bordo del mondo"
	var near_own := false
	for c: Dictionary in castles:
		var ce: Vector3 = c.center
		if absf(p.x - ce.x) < WALL_GAP and absf(p.z - ce.z) < WALL_GAP:
			return "Si costruisce fuori dalle mura"
		# davanti alla porta resta un corridoio libero: lì passano gli eserciti
		var gd: Vector3 = c.dir
		var rel := Vector3(p.x - ce.x, 0, p.z - ce.z)
		var along := rel.dot(gd)
		if along > 0.0 and along < RANGE + 20.0 and absf(rel.dot(Vector3(-gd.z, 0, gd.x))) < GATE_LANE:
			return "Davanti alla porta si lascia la strada libera"
		if int(owners[c.id]) == team and Vector2(p.x - ce.x, p.z - ce.z).length() <= RANGE:
			near_own = true
	if not near_own:
		return "Troppo lontano dai tuoi castelli"
	for o: Array in others:
		if Vector2(p.x - float(o[0]), p.z - float(o[1])).length() < SPACING:
			return "C'è già un edificio qui"
	var lo := 999
	var hi := -999
	for dz: int in [-5, 0, 5]:
		for dx: int in [-5, 0, 5]:
			var t := ground_y(world, int(p.x) + dx, int(p.z) + dz)
			if t <= Defs.SEA + 1:
				return "Qui c'è acqua"
			lo = mini(lo, t)
			hi = maxi(hi, t)
	if hi - lo > 5:
		return "Terreno troppo ripido"
	if hi + (H + 1) * WorldGen.CS >= Defs.WY - 1:
		return "Troppo in alto per costruire"
	return ""


static func _shape(type: int) -> Dictionary:
	var v := {}
	match type:
		Defs.B_CHIESA:
			_walls(v, 0, 4, Defs.PLASTER)
			_door(v, 0, 2)
			for y in range(5, 8):
				var r := 7 - y
				for lz in range(0, D + 1):
					for lx in range(-r, r + 1):
						v[Vector3i(lx, y, lz)] = Defs.ROOF
			v[Vector3i(0, 4, 0)] = Defs.GILT  # rosone
			# campanile sul retro, alto oltre le mura, con la campana d'oro e la croce
			for y in range(0, 12):
				for p: Vector2i in [Vector2i(2, 3), Vector2i(2, 4)]:
					if y != 10:
						v[Vector3i(p.x, y, p.y)] = Defs.BRICK
			v[Vector3i(2, 10, 3)] = Defs.GILT
			v[Vector3i(2, 12, 3)] = Defs.ROOF
			v[Vector3i(2, 12, 4)] = Defs.ROOF
			v[Vector3i(2, 13, 3)] = Defs.GILT
			v[Vector3i(2, 14, 3)] = Defs.GILT
		Defs.B_CASEIFICIO:
			_walls(v, 0, 3, Defs.WOOD)
			for lx in range(-1, 2):  # bottega aperta sul davanti
				for y in range(0, 3):
					v.erase(Vector3i(lx, y, 0))
			_roof_flat(v, 4, Defs.ROOF)
			for lx in range(-1, 2):
				v[Vector3i(lx, 5, 2)] = Defs.ROOF
			# forme impilate al banco e una forma gigante come insegna sul tetto
			for k: Vector3i in [Vector3i(-1, 0, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(-1, 1, 1), Vector3i(1, 1, 1), Vector3i(0, 2, 1)]:
				v[k] = Defs.CHEESE
			for y in range(6, 10):
				for lx in range(-2, 3):
					if (absi(lx) < 2 or (y > 6 and y < 9)):
						v[Vector3i(lx, y, 2)] = Defs.CHEESE
			v[Vector3i(1, 8, 1)] = Defs.SAND  # la fetta mancante: qualcuno ha assaggiato
		Defs.B_STALLA:
			for lz in range(2, D + 1):
				for lx in range(-W, W + 1):
					for y in range(0, 4):
						if absi(lx) == W or lz == D or lz == 2:
							v[Vector3i(lx, y, lz)] = Defs.WOOD
			for y in range(0, 3):
				v.erase(Vector3i(0, y, 2))
			_roof_flat(v, 4, Defs.ROOF, 2)
			# recinto davanti e balle di fieno
			for lx: int in [-2, -1, 1, 2]:
				v[Vector3i(lx, 0, 0)] = Defs.WOOD
			v[Vector3i(-W, 0, 1)] = Defs.WOOD
			v[Vector3i(W, 0, 1)] = Defs.WOOD
			v[Vector3i(-1, 0, 1)] = Defs.FARM
			v[Vector3i(1, 0, 1)] = Defs.FARM
			v[Vector3i(1, 1, 1)] = Defs.FARM
			# insegna a macchie di mucca, con le corna
			for lx in range(-2, 3):
				for y in range(5, 9):
					v[Vector3i(lx, y, 3)] = Defs.STONE2 if (lx * 3 + y * 2) % 5 == 0 else Defs.PLASTER
			v[Vector3i(-2, 9, 3)] = Defs.SAND
			v[Vector3i(2, 9, 3)] = Defs.SAND
		Defs.B_CANTINA:
			_walls(v, 0, 3, Defs.STONE2)
			_door(v, 0, 1)
			_roof_flat(v, 4, Defs.STONE2)
			# pergolato di vite in alto, sui pali
			for p: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-2, 4), Vector2i(2, 4)]:
				for y in range(5, 8):
					v[Vector3i(p.x, y, p.y)] = Defs.TRUNK
			for lz in range(0, D + 1):
				for lx in range(-W, W + 1):
					if (lx + lz) % 2 == 0 or lz == 2:
						v[Vector3i(lx, 8, lz)] = Defs.VINE
			# botte gigante come insegna e botti all'ingresso
			for y in range(5, 8):
				for lx in range(-1, 2):
					v[Vector3i(lx, y, 2)] = Defs.WOOD if y != 6 else Defs.TRUNK
			for lx: int in [-2, 2]:
				v.erase(Vector3i(lx, 0, 0))
				v.erase(Vector3i(lx, 1, 0))
			v[Vector3i(-1, 0, 0)] = Defs.WOOD
			v[Vector3i(1, 0, 0)] = Defs.WOOD
			v[Vector3i(1, 1, 0)] = Defs.WOOD
		Defs.B_ASTROLOGO:
			for y in range(0, 12):
				for lz in range(1, 4):
					for lx in range(-1, 2):
						if absi(lx) == 1 or lz != 2:
							v[Vector3i(lx, y, lz)] = Defs.AZURE if (y + lx + lz) % 4 != 0 else Defs.GILT
			_door(v, 0, 1, 1)
			for lz in range(0, 5):
				for lx in range(-2, 3):
					if absi(lx) + absi(lz - 2) <= 2:
						v[Vector3i(lx, 12, lz)] = Defs.AZURE
			for lz in range(1, 4):
				for lx in range(-1, 2):
					v[Vector3i(lx, 13, lz)] = Defs.AZURE
			v[Vector3i(0, 14, 2)] = Defs.GILT
			# cannocchiale puntato (male) verso il cielo
			for k in 3:
				v[Vector3i(0, 11 + k, 0 - k / 2)] = Defs.GILT
		Defs.B_SANTUARIO:
			for p: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-2, 4), Vector2i(2, 4), Vector2i(-2, 2), Vector2i(2, 2)]:
				for y in range(0, 5):
					v[Vector3i(p.x, y, p.y)] = Defs.MARBLE
			for lx in range(-W, W + 1):
				for y in range(0, 5):
					v[Vector3i(lx, y, D)] = Defs.MARBLE
			_roof_flat(v, 5, Defs.MARBLE)
			for lz in range(0, 5):
				for lx in range(-2, 3):
					if absi(lx) + absi(lz - 2) <= 3:
						v[Vector3i(lx, 6, lz)] = Defs.DOME
			for lz in range(1, 4):
				for lx in range(-1, 2):
					v[Vector3i(lx, 7, lz)] = Defs.DOME
			v[Vector3i(0, 8, 2)] = Defs.DOME
			v[Vector3i(0, 9, 2)] = Defs.GILT
			v[Vector3i(0, 10, 2)] = Defs.GILT
			v[Vector3i(0, 0, 3)] = Defs.GILT  # altare
	return v


static func _walls(v: Dictionary, y0: int, y1: int, m: int) -> void:
	for y in range(y0, y1 + 1):
		for lz in range(0, D + 1):
			for lx in range(-W, W + 1):
				if absi(lx) == W or lz == 0 or lz == D:
					v[Vector3i(lx, y, lz)] = m


static func _door(v: Dictionary, lx: int, top: int, lz := 0) -> void:
	for y in range(0, top + 1):
		v.erase(Vector3i(lx, y, lz))


static func _roof_flat(v: Dictionary, y: int, m: int, lz0 := 0) -> void:
	for lz in range(lz0, D + 1):
		for lx in range(-W, W + 1):
			v[Vector3i(lx, y, lz)] = m
