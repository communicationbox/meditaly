class_name UnitModels
extends RefCounted
## Modelli voxel delle unità, generati da codice. UV.x = parte animata, UV.y = perno.
## Alpha del colore = 0 per le superfici tinte con il colore della casata.

const STEEL := Color(0.62, 0.65, 0.70)
const DARK := Color(0.22, 0.20, 0.20)
const SKIN := Color(0.87, 0.67, 0.50)
const LEATHER := Color(0.36, 0.23, 0.13)
const WOODC := Color(0.47, 0.31, 0.16)
const WHITE := Color(1, 1, 1)
const IRON := Color(0.17, 0.17, 0.19)
const GOLD := Color(0.95, 0.76, 0.22)

var st: SurfaceTool
var s := 1.0


func _begin(scale_: float = 1.0) -> void:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	s = scale_


func _b(a: Vector3, b: Vector3, col: Color, part: int = 0, pivot: float = 0.0, team := false) -> void:
	VoxelWorld._setup_tables()
	var size := (b - a)
	var c := col
	c.a = 0.0 if team else 1.0
	for d in 6:
		var cs: Array = VoxelWorld._f_c[d]
		var nrm: Vector3 = VoxelWorld._f_n[d]
		for t in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = cs[t]
			st.set_color(c)
			st.set_normal(nrm)
			st.set_uv(Vector2(part / 10.0, pivot * s))
			st.add_vertex((a + Vector3(v.x * size.x, v.y * size.y, v.z * size.z)) * s)


func _legs(col: Color, y := 0.72) -> void:
	_b(Vector3(-0.25, 0.0, -0.14), Vector3(-0.03, y, 0.14), col, 1, y)
	_b(Vector3(0.03, 0.0, -0.14), Vector3(0.25, y, 0.14), col, 2, y)
	_b(Vector3(-0.26, 0.0, -0.16), Vector3(-0.02, 0.14, 0.2), LEATHER, 1, y)
	_b(Vector3(0.02, 0.0, -0.16), Vector3(0.26, 0.14, 0.2), LEATHER, 2, y)


func fante() -> ArrayMesh:
	_begin(1.15)
	_legs(Color(0.28, 0.24, 0.22))
	_b(Vector3(-0.3, 0.72, -0.17), Vector3(0.3, 1.36, 0.17), WHITE, 0, 0, true)
	_b(Vector3(-0.31, 0.74, -0.18), Vector3(0.31, 0.84, 0.18), LEATHER)
	_b(Vector3(-0.05, 0.86, 0.17), Vector3(0.05, 1.32, 0.19), WHITE)
	_b(Vector3(-0.17, 1.0, 0.17), Vector3(0.17, 1.1, 0.19), WHITE)
	_b(Vector3(-0.17, 1.38, -0.17), Vector3(0.17, 1.72, 0.17), SKIN)
	_b(Vector3(-0.21, 1.6, -0.21), Vector3(0.21, 1.8, 0.21), STEEL)
	_b(Vector3(-0.04, 1.42, 0.17), Vector3(0.04, 1.62, 0.2), STEEL)
	# braccio con scudo
	_b(Vector3(-0.44, 0.8, -0.1), Vector3(-0.3, 1.36, 0.1), STEEL, 3, 1.3)
	_b(Vector3(-0.58, 0.62, -0.28), Vector3(-0.46, 1.32, 0.3), WHITE, 3, 1.3, true)
	_b(Vector3(-0.6, 0.92, -0.05), Vector3(-0.58, 1.3, 0.05), GOLD, 3, 1.3)
	# braccio con lancia
	_b(Vector3(0.3, 0.8, -0.1), Vector3(0.44, 1.36, 0.1), STEEL, 4, 1.3)
	_b(Vector3(0.43, 0.05, 0.08), Vector3(0.5, 2.55, 0.15), WOODC, 4, 1.3)
	_b(Vector3(0.41, 2.55, 0.06), Vector3(0.52, 2.85, 0.17), STEEL, 4, 1.3)
	_b(Vector3(0.5, 2.2, 0.09), Vector3(0.82, 2.48, 0.13), WHITE, 4, 1.3, true)
	return st.commit()


func balestriere() -> ArrayMesh:
	_begin(1.12)
	_legs(WHITE * 0.75, 0.72)
	_b(Vector3(-0.28, 0.72, -0.16), Vector3(0.28, 1.34, 0.16), WHITE, 0, 0, true)
	_b(Vector3(-0.29, 0.76, -0.17), Vector3(0.29, 0.86, 0.17), LEATHER)
	_b(Vector3(-0.17, 1.36, -0.17), Vector3(0.17, 1.7, 0.17), SKIN)
	_b(Vector3(-0.2, 1.62, -0.2), Vector3(0.2, 1.74, 0.2), LEATHER)
	_b(Vector3(0.05, 1.74, -0.12), Vector3(0.15, 2.0, -0.08), Color(0.9, 0.85, 0.75))
	_b(Vector3(0.2, 0.7, -0.3), Vector3(0.38, 1.36, -0.16), LEATHER)
	# braccia in posizione di tiro
	_b(Vector3(-0.42, 0.95, -0.08), Vector3(-0.28, 1.34, 0.32), WHITE * 0.9, 3, 1.3, true)
	_b(Vector3(0.28, 0.95, -0.08), Vector3(0.42, 1.34, 0.32), WHITE * 0.9, 4, 1.3, true)
	# balestra
	_b(Vector3(-0.05, 1.05, 0.1), Vector3(0.05, 1.15, 0.95), WOODC, 4, 1.3)
	_b(Vector3(-0.52, 1.07, 0.74), Vector3(0.52, 1.14, 0.82), DARK, 4, 1.3)
	return st.commit()


