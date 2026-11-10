extends SceneTree
## Una casata fa solo cavalieri, le altre giocano da IA: deve restare una strategia tra le tante,
## non quella che vince sempre. A ogni partita il cavaliere tocca a una casata diversa.
##   godot --headless --path . -s tests/knight_rush.gd -- [--games 8] [--min 30] [--seed 1] [--type cavaliere|fante] [--blind] [--house 0]
## --blind: le altre IA non guardano cosa le attacca (come prima che sapessero rispondere).

const HG := preload("res://tests/balance.gd")


class RushSim:
	extends Sim
	var rusher := 0
	var rush_type := Defs.CAVALIERE
	var blind := false
	func _ai_pick(t: int) -> int:
		if t == rusher:
			return rush_type
		if blind:
			return Sim.ai_pick_unit(rng.randf(), rng.randf(), Vector2.ZERO)
		return super(t)


func _init() -> void:
	_run.call_deferred()


func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 else def


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var games := _opt(a, "--games", "8").to_int()
	var minutes := _opt(a, "--min", "30").to_float()
	var seed0 := _opt(a, "--seed", "1").to_int()
	var house0 := _opt(a, "--house", "0").to_int()
	var rush_type := Defs.FANTE if _opt(a, "--type", "cavaliere") == "fante" else Defs.CAVALIERE
	var world := VoxelWorld.new()
	var base_castles := WorldGen.generate(world, Game.SEED)
	var base_vox := world.vox.duplicate()
	var base_top := world.col_top.duplicate()
	var base_sol := world.col_sol.duplicate()
	var share := 0.0
	var firsts := 0
	var wiped := 0
	for n in games:
		world.vox = base_vox.duplicate()
		world.col_top = base_top.duplicate()
		world.col_sol = base_sol.duplicate()
		world._dirty.clear()
		var g := HG.HeadlessGame.new()
		g.world = world
		var sim := RushSim.new()
		sim.rusher = (house0 + n) % Defs.HOUSE_COUNT
		sim.rush_type = rush_type
		sim.blind = a.has("--blind")
		g.sim = sim
		sim.events_enabled = false
		sim.equal_houses = true  # il carattere delle casate non deve contare
		sim.seed_override = seed0 + n
		sim.setup(g, base_castles.duplicate(true))
		var step := 1.0 / Defs.SIM_HZ
		while sim.winner < 0 and sim.time < minutes * 60.0:
			sim.tick(step)
			var i := g.pending.size() - 1
			while i >= 0:
				if float(g.pending[i][0]) <= sim.time:
					var e: Array = g.pending[i]
					g.pending.remove_at(i)
					sim.fragment_landed(e[1], e[2])
				i -= 1
		var counts: Array = HG.new()._counts(sim)
		var mine: int = counts[sim.rusher]
		var best := 0
		for t in Defs.HOUSE_COUNT:
			if t != sim.rusher:
				best = maxi(best, int(counts[t]))
		var owned := 0
		for t in Defs.HOUSE_COUNT:
			owned += int(counts[t])
		share += float(mine) / float(maxi(owned, 1))
		if mine > best or sim.winner == sim.rusher:
			firsts += 1
		if mine == 0:
			wiped += 1
		print("partita %d: casata %d (%s) chiude con %d castelli, la migliore delle altre %d, minuti %.0f" % [n, sim.rusher, Defs.HOUSES[sim.rusher].name, mine, best, sim.time / 60.0])
		sim.free()
		g.free()
	print("RIASSUNTO %s%s: quota media di castelli %.0f%% (pari = %.0f%%), prima in %d/%d, eliminata in %d/%d" % [
		Defs.UNITS[rush_type].name, " (IA cieche)" if a.has("--blind") else "", 100.0 * share / games, 100.0 / Defs.HOUSE_COUNT, firsts, games, wiped, games])
	quit(0)
