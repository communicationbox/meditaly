extends SceneTree
## La disposizione dei castelli: tutti sulla terraferma, abbastanza distanti, con la porta che dà su terra.
##   godot --headless --path . -s tests/castle_layout.gd

var fails := 0

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var g := Game.new()
	g.name = "Game"
	main.add_child(g)
	g.start_solo(1, "Prova", PackedStringArray())
	var w: VoxelWorld = g.world
	check("tutti i castelli di Defs ci sono (%d)" % g.castles.size(), g.castles.size() == Defs.CASTLES.size())
	for c: Dictionary in g.castles:
		var ce: Vector3 = c.center
		check("%s sopra il mare (base %d)" % [c.name, c.base], int(c.base) >= Defs.SEA + 2)
		var go: Vector3 = c.gate_out
		var gy := w.top_y(int(go.x), int(go.z))
		check("%s: fuori dalla porta c'è terra (%d)" % [c.name, gy], gy >= Defs.SEA)
		var nd := 1e9
		var nn := ""
		for o: Dictionary in g.castles:
			if o.id != c.id:
				var d := Vector2(ce.x - o.center.x, ce.z - o.center.z).length()
				if d < nd:
					nd = d
					nn = o.name
		check("%s lontano dagli altri (%s a %d)" % [c.name, nn, int(nd)], nd >= 120.0)
	for c: Dictionary in g.castles:
		if Defs.CASTLES[c.id].has("lord"):
			check("%s: signoria %s" % [c.name, c.lord_of], c.lord != "" and c.start_house == Defs.NEUTRAL)
	print("FALLITI: %d" % fails)
	quit(1 if fails > 0 else 0)