func cavaliere() -> ArrayMesh:
	_begin(1.2)
	var horse := Color(0.33, 0.21, 0.12)
	# zampe
	for i in 4:
		var x := -0.42 if i % 2 == 0 else 0.2
		var z := 0.75 if i < 2 else -0.85
		var part := (1 if i == 0 or i == 3 else 2)
		_b(Vector3(x, 0, z), Vector3(x + 0.22, 0.95, z + 0.22), horse, part, 0.95)
		_b(Vector3(x - 0.01, 0, z - 0.01), Vector3(x + 0.23, 0.16, z + 0.23), DARK, part, 0.95)
	# corpo e gualdrappa
	_b(Vector3(-0.42, 0.85, -0.95), Vector3(0.42, 1.55, 1.0), horse)
	_b(Vector3(-0.47, 0.72, -0.98), Vector3(0.47, 1.6, 0.6), WHITE, 0, 0, true)
	_b(Vector3(-0.48, 0.72, -0.2), Vector3(0.48, 0.84, 0.2), GOLD)
	# collo e testa
	_b(Vector3(-0.2, 1.35, 0.85), Vector3(0.2, 2.1, 1.3), horse)
	_b(Vector3(-0.17, 1.85, 1.25), Vector3(0.17, 2.15, 1.75), horse)
	_b(Vector3(-0.19, 2.0, 1.2), Vector3(0.19, 2.25, 1.55), STEEL)
	_b(Vector3(-0.04, 1.9, 0.8), Vector3(0.04, 2.4, 1.15), DARK)
	_b(Vector3(-0.05, 1.0, -1.25), Vector3(0.05, 1.5, -0.95), DARK)
	# cavaliere
	_b(Vector3(-0.28, 1.5, -0.2), Vector3(0.28, 2.2, 0.15), STEEL)
	_b(Vector3(-0.3, 1.55, -0.22), Vector3(0.3, 2.0, 0.17), WHITE, 0, 0, true)
	_b(Vector3(-0.18, 2.2, -0.18), Vector3(0.18, 2.62, 0.18), STEEL)
	_b(Vector3(-0.19, 2.34, 0.17), Vector3(0.19, 2.42, 0.2), DARK)
	_b(Vector3(-0.05, 2.62, -0.2), Vector3(0.05, 2.98, 0.14), WHITE, 0, 0, true)
	_b(Vector3(-0.05, 2.74, -0.5), Vector3(0.05, 2.96, -0.2), WHITE, 0, 0, true)
	# braccia, scudo e lancia
	_b(Vector3(-0.42, 1.65, -0.08), Vector3(-0.28, 2.15, 0.1), STEEL, 3, 2.1)
	_b(Vector3(-0.56, 1.4, -0.3), Vector3(-0.44, 2.1, 0.3), WHITE, 3, 2.1, true)
	_b(Vector3(0.28, 1.65, -0.08), Vector3(0.42, 2.15, 0.2), STEEL, 4, 2.1)
	_b(Vector3(0.37, 1.72, -1.1), Vector3(0.44, 1.8, 2.4), Color(0.85, 0.82, 0.7), 4, 2.1)
	_b(Vector3(0.36, 1.71, 2.4), Vector3(0.45, 1.81, 2.75), STEEL, 4, 2.1)
	return st.commit()


func ariete() -> ArrayMesh:
	_begin(1.15)
	for z: float in [-1.6, 1.3]:
		for x: float in [-1.15, 0.95]:
			_b(Vector3(x, 0, z), Vector3(x + 0.2, 0.7, z + 0.7), DARK)
	_b(Vector3(-1.0, 0.45, -2.0), Vector3(1.0, 0.65, 2.0), WOODC)
	for z: float in [-1.85, -0.1, 1.65]:
		_b(Vector3(-0.95, 0.6, z), Vector3(-0.8, 2.4, z + 0.2), WOODC)
		_b(Vector3(0.8, 0.6, z), Vector3(0.95, 2.4, z + 0.2), WOODC)
	# tetto spiovente con i colori di casata
	_b(Vector3(-1.2, 2.4, -2.1), Vector3(1.2, 2.6, 2.1), WHITE, 0, 0, true)
	_b(Vector3(-0.8, 2.6, -2.1), Vector3(0.8, 2.85, 2.1), WHITE * 0.85, 0, 0, true)
	_b(Vector3(-0.35, 2.85, -2.1), Vector3(0.35, 3.05, 2.1), LEATHER)
	# tronco oscillante
	_b(Vector3(-0.28, 1.1, -2.3), Vector3(0.28, 1.65, 2.5), Color(0.38, 0.25, 0.14), 5)
	_b(Vector3(-0.34, 1.05, 2.5), Vector3(0.34, 1.7, 3.05), IRON, 5)
	_b(Vector3(-0.3, 1.65, -0.1), Vector3(0.3, 2.4, 0.0), LEATHER, 0)
	return st.commit()


