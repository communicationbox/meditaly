extends SceneTree
## Pressione sui castelli: partita tra sole IA senza grafica. Per ogni castello conta i secondi
## sotto attacco, i colpi al re e le volte che cambia padrone. Serve a scovare i castelli troppo
## tranquilli (per esempio uno isolato su un'isola).
##   godot --headless --path . -s tests/pressure.gd -- [--seeds 3] [--seed 1] [--min 30]

const HG := preload("res://tests/balance.gd")


func _init() -> void:
	_run.call_deferred()


func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 else def


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var minutes := _opt(a, "--min", "30").to_float()
	var seeds := _opt(a, "--seeds", "3").to_int()
	var seed0 := _opt(a, "--seed", "1").to_int()
	var world0 := VoxelWorld.new()
	var castles0 := WorldGen.generate(world0, Game.SEED)
	var tot_att := {}
	var tot_cap := {}
	var tot_near := {}
	for s in seeds:
		var world := VoxelWorld.new()
		var castles := WorldGen.generate(world, Game.SEED)
		var g = HG.HeadlessGame.new()
		g.world = world
		var sim := Sim.new()
		g.sim = sim
		sim.events_enabled = false
		sim.seed_override = seed0 + s
		sim.setup(g, castles)
		var step := 1.0 / Defs.SIM_HZ
		var next_s := 1.0
		var owners: Array = []
		for c: Dictionary in sim.castles:
			owners.append(c.owner)
		while sim.winner < 0 and sim.time < minutes * 60.0:
			sim.tick(step)
			var i: int = g.pending.size() - 1
			while i >= 0:
				if float(g.pending[i][0]) <= sim.time:
					var e: Array = g.pending[i]
					g.pending.remove_at(i)
					sim.fragment_landed(e[1], e[2])
				i -= 1
			if sim.time >= next_s:
				next_s += 1.0
				for c: Dictionary in sim.castles:
					var n := 0
					for u: Sim.U in sim.ulist:
						if u.team != int(c.owner) and u.team != Defs.NEUTRAL and u.pos.distance_to(c.center) < Sim.R + 30.0:
							n += 1
					if n > 0:
						tot_near[c.name] = int(tot_near.get(c.name, 0)) + 1
					if c.under_attack:
						tot_att[c.name] = int(tot_att.get(c.name, 0)) + 1
					if int(c.owner) != int(owners[c.id]):
						tot_cap[c.name] = int(tot_cap.get(c.name, 0)) + 1
						owners[c.id] = c.owner
		var fin: Array = []
		for c: Dictionary in sim.castles:
			fin.append("%s=%s" % [c.name, Defs.HOUSES[c.owner].name])
		print("seme %d: %s" % [seed0 + s, ", ".join(fin)])
	print("castello      sotto attacco   nemici vicini   cambi di padrone   (secondi su %d partite da %d min)" % [seeds, int(minutes)])
	for c: Dictionary in castles0:
		print("%-12s %10d %15d %12d" % [c.name, int(tot_att.get(c.name, 0)), int(tot_near.get(c.name, 0)), int(tot_cap.get(c.name, 0))])
	quit(0)
