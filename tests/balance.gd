extends SceneTree
## Simulatore di bilanciamento: partite complete tra sole IA, senza grafica né rete.
## I crolli non usano la fisica: ogni pezzo arriva a terra nel tempo di caduta calcolato.
##   godot --headless --path . -s tests/balance.gd -- --games 10 --seed 1000 --out file.jsonl [--repair full] [--max-min 60]


class HeadlessGame:
	extends Node
	var world: VoxelWorld
	var sim: Sim
	var pending: Array = []
	func push_edits(edits: PackedInt64Array, _debris := true) -> void:
		world.apply_edits(edits)
	func fx_all(_k: String, _p: Vector3, _a: float) -> void:
		pass
	func msg_all(_t: String, _c: Color) -> void:
		pass
	func msg_house(_h: int, _t: String, _c: Color) -> void:
		pass
	func proj_all(_i: int, _k: int, _p: Vector3, _v: Vector3) -> void:
		pass
	func proj_end_all(_i: int) -> void:
		pass
	func frag_break_all(_i: int) -> void:
		pass
	func broadcast_state(_s: Array) -> void:
		pass
	func snapshot_all(_b: PackedByteArray, _w: PackedFloat32Array, _a: PackedFloat32Array) -> void:
		pass
	## Tempo di caduta dal punto più basso del pezzo fino al suolo sotto il baricentro.
	func frag_all(id: int, data: PackedInt64Array) -> void:
		var com := Vector3.ZERO
		var low := 999
		for e in data:
			var p := world.pos_of(e >> Defs.EDIT_SHIFT)
			com += Vector3(p)
			low = mini(low, p.y)
		com /= data.size()
		var ground := low
		while ground > 0 and world.get_v(int(com.x), ground, int(com.z)) == 0:
			ground -= 1
		var h := maxf(float(low - ground), 0.5)
		pending.append([sim.time + sqrt(2.0 * h / 15.7) + 0.55, id, Vector3(com.x, ground + 1.0, com.z)])


func _init() -> void:
	_run.call_deferred()


func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 else def


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var games := _opt(a, "--games", "1").to_int()
	var seed0 := _opt(a, "--seed", "1").to_int()
	var max_min := _opt(a, "--max-min", "60").to_float()
	var repair := _opt(a, "--repair", "slow")
	var f := FileAccess.open(_opt(a, "--out", "balance.jsonl"), FileAccess.WRITE)
	var world := VoxelWorld.new()
	var base_castles := WorldGen.generate(world, Game.SEED)
	var base_vox := world.vox.duplicate()
	var base_top := world.col_top.duplicate()
	var base_sol := world.col_sol.duplicate()
	for n in games:
		var t0 := Time.get_ticks_msec()
		world.vox = base_vox.duplicate()
		world.col_top = base_top.duplicate()
		world.col_sol = base_sol.duplicate()
		world._dirty.clear()
		var g := HeadlessGame.new()
		g.world = world
		var sim := Sim.new()
		g.sim = sim
		sim.events_enabled = false
		sim.seed_override = seed0 + n
		sim.repair_slow_when_attacked = repair == "slow"
		sim.stats = {"recruited": [0, 0, 0, 0, 0, 0, 0, 0, 0], "spent": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
			"powers": [0, 0, 0, 0, 0], "damage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
			"kills": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "deaths": [0, 0, 0, 0, 0, 0, 0, 0, 0],
			"captures": 0, "first_capture": -1.0, "repaired": 0}
		sim.setup(g, base_castles.duplicate(true))
		var step := 1.0 / Defs.SIM_HZ
		var timeline: Array = []
		var next_mark := 300.0
		var elim := {}
		while sim.winner < 0 and sim.time < max_min * 60.0:
			sim.tick(step)
			var i := g.pending.size() - 1
			while i >= 0:
				if float(g.pending[i][0]) <= sim.time:
					var e: Array = g.pending[i]
					g.pending.remove_at(i)
					sim.fragment_landed(e[1], e[2])
				i -= 1
			if sim.time >= next_mark:
				next_mark += 300.0
				timeline.append(_counts(sim))
			for t in Defs.HOUSE_COUNT:
				if not sim.houses[t].alive and not elim.has(t):
					elim[t] = int(sim.time)
		var row := {"seed": seed0 + n, "repair": repair, "winner": sim.winner, "time": int(sim.time), "final": _counts(sim),
			"timeline": timeline, "elim": elim, "stats": sim.stats, "units": sim.ulist.size(), "wall_ms": Time.get_ticks_msec() - t0}
		f.store_line(JSON.stringify(row))
		f.flush()
		sim.free()
		g.free()
	quit(0)


func _counts(sim: Sim) -> Array:
	var c: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for k: Dictionary in sim.castles:
		c[int(k.owner)] += 1
	return c