func catapulta() -> ArrayMesh:
	_begin(1.2)
	for z: float in [-1.5, 1.0]:
		for x: float in [-1.25, 1.05]:
			_b(Vector3(x, 0, z), Vector3(x + 0.2, 0.8, z + 0.8), DARK)
	_b(Vector3(-1.1, 0.5, -1.7), Vector3(-0.8, 0.8, 1.9), WOODC)
	_b(Vector3(0.8, 0.5, -1.7), Vector3(1.1, 0.8, 1.9), WOODC)
	_b(Vector3(-1.1, 0.5, -1.2), Vector3(1.1, 0.75, -0.95), WOODC)
	_b(Vector3(-1.1, 0.5, 1.4), Vector3(1.1, 0.75, 1.65), WOODC)
	# montanti e traversa
	_b(Vector3(-1.05, 0.8, 0.25), Vector3(-0.8, 2.4, 0.5), WOODC)
	_b(Vector3(0.8, 0.8, 0.25), Vector3(1.05, 2.4, 0.5), WOODC)
	_b(Vector3(-1.05, 2.4, 0.2), Vector3(1.05, 2.68, 0.55), Color(0.38, 0.25, 0.14))
	# braccio che scatta
	_b(Vector3(-0.13, 0.9, -2.0), Vector3(0.13, 1.15, 0.5), Color(0.55, 0.38, 0.2), 6, 1.0)
	_b(Vector3(-0.4, 0.85, -2.5), Vector3(0.4, 1.3, -1.8), LEATHER, 6, 1.0)
	_b(Vector3(-0.3, 1.2, -2.4), Vector3(0.3, 1.65, -1.9), Color(0.6, 0.58, 0.54), 6, 1.0)
	# stendardo
	_b(Vector3(-1.05, 2.68, 0.3), Vector3(-0.95, 3.8, 0.4), WOODC)
	_b(Vector3(-0.95, 3.2, 0.32), Vector3(-0.2, 3.75, 0.38), WHITE, 7, 0, true)
	# serventi
	_b(Vector3(0.3, 0.75, 1.75), Vector3(0.75, 1.5, 2.1), WHITE, 0, 0, true)
	_b(Vector3(0.38, 1.5, 1.8), Vector3(0.68, 1.8, 2.05), SKIN)
	return st.commit()


func bombarda() -> ArrayMesh:
	_begin(1.2)
	for x: float in [-0.95, 0.75]:
		_b(Vector3(x, 0, -0.6), Vector3(x + 0.22, 1.0, 0.4), DARK)
	_b(Vector3(-0.75, 0.3, -1.6), Vector3(0.75, 0.75, 1.3), WOODC)
	_b(Vector3(-0.55, 0.75, -1.5), Vector3(0.55, 1.5, 1.8), IRON, 5)
	_b(Vector3(-0.65, 0.65, 1.8), Vector3(0.65, 1.6, 2.2), IRON * 1.4, 5)
	_b(Vector3(-0.6, 0.7, 0.5), Vector3(0.6, 1.55, 0.7), IRON * 1.6, 5)
	_b(Vector3(-0.6, 0.7, -0.6), Vector3(0.6, 1.55, -0.4), IRON * 1.6, 5)
	_b(Vector3(-0.38, 0.88, 2.2), Vector3(0.38, 1.37, 2.21), Color(0, 0, 0), 5)
	_b(Vector3(-0.75, 1.5, -1.5), Vector3(-0.65, 3.0, -1.4), WOODC)
	_b(Vector3(-0.65, 2.45, -1.48), Vector3(0.1, 2.95, -1.42), WHITE, 7, 0, true)
	_b(Vector3(0.7, 0.7, -1.9), Vector3(1.15, 1.45, -1.5), WHITE, 0, 0, true)
	_b(Vector3(0.78, 1.45, -1.85), Vector3(1.08, 1.75, -1.55), SKIN)
	return st.commit()


func barca() -> ArrayMesh:
	_begin(1.25)
	var hull := Color(0.42, 0.26, 0.13)
	_b(Vector3(-0.65, -0.3, -1.3), Vector3(0.65, 0.3, 1.3), hull)
	_b(Vector3(-0.4, -0.25, 1.3), Vector3(0.4, 0.35, 1.85), hull)
	_b(Vector3(-0.15, 0.0, 1.85), Vector3(0.15, 0.6, 2.25), hull)
	_b(Vector3(-0.4, -0.2, -1.6), Vector3(0.4, 0.35, -1.3), hull)
	_b(Vector3(-0.72, 0.28, -1.32), Vector3(0.72, 0.38, 1.32), WHITE, 0, 0, true)
	_b(Vector3(-0.06, 0.3, -0.1), Vector3(0.06, 3.0, 0.02), WOODC)
	_b(Vector3(-0.9, 1.05, -0.05), Vector3(0.9, 2.75, 0.0), WHITE, 7, 0, true)
	_b(Vector3(-0.95, 2.78, -0.08), Vector3(0.95, 2.86, 0.03), WOODC)
	_b(Vector3(-0.15, 1.75, -0.07), Vector3(0.15, 2.45, 0.02), GOLD)
	_b(Vector3(-0.3, 1.95, -0.07), Vector3(0.3, 2.2, 0.02), GOLD)
	_b(Vector3(-0.2, 0.3, 0.5), Vector3(0.2, 0.95, 0.85), WHITE * 0.9, 0, 0, true)
	_b(Vector3(-0.14, 0.95, 0.55), Vector3(0.14, 1.22, 0.8), SKIN)
	return st.commit()


func cow() -> ArrayMesh:
	_begin(1.25)
	var w := Color(0.95, 0.94, 0.9)
	var bl := Color(0.08, 0.08, 0.1)
	for x: float in [-0.5, 0.25]:
		for z: float in [-0.8, 0.65]:
			_b(Vector3(x, 0, z), Vector3(x + 0.25, 0.7, z + 0.25), w)
	_b(Vector3(-0.55, 0.6, -1.0), Vector3(0.55, 1.45, 1.0), w)
	_b(Vector3(-0.56, 0.9, -0.5), Vector3(0.1, 1.46, 0.2), bl)
	_b(Vector3(0.0, 0.7, 0.4), Vector3(0.56, 1.25, 0.9), bl)
	_b(Vector3(-0.3, 1.0, 1.0), Vector3(0.3, 1.65, 1.6), w)
	_b(Vector3(-0.25, 1.0, 1.55), Vector3(0.25, 1.28, 1.75), Color(0.95, 0.68, 0.68))
	_b(Vector3(-0.42, 1.55, 1.15), Vector3(-0.3, 1.8, 1.25), Color(0.85, 0.8, 0.6))
	_b(Vector3(0.3, 1.55, 1.15), Vector3(0.42, 1.8, 1.25), Color(0.85, 0.8, 0.6))
	_b(Vector3(-0.2, 0.42, -0.5), Vector3(0.2, 0.62, 0.0), Color(0.95, 0.68, 0.68))
	return st.commit()


