extends SceneTree
## Diagnosi: quanti attacchi lanciano le IA, con quanti soldati, e come finiscono.
##   godot --headless --path . -s tests/ai_diag.gd -- [minuti] [aggressività] [seed]


class DiagSim:
	extends Sim
	var orders := 0
	var size_sum := 0
	var to_neutral := 0
	var stage_done := 0
	var to_house := 0
	var captures: Array = []
	var king_hits := {}
	func cmd_order(team: int, ids: PackedInt32Array, point: Vector3, on_struct: bool) -> void:
		if houses[team].ai and not on_struct:
			var g := castle_at(point)
			if g >= 0 and castles[g].owner != team:
				orders += 1
				size_sum += ids.size()
				if castles[g].owner == Defs.NEUTRAL:
					to_neutral += 1
				else:
					to_house += 1
		super(team, ids, point, on_struct)
	func _ai_stage_tick(t: int, st: Dictionary) -> void:
		var had := ai_stage.has(t)
		super(t, st)
		if had and not ai_stage.has(t):
			stage_done += 1
	func _hurt_king(c: Dictionary, dmg: float, team: int) -> void:
		if int(c.owner) != team and not at_peace(int(c.owner), team):
			king_hits[c.name] = int(king_hits.get(c.name, 0)) + 1
		super(c, dmg, team)
	func _capture(c: Dictionary, team: int) -> void:
		captures.append("%d:%s>%d" % [int(time), c.name, team])
		super(c, team)


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
	var mins := a[0].to_float() if a.size() > 0 else 15.0
	var aggr := a[1].to_float() if a.size() > 1 else 1.0
	var sd := a[2].to_int() if a.size() > 2 else 1
	var world := VoxelWorld.new()
	var base := WorldGen.generate(world, Game.SEED)
	var g := HeadlessGame.new()
	g.world = world
	var sim := DiagSim.new()
	g.sim = sim
	sim.events_enabled = false
	sim.seed_override = sd
	sim.ai_aggression = aggr
	sim.stats = {"recruited": [0, 0, 0, 0, 0, 0, 0, 0, 0], "spent": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"powers": [0, 0, 0, 0, 0], "damage": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"kills": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "deaths": [0, 0, 0, 0, 0, 0, 0, 0, 0],
		"captures": 0, "first_capture": -1.0, "repaired": 0}
	sim.setup(g, base.duplicate(true))
	var step := 1.0 / Defs.SIM_HZ
	var mark := 120.0
	while sim.time < mins * 60.0 and sim.winner < 0:
		sim.tick(step)
		var i := g.pending.size() - 1
		while i >= 0:
			if float(g.pending[i][0]) <= sim.time:
				var e: Array = g.pending[i]
				g.pending.remove_at(i)
				sim.fragment_landed(e[1], e[2])
			i -= 1
		if sim.time >= mark:
			mark += 120.0
			var per := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			for u in sim.ulist:
				per[u.team] += 1
			var gold := []
			for h in Defs.HOUSE_COUNT:
				gold.append(int(sim.houses[h].gold))
			var hist := {}
			for u in sim.ulist:
				if u.team == Defs.NEUTRAL or u.hp <= 0.0 or u.garrison:
					continue
				var near := -1
				for c: Dictionary in sim.castles:
					if int(c.owner) != u.team and u.pos.distance_to(c.center) < Sim.R + 22.0:
						near = c.id
				var k := "lontano"
				if u.inside_enemy >= 0:
					k = "cortile_tgt" if u.tgt != null else "cortile_libero"
				elif near >= 0:
					k = "mura_" + ("ordine" if u.has_order else "libero") + ("_tgt" if u.tgt != null else "") + ("_vox" if u.vox_t else "") + ("_att" if u.attacking else "") + ("_ass" if (u.type == Defs.CATAPULTA or u.type == Defs.BOMBARDA) else "")
				hist[k] = int(hist.get(k, 0)) + 1
			print("  stati ", hist)
			var integ := []
			for c: Dictionary in sim.castles:
				integ.append("%s %.2f" % [String(c.name).left(3), float(c.integrity)])
			print("  mura ", integ)
			print("  uccisioni per fonte ", sim.stats.kills, " morti per tipo ", sim.stats.deaths)
			print("t=%d unita=%s oro=%s ordini=%d media=%.0f liberi=%d casate=%d raduni=%d" % [int(sim.time), str(per), str(gold), sim.orders, float(sim.size_sum) / maxf(sim.orders, 1), sim.to_neutral, sim.to_house, sim.stage_done])
			var under := 0
			for c: Dictionary in sim.castles:
				if bool(c.under_attack):
					under += 1
			print("  sotto_attacco ", under, " raduni_attivi ", sim.ai_stage.size())
	print("conquiste ", sim.captures)
	print("colpi al re ", sim.king_hits)
	print("vincitore ", sim.winner, " t=", int(sim.time))
	print("FALLITI: 0")
	quit(0)
