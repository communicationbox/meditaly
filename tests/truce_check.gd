extends SceneTree
## Tregua: nei primi minuti le IA non conquistano nulla e nessuna casata ne tocca un'altra.
##   godot --headless --path . -s tests/truce_check.gd -- [partite] [seed]


class TruceSim:
	extends Sim
	var log_capture: Array = []
	var splash_hits := 0
	var splash_ex := ""
	func _capture(c: Dictionary, team: int) -> void:
		log_capture.append([int(time), int(c.owner), team, String(c.name)])
		super(c, team)
	func _splash(p: Vector3, radius: float, dmg: float, team: int, src := SRC_POWER) -> void:
		for u in ulist:
			if u.team != team and u.hp > 0.0 and at_peace(team, u.team) and u.pos.distance_to(p) < radius:
				splash_hits += 1
				splash_ex = "t=%d casata %d colpisce casata %d" % [int(time), team, u.team]
		super(p, radius, dmg, team, src)


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


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var games := a[0].to_int() if a.size() > 0 else 4
	var seed0 := a[1].to_int() if a.size() > 1 else 500
	var world := VoxelWorld.new()
	var base_castles := WorldGen.generate(world, Game.SEED)
	var base_vox := world.vox.duplicate()
	var base_top := world.col_top.duplicate()
	var base_sol := world.col_sol.duplicate()
	var bad := 0
	for n in games:
		world.vox = base_vox.duplicate()
		world.col_top = base_top.duplicate()
		world.col_sol = base_sol.duplicate()
		world._dirty.clear()
		var g := HeadlessGame.new()
		g.world = world
		var sim := TruceSim.new()
		g.sim = sim
		sim.events_enabled = false
		sim.seed_override = seed0 + n
		sim.setup(g, base_castles.duplicate(true))
		sim.houses[0].ai = false
		var step := 1.0 / Defs.SIM_HZ
		var wall0: Dictionary = {}
		for c: Dictionary in sim.castles:
			wall0[c.id] = float(c.integrity)
		while sim.time < Sim.TRUCE_TIME - 1.0:
			sim.tick(step)
			var i := g.pending.size() - 1
			while i >= 0:
				if float(g.pending[i][0]) <= sim.time:
					var e: Array = g.pending[i]
					g.pending.remove_at(i)
					sim.fragment_landed(e[1], e[2])
				i -= 1
		var fra := 0
		for k: Array in sim.log_capture:
			if int(k[1]) != Defs.NEUTRAL:
				fra += 1
		var dented: Array = []
		for c: Dictionary in sim.castles:
			if int(c.start_house) != Defs.NEUTRAL and int(c.owner) == int(c.start_house) and float(c.integrity) < float(wall0[c.id]) - 0.005:
				dented.append("%s %.2f" % [c.name, float(c.integrity)])
		print("seed %d conquiste=%s fra_casate=%d colpi_ad_area_fra_casate=%d %s mura_casate_rovinate=%s" % [seed0 + n, str(sim.log_capture), fra, sim.splash_hits, sim.splash_ex, str(dented)])
		if not sim.log_capture.is_empty() or sim.splash_hits > 0 or not dented.is_empty():
			bad += 1
		sim.free()
		g.free()
	print("FALLITI: %d" % bad)
	quit(1 if bad > 0 else 0)