## Forma di Parmigiano: asse lungo X.
func parmigiano(radius: float) -> ArrayMesh:
	_begin(1.0)
	var rind := Color(0.82, 0.58, 0.16)
	var paste := Color(0.97, 0.84, 0.42)
	var hw := radius * 0.42
	for k in range(int(-radius), int(radius)):
		var zz := k + 0.5
		var half := sqrt(maxf(radius * radius - zz * zz, 0.0))
		_b(Vector3(-hw, -half, k), Vector3(hw, half, k + 1.0), rind)
		_b(Vector3(-hw - 0.08, -half * 0.8, k), Vector3(hw + 0.08, half * 0.8, k + 1.0), paste)
	# scritte puntinate sulla crosta
	for k in 8:
		var a := k * TAU / 8.0
		_b(Vector3(-hw - 0.14, sin(a) * radius * 0.55 - 0.3, cos(a) * radius * 0.55 - 0.3), Vector3(hw + 0.14, sin(a) * radius * 0.55 + 0.3, cos(a) * radius * 0.55 + 0.3), rind)
	return st.commit()


## Il re sul gabinetto, rivolto in avanti (+Z). La veste prende il colore della casata
## (o quello dato, per il re che vola via). Parte 4 = braccio col giornale, che sventola quando lo attaccano.
func re(robe := WHITE, team := true) -> ArrayMesh:
	_begin(1.2)
	# porcellana un po' azzurrina, con le ombre: bianca come la veste del Podestà si confondeva
	var por := Color(0.9, 0.95, 1.0)
	var por2 := Color(0.72, 0.8, 0.88)
	var seat := Color(0.98, 0.98, 0.98)
	# gabinetto vero: piede stretto, vaso che si allarga e sporge ai lati del re,
	# sedile ad anello col bordo scuro, coperchio alzato bianco dietro la schiena
	_b(Vector3(-0.2, 0.0, -0.15), Vector3(0.2, 0.08, 0.4), por2)
	_b(Vector3(-0.17, 0.08, -0.12), Vector3(0.17, 0.3, 0.32), por)
	_b(Vector3(-0.36, 0.3, -0.3), Vector3(0.36, 0.42, 0.62), por2)
	# vaso e sedile a gradini: visti dall'alto fanno l'ovale tipico, non un tavolo
	for st_: Array in [[0.5, -0.36, 0.42], [0.42, 0.42, 0.64], [0.28, 0.64, 0.8]]:
		var hw: float = st_[0]
		_b(Vector3(-hw, 0.42, st_[1]), Vector3(hw, 0.56, st_[2]), por)
		_b(Vector3(-hw - 0.06, 0.56, float(st_[1]) - 0.04), Vector3(hw + 0.06, 0.6, float(st_[2]) + 0.06), Color(0.25, 0.22, 0.2))
		_b(Vector3(-hw - 0.05, 0.6, float(st_[1]) - 0.03), Vector3(hw + 0.05, 0.66, float(st_[2]) + 0.05), seat)
	# l'acqua azzurra che si vede ai lati delle cosce
	_b(Vector3(-0.42, 0.66, 0.16), Vector3(0.42, 0.675, 0.6), Color(0.3, 0.62, 0.9))
	# coperchio alzato: ovale, bianco, più largo del re, con le cerniere
	_b(Vector3(-0.6, 0.68, -0.48), Vector3(0.6, 1.4, -0.4), seat)
	_b(Vector3(-0.44, 1.4, -0.48), Vector3(0.44, 1.62, -0.4), seat)
	_b(Vector3(-0.3, 0.64, -0.5), Vector3(0.3, 0.7, -0.38), Color(0.7, 0.7, 0.68))
	# cassetta alta sopra la corona, col tubo, la catenella lunga e il pomello da tirare
	_b(Vector3(-0.8, 2.1, -0.82), Vector3(0.8, 2.75, -0.52), por)
	_b(Vector3(-0.84, 2.75, -0.84), Vector3(0.84, 2.81, -0.5), por2)
	_b(Vector3(-0.07, 0.42, -0.74), Vector3(0.07, 2.1, -0.62), Color(0.62, 0.62, 0.6))
	_b(Vector3(0.61, 1.0, -0.56), Vector3(0.63, 2.1, -0.54), Color(0.75, 0.62, 0.3))
	_b(Vector3(0.56, 0.86, -0.6), Vector3(0.68, 1.02, -0.5), WOODC)
	# rotolo di carta su un paletto, con un pezzo che pende
	_b(Vector3(0.72, 0.0, -0.05), Vector3(0.78, 0.8, 0.01), WOODC)
	_b(Vector3(0.66, 0.68, -0.14), Vector3(0.86, 0.86, 0.1), WHITE)
	_b(Vector3(0.7, 0.3, 0.08), Vector3(0.82, 0.72, 0.1), WHITE)
	# cosce nude (i calzoni sono calati), calzoni ammucchiati alle caviglie, pantofole
	_b(Vector3(-0.27, 0.62, 0.0), Vector3(-0.03, 0.82, 0.78), SKIN)
	_b(Vector3(0.03, 0.62, 0.0), Vector3(0.27, 0.82, 0.78), SKIN)
	_b(Vector3(-0.26, 0.12, 0.6), Vector3(-0.04, 0.66, 0.8), SKIN)
	_b(Vector3(0.04, 0.12, 0.6), Vector3(0.26, 0.66, 0.8), SKIN)
	_b(Vector3(-0.34, 0.0, 0.52), Vector3(0.34, 0.26, 0.9), robe * 0.7, 0, 0, team)
	_b(Vector3(-0.3, 0.0, 0.82), Vector3(-0.02, 0.12, 1.08), Color(0.6, 0.1, 0.12))
	_b(Vector3(0.02, 0.0, 0.82), Vector3(0.3, 0.12, 1.08), Color(0.6, 0.1, 0.12))
	# veste reale con bordo d'ermellino
	_b(Vector3(-0.34, 0.62, -0.3), Vector3(0.34, 1.35, 0.14), robe, 0, 0, team)
	_b(Vector3(-0.36, 1.2, -0.24), Vector3(0.36, 1.36, 0.22), WHITE)
	_b(Vector3(-0.05, 1.22, 0.2), Vector3(0.05, 1.3, 0.23), Color(0.1, 0.1, 0.1))
	# testa, barba, nasone e corona
	_b(Vector3(-0.2, 1.36, -0.18), Vector3(0.2, 1.74, 0.18), SKIN)
	_b(Vector3(-0.21, 1.3, 0.1), Vector3(0.21, 1.52, 0.24), Color(0.92, 0.92, 0.9))
	_b(Vector3(-0.05, 1.5, 0.18), Vector3(0.05, 1.6, 0.27), Color(0.9, 0.55, 0.5))
	_b(Vector3(-0.22, 1.74, -0.2), Vector3(0.22, 1.86, 0.2), GOLD)
	for k: Vector2 in [Vector2(-0.18, -0.16), Vector2(0.14, -0.16), Vector2(-0.18, 0.12), Vector2(0.14, 0.12)]:
		_b(Vector3(k.x, 1.86, k.y), Vector3(k.x + 0.06, 2.0, k.y + 0.06), GOLD)
	# braccio sinistro appoggiato al ginocchio, braccio destro alzato con la bandierina bianca:
	# quando lo attaccano la sventola (parte 4, animata dallo shader), e intanto si arrende
	_b(Vector3(-0.46, 0.85, -0.1), Vector3(-0.34, 1.3, 0.3), robe, 0, 0, team)
	_b(Vector3(0.34, 1.05, -0.08), Vector3(0.48, 1.32, 0.1), robe, 8, 1.15, team)
	_b(Vector3(0.36, 1.32, -0.06), Vector3(0.48, 1.62, 0.08), robe, 8, 1.15, team)
	_b(Vector3(0.37, 1.6, -0.06), Vector3(0.49, 1.72, 0.08), SKIN, 8, 1.15)
	_b(Vector3(0.4, 1.55, -0.02), Vector3(0.45, 2.55, 0.03), WOODC, 8, 1.15)
	_b(Vector3(0.45, 2.12, -0.01), Vector3(0.95, 2.5, 0.02), WHITE, 9, 1.15)
	_b(Vector3(0.95, 2.18, -0.01), Vector3(1.05, 2.42, 0.02), WHITE * 0.92, 9, 1.15)
	return st.commit()


## Frate: saio marrone, tonsura, cordone del colore della casata.
func frate() -> ArrayMesh:
	_begin(1.1)
	var saio := Color(0.42, 0.28, 0.16)
	_b(Vector3(-0.22, 0.0, -0.14), Vector3(-0.02, 0.12, 0.2), LEATHER, 1, 0.7)
	_b(Vector3(0.02, 0.0, -0.14), Vector3(0.22, 0.12, 0.2), LEATHER, 2, 0.7)
	_b(Vector3(-0.32, 0.08, -0.2), Vector3(0.32, 1.38, 0.2), saio)
	_b(Vector3(-0.34, 0.8, -0.22), Vector3(0.34, 0.9, 0.22), WHITE, 0, 0, true)
	_b(Vector3(0.2, 0.3, 0.2), Vector3(0.26, 0.8, 0.24), WHITE, 0, 0, true)
	_b(Vector3(-0.3, 1.25, -0.28), Vector3(0.3, 1.45, 0.05), saio * 0.85)
	_b(Vector3(-0.18, 1.4, -0.17), Vector3(0.18, 1.74, 0.17), SKIN)
	_b(Vector3(-0.19, 1.62, -0.18), Vector3(0.19, 1.7, 0.18), Color(0.3, 0.2, 0.12))
	_b(Vector3(-0.05, 1.5, 0.17), Vector3(0.05, 1.58, 0.22), Color(0.9, 0.55, 0.5))
	# mani giunte in preghiera
	_b(Vector3(-0.4, 0.95, -0.08), Vector3(-0.3, 1.3, 0.1), saio, 3, 1.3)
	_b(Vector3(0.3, 0.95, -0.08), Vector3(0.4, 1.3, 0.1), saio, 4, 1.3)
	_b(Vector3(-0.1, 1.05, 0.2), Vector3(0.1, 1.25, 0.3), SKIN)
	return st.commit()


## Nonna: vestito nero, scialle della casata, crocchia bianca, occhiali, mattarello.
## Busto del re a partire da quota y: veste, ermellino, testa, barba, naso e corona.
func _busto(robe: Color, x: float, y: float) -> void:
	_b(Vector3(x - 0.34, y, -0.2), Vector3(x + 0.34, y + 0.72, 0.2), robe)
	_b(Vector3(x - 0.36, y + 0.58, -0.24), Vector3(x + 0.36, y + 0.74, 0.24), WHITE)
	_b(Vector3(x - 0.2, y + 0.74, -0.18), Vector3(x + 0.2, y + 1.12, 0.18), SKIN)
	_b(Vector3(x - 0.21, y + 0.68, 0.1), Vector3(x + 0.21, y + 0.9, 0.24), Color(0.92, 0.92, 0.9))
	_b(Vector3(x - 0.05, y + 0.88, 0.18), Vector3(x + 0.05, y + 0.98, 0.27), Color(0.9, 0.55, 0.5))
	_b(Vector3(x - 0.22, y + 1.12, -0.2), Vector3(x + 0.22, y + 1.24, 0.2), GOLD)
	for k: Vector2 in [Vector2(-0.18, -0.16), Vector2(0.14, -0.16), Vector2(-0.18, 0.12), Vector2(0.14, 0.12)]:
		_b(Vector3(x + k.x, y + 1.24, k.y), Vector3(x + k.x + 0.05, y + 1.38, k.y + 0.05), GOLD)


## Le uscite di scena del re, oltre al gabinetto: 1 botte, 2 trono a molla, 3 regina, 4 tinozza.
func re_scena(robe: Color, v: int) -> ArrayMesh:
	_begin(1.2)
	var iron := Color(0.36, 0.34, 0.33)
	var dark := Color(0.3, 0.19, 0.1)
	match v:
		1:
			for l: Array in [[0.0, 0.3, 0.5], [0.3, 0.65, 0.62], [0.65, 1.05, 0.68], [1.05, 1.35, 0.6], [1.35, 1.6, 0.5]]:
				_b(Vector3(-float(l[2]), l[0], -float(l[2])), Vector3(l[2], l[1], l[2]), WOODC)
			for y: float in [0.28, 1.3]:
				_b(Vector3(-0.64, y, -0.64), Vector3(0.64, y + 0.08, 0.64), iron)
			_b(Vector3(-0.42, 1.6, -0.42), Vector3(0.42, 1.63, 0.42), dark)
			_busto(robe, 0.0, 1.05)
			_b(Vector3(-0.52, 1.56, 0.34), Vector3(-0.32, 1.7, 0.56), SKIN)
			_b(Vector3(0.32, 1.56, 0.34), Vector3(0.52, 1.7, 0.56), SKIN)
		2:
			_b(Vector3(-0.7, 0.0, -0.7), Vector3(0.7, 0.14, 0.7), WOODC)
			for k in 7:
				var w := 0.5 if k % 2 == 0 else 0.36
				_b(Vector3(-w, 0.14 + k * 0.16, -w), Vector3(w, 0.26 + k * 0.16, w), Color(0.82, 0.68, 0.3))
			_b(Vector3(-0.62, 1.26, -0.56), Vector3(0.62, 1.42, 0.66), Color(0.62, 0.08, 0.1))
			_b(Vector3(-0.62, 1.42, -0.62), Vector3(0.62, 3.0, -0.44), Color(0.62, 0.08, 0.1))
			_b(Vector3(-0.7, 3.0, -0.66), Vector3(0.7, 3.14, -0.4), GOLD)
			_b(Vector3(-0.27, 1.42, 0.0), Vector3(-0.03, 1.64, 0.82), robe * 0.8)
			_b(Vector3(0.03, 1.42, 0.0), Vector3(0.27, 1.64, 0.82), robe * 0.8)
			_busto(robe, 0.0, 1.42)
		3:
			_b(Vector3(-0.85, 0.0, -0.14), Vector3(-0.62, 0.72, 0.14), robe * 0.7)
			_b(Vector3(-0.48, 0.0, -0.14), Vector3(-0.25, 0.72, 0.14), robe * 0.7)
			_busto(robe, -0.55, 0.72)
			var dress := Color(0.46, 0.1, 0.42)
			_b(Vector3(0.28, 0.0, -0.48), Vector3(1.28, 0.7, 0.48), dress)
			_b(Vector3(0.42, 0.7, -0.32), Vector3(1.14, 1.5, 0.32), dress)
			_b(Vector3(0.44, 1.42, -0.34), Vector3(1.12, 1.56, 0.34), GOLD)
			_b(Vector3(0.58, 1.56, -0.2), Vector3(0.98, 2.0, 0.2), SKIN)
			_b(Vector3(0.54, 1.82, -0.26), Vector3(1.02, 2.06, 0.1), Color(0.34, 0.2, 0.1))
			_b(Vector3(0.54, 2.06, -0.24), Vector3(1.02, 2.16, 0.24), GOLD)
			_b(Vector3(-0.3, 1.66, -0.08), Vector3(0.5, 1.82, 0.08), dress)
			_b(Vector3(-0.42, 1.62, -0.12), Vector3(-0.26, 1.86, 0.12), SKIN)
		4:
			_b(Vector3(-0.95, 0.0, -0.75), Vector3(0.95, 0.42, 0.75), WOODC)
			_b(Vector3(-1.0, 0.42, -0.8), Vector3(1.0, 0.58, 0.8), dark)
			for x: float in [-0.7, 0.62]:
				_b(Vector3(x, 0.02, -0.78), Vector3(x + 0.08, 0.5, 0.78), iron)
			_b(Vector3(-0.86, 0.5, -0.66), Vector3(0.86, 0.59, 0.66), Color(0.3, 0.62, 0.9))
			_busto(robe, 0.0, 0.45)
			_b(Vector3(-1.5, 0.92, 0.28), Vector3(1.5, 1.02, 0.38), WOODC)
			_b(Vector3(1.32, 0.72, 0.24), Vector3(1.72, 1.2, 0.42), WOODC)
	return st.commit()


func nonna() -> ArrayMesh:
	_begin(1.0)
	var nero := Color(0.12, 0.11, 0.12)
	_b(Vector3(-0.2, 0.0, -0.12), Vector3(-0.03, 0.4, 0.12), Color(0.85, 0.8, 0.75), 1, 0.4)
	_b(Vector3(0.03, 0.0, -0.12), Vector3(0.2, 0.4, 0.12), Color(0.85, 0.8, 0.75), 2, 0.4)
	_b(Vector3(-0.36, 0.3, -0.24), Vector3(0.36, 1.2, 0.24), nero)
	_b(Vector3(-0.26, 0.4, 0.24), Vector3(0.26, 1.05, 0.27), WHITE)
	_b(Vector3(-0.38, 1.0, -0.26), Vector3(0.38, 1.25, 0.26), WHITE, 0, 0, true)
	_b(Vector3(-0.18, 1.22, -0.16), Vector3(0.18, 1.56, 0.17), SKIN)
	_b(Vector3(-0.2, 1.45, -0.2), Vector3(0.2, 1.62, 0.1), Color(0.93, 0.93, 0.93))
	_b(Vector3(-0.1, 1.55, -0.28), Vector3(0.1, 1.72, -0.12), Color(0.93, 0.93, 0.93))
	_b(Vector3(-0.15, 1.38, 0.17), Vector3(0.15, 1.42, 0.19), DARK)
	_b(Vector3(-0.15, 1.34, 0.17), Vector3(-0.03, 1.44, 0.19), DARK)
	_b(Vector3(0.03, 1.34, 0.17), Vector3(0.15, 1.44, 0.19), DARK)
	_b(Vector3(-0.48, 0.75, -0.08), Vector3(-0.36, 1.2, 0.08), nero, 3, 1.15)
	_b(Vector3(0.36, 0.75, -0.08), Vector3(0.48, 1.2, 0.08), nero, 4, 1.15)
	# mattarello
	_b(Vector3(0.38, 0.85, 0.05), Vector3(0.46, 0.95, 0.75), WOODC, 4, 1.15)
	_b(Vector3(0.39, 0.86, 0.75), Vector3(0.45, 0.94, 0.9), Color(0.35, 0.22, 0.1), 4, 1.15)
	return st.commit()


## Menestrello: calzamaglia bicolore, cappello a punte della casata, liuto.
func menestrello() -> ArrayMesh:
	_begin(1.1)
	var giallo := Color(0.95, 0.8, 0.25)
	_b(Vector3(-0.22, 0.0, -0.12), Vector3(-0.03, 0.72, 0.12), WHITE, 1, 0.72, true)
	_b(Vector3(0.03, 0.0, -0.12), Vector3(0.22, 0.72, 0.12), giallo, 2, 0.72)
	_b(Vector3(-0.27, 0.72, -0.15), Vector3(0.27, 1.32, 0.15), giallo)
	_b(Vector3(-0.27, 0.72, 0.15), Vector3(0.0, 1.32, 0.16), WHITE, 0, 0, true)
	_b(Vector3(-0.16, 1.34, -0.16), Vector3(0.16, 1.66, 0.16), SKIN)
	_b(Vector3(-0.08, 1.48, 0.16), Vector3(0.08, 1.56, 0.2), Color(0.8, 0.2, 0.2))
	_b(Vector3(-0.2, 1.64, -0.18), Vector3(0.2, 1.76, 0.18), WHITE, 0, 0, true)
	_b(Vector3(-0.42, 1.7, -0.06), Vector3(-0.1, 1.84, 0.06), WHITE, 0, 0, true)
	_b(Vector3(0.1, 1.7, -0.06), Vector3(0.42, 1.84, 0.06), giallo)
	_b(Vector3(-0.48, 1.62, -0.05), Vector3(-0.38, 1.72, 0.05), GOLD)
	_b(Vector3(0.38, 1.62, -0.05), Vector3(0.48, 1.72, 0.05), GOLD)
	_b(Vector3(-0.4, 0.8, -0.08), Vector3(-0.27, 1.3, 0.08), giallo, 3, 1.3)
	_b(Vector3(0.27, 0.8, -0.08), Vector3(0.4, 1.3, 0.08), WHITE, 4, 1.3, true)
	# liuto sul petto
	_b(Vector3(-0.2, 0.85, 0.16), Vector3(0.12, 1.1, 0.26), WOODC, 4, 1.3)
	_b(Vector3(0.1, 0.98, 0.18), Vector3(0.42, 1.04, 0.24), Color(0.3, 0.2, 0.1), 4, 1.3)
	return st.commit()


## Personaggi delle botteghe (solo da vedere): 0 casaro, 1 mandriano, 2 oste, 3 astrologo, 4 suora.
func worker(kind: int) -> ArrayMesh:
	_begin(1.1)
	match kind:
		0:  # casaro: camice e berretto bianchi, forma di Parmigiano in braccio
			_legs(Color(0.3, 0.3, 0.35))
			_b(Vector3(-0.3, 0.72, -0.17), Vector3(0.3, 1.36, 0.17), WHITE)
			_b(Vector3(-0.17, 1.38, -0.17), Vector3(0.17, 1.72, 0.17), SKIN)
			_b(Vector3(-0.19, 1.7, -0.19), Vector3(0.19, 1.95, 0.19), WHITE)
			_b(Vector3(-0.12, 1.52, 0.17), Vector3(0.12, 1.56, 0.2), Color(0.25, 0.15, 0.1))
			_b(Vector3(-0.44, 0.85, -0.1), Vector3(-0.3, 1.3, 0.1), WHITE, 3, 1.3)
			_b(Vector3(0.3, 0.85, -0.1), Vector3(0.44, 1.3, 0.1), WHITE, 4, 1.3)
			_b(Vector3(-0.35, 0.75, 0.18), Vector3(0.35, 1.25, 0.42), Color(0.98, 0.8, 0.3), 4, 1.3)
		1:  # mandriano: gilet, casco da cantiere giallo, bastone
			_legs(Color(0.25, 0.3, 0.5))
			_b(Vector3(-0.3, 0.72, -0.17), Vector3(0.3, 1.36, 0.17), Color(0.85, 0.8, 0.7))
			_b(Vector3(-0.31, 0.74, -0.18), Vector3(0.31, 1.3, 0.0), LEATHER)
			_b(Vector3(-0.17, 1.38, -0.17), Vector3(0.17, 1.72, 0.17), SKIN)
			_b(Vector3(-0.22, 1.68, -0.22), Vector3(0.22, 1.86, 0.22), Color(1.0, 0.82, 0.1))
			_b(Vector3(-0.24, 1.68, 0.18), Vector3(0.24, 1.72, 0.3), Color(1.0, 0.82, 0.1))
			_b(Vector3(-0.44, 0.85, -0.1), Vector3(-0.3, 1.3, 0.1), Color(0.85, 0.8, 0.7), 3, 1.3)
			_b(Vector3(0.3, 0.85, -0.1), Vector3(0.44, 1.3, 0.1), Color(0.85, 0.8, 0.7), 4, 1.3)
			_b(Vector3(0.42, 0.0, 0.08), Vector3(0.48, 1.9, 0.14), WOODC, 4, 1.3)
		2:  # oste: pancione, grembiule, naso rosso, boccale
			_legs(Color(0.3, 0.22, 0.15))
			_b(Vector3(-0.38, 0.7, -0.24), Vector3(0.38, 1.36, 0.34), Color(0.75, 0.3, 0.25))
			_b(Vector3(-0.3, 0.72, 0.34), Vector3(0.3, 1.2, 0.37), WHITE)
			_b(Vector3(-0.17, 1.38, -0.15), Vector3(0.17, 1.72, 0.19), SKIN)
			_b(Vector3(-0.06, 1.5, 0.19), Vector3(0.06, 1.62, 0.27), Color(0.9, 0.2, 0.2))
			_b(Vector3(-0.18, 1.42, 0.17), Vector3(0.18, 1.48, 0.21), Color(0.2, 0.12, 0.08))
			_b(Vector3(-0.5, 0.85, -0.1), Vector3(-0.38, 1.3, 0.1), Color(0.75, 0.3, 0.25), 3, 1.3)
			_b(Vector3(0.38, 0.85, -0.1), Vector3(0.5, 1.3, 0.1), Color(0.75, 0.3, 0.25), 4, 1.3)
			_b(Vector3(0.38, 1.25, 0.05), Vector3(0.58, 1.55, 0.25), Color(0.7, 0.5, 0.25), 4, 1.3)
			_b(Vector3(0.38, 1.5, 0.05), Vector3(0.58, 1.58, 0.25), WHITE, 4, 1.3)
		3:  # astrologo: tunica blu con stelle, cappello a punta, barba
			var blu := Color(0.18, 0.22, 0.55)
			_b(Vector3(-0.3, 0.0, -0.2), Vector3(0.3, 1.36, 0.2), blu)
			for k: Vector3 in [Vector3(-0.15, 0.4, 0.2), Vector3(0.1, 0.8, 0.2), Vector3(-0.05, 1.15, 0.2)]:
				_b(k, k + Vector3(0.1, 0.1, 0.02), GOLD)
			_b(Vector3(-0.17, 1.38, -0.17), Vector3(0.17, 1.72, 0.17), SKIN)
			_b(Vector3(-0.18, 1.3, 0.12), Vector3(0.18, 1.52, 0.24), Color(0.92, 0.92, 0.9))
			_b(Vector3(-0.24, 1.7, -0.24), Vector3(0.24, 1.8, 0.24), blu)
			_b(Vector3(-0.15, 1.8, -0.15), Vector3(0.15, 2.05, 0.15), blu)
			_b(Vector3(-0.07, 2.05, -0.07), Vector3(0.07, 2.3, 0.07), blu)
			_b(Vector3(-0.04, 2.3, -0.04), Vector3(0.04, 2.38, 0.04), GOLD)
			_b(Vector3(-0.44, 0.85, -0.1), Vector3(-0.3, 1.3, 0.1), blu, 3, 1.3)
			_b(Vector3(0.3, 0.85, -0.1), Vector3(0.44, 1.3, 0.1), blu, 4, 1.3)
			_b(Vector3(0.35, 1.2, 0.0), Vector3(0.45, 1.3, 0.6), GOLD, 4, 1.3)
		4:  # suora: abito nero e bianco, mestolo
			var nero := Color(0.1, 0.1, 0.12)
			_b(Vector3(-0.3, 0.0, -0.2), Vector3(0.3, 1.36, 0.2), nero)
			_b(Vector3(-0.22, 0.9, 0.2), Vector3(0.22, 1.3, 0.22), WHITE)
			_b(Vector3(-0.17, 1.38, -0.15), Vector3(0.17, 1.68, 0.17), SKIN)
			_b(Vector3(-0.2, 1.36, -0.22), Vector3(0.2, 1.8, -0.1), nero)
			_b(Vector3(-0.2, 1.66, -0.2), Vector3(0.2, 1.8, 0.18), nero)
			_b(Vector3(-0.19, 1.62, 0.16), Vector3(0.19, 1.68, 0.19), WHITE)
			_b(Vector3(-0.44, 0.85, -0.1), Vector3(-0.3, 1.3, 0.1), nero, 3, 1.3)
			_b(Vector3(0.3, 0.85, -0.1), Vector3(0.44, 1.3, 0.1), nero, 4, 1.3)
			_b(Vector3(0.36, 1.0, 0.05), Vector3(0.42, 1.06, 0.7), STEEL, 4, 1.3)
			_b(Vector3(0.3, 0.96, 0.7), Vector3(0.48, 1.12, 0.88), STEEL, 4, 1.3)
	return st.commit()
