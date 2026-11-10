extends SceneTree
## Scontri in campo aperto tra eserciti dello stesso costo: nessuna unità deve vincere contro tutto.
## Ogni scontro si gioca più volte, scambiando i lati, perché il caso e il terreno non decidano.
##   godot --headless --path . -s tests/matchups.gd

const BUDGET := 900.0
const GAP := 15.0  # metà della distanza tra i due fronti alla partenza
const ROUNDS := 2  # coppie di scontri a lati scambiati
var fails := 0

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()


## Esercito da una ricetta {tipo: quota}: le quote si spartiscono il budget.
func _army(sim: Sim, team: int, mix: Dictionary, at: Vector3, face: float) -> Array:
	var out: Array = []
	var k := 0
	for ty: int in mix:
		var n := int(round(BUDGET * float(mix[ty]) / float(Defs.UNITS[ty].cost)))
		for i in n:
			var p := at + Vector3((k % 8 - 4) * 1.6, 0, face * (k / 8) * 1.6)
			var u := sim.spawn_unit(ty, team, p)
			u.home = u.pos
			out.append(u)
			k += 1
	return out


func _value(army: Array) -> float:
	var v := 0.0
	for u: Sim.U in army:
		if u.hp > 0.0:
			v += float(Defs.UNITS[u.type].cost) * u.hp / float(Defs.UNITS[u.type].hp)
	return v


## Fiorini sopravvissuti di A meno quelli di B, in frazione del budget (da -1 a +1).
func _fight(sim: Sim, ep: Vector3, a: Dictionary, b: Dictionary, flip: bool) -> float:
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var s := -1.0 if flip else 1.0
	var pa := ep + Vector3(0, 0, -GAP * s)
	var pb := ep + Vector3(0, 0, GAP * s)
	var ua := _army(sim, 2, a, pa, -s)
	var ub := _army(sim, 3, b, pb, s)
	# avanzano l'uno contro l'altro, come li manderebbe un giocatore: chi tira da lontano ha tempo di farlo
	sim.cmd_order(2, PackedInt32Array(ua.map(func(u: Sim.U) -> int: return u.id)), pb, false)
	sim.cmd_order(3, PackedInt32Array(ub.map(func(u: Sim.U) -> int: return u.id)), pa, false)
	for k in int(Defs.SIM_HZ) * 90:
		sim.tick(1.0 / Defs.SIM_HZ)
		if _value(ua) <= 0.0 or _value(ub) <= 0.0:
			break
	return (_value(ua) - _value(ub)) / BUDGET


func _match(sim: Sim, ep: Vector3, a: Dictionary, b: Dictionary) -> float:
	var tot := 0.0
	for r in ROUNDS:
		tot += _fight(sim, ep, a, b, false) + _fight(sim, ep, a, b, true)
	return tot / (2.0 * ROUNDS)


## Un prato piatto, lontano dai castelli, dove nessuno dei due eserciti parte in salita o in acqua.
func _flat_field(g: Game) -> Vector3:
	var w: VoxelWorld = g.world
	var best := Vector3.ZERO
	var best_s := 1e9
	for z in range(40, Defs.WZ - 40, 8):
		for x in range(40, Defs.WX - 40, 8):
			var far := true
			for cs: Dictionary in g.castles:
				if (cs.center as Vector3).distance_to(Vector3(x, (cs.center as Vector3).y, z)) < 60.0:
					far = false
			if not far:
				continue
			var lo := 999
			var hi := -1
			for dz in range(-20, 21, 2):
				for dx in range(-16, 17, 2):
					var y := w.top_y(x + dx, z + dz)
					lo = mini(lo, y)
					hi = maxi(hi, y)
			if lo <= Defs.SEA + 1:
				continue
			if hi - lo < best_s:
				best_s = hi - lo
				best = Vector3(x, w.top_y(x, z) + 1, z)
	return best


## Il mix da campo che l'IA recluta con quella quota di cavalieri nemici (senza macchine d'assedio).
func _ai_mix(mix: Vector2) -> Dictionary:
	var gold := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var tot := 0.0
	for k in 4000:
		var ty := Sim.ai_pick_unit(rng.randf(), rng.randf(), mix)
		if ty == Defs.ARIETE or ty == Defs.CATAPULTA or ty == Defs.BOMBARDA:
			continue
		gold[ty] = float(gold.get(ty, 0.0)) + float(Defs.UNITS[ty].cost)
		tot += float(Defs.UNITS[ty].cost)
	for ty: int in gold:
		gold[ty] = float(gold[ty]) / tot
	return gold


func _run() -> void:
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var g := Game.new()
	g.name = "Game"
	main.add_child(g)
	g.start_solo(1, "Prova", PackedStringArray())
	var sim: Sim = g.sim
	sim.events_enabled = false
	sim.ai_enabled = false
	sim.equal_houses = true
	sim.truce_until = 0.0
	var ep := _flat_field(g)
	var K := {Defs.CAVALIERE: 1.0}
	var F := {Defs.FANTE: 1.0}
	var B := {Defs.BALESTRIERE: 1.0}
	var rows := [["cavalieri", K, "cavalieri", K], ["cavalieri", K, "fanti", F], ["cavalieri", K, "balestrieri", B],
		["cavalieri", K, "IA tranquilla", _ai_mix(Vector2.ZERO)], ["cavalieri", K, "IA contro cavalieri", _ai_mix(Vector2(1, 0))], ["fanti", F, "balestrieri", B], ["fanti", F, "IA tranquilla", _ai_mix(Vector2.ZERO)], ["fanti", F, "IA contro fanti", _ai_mix(Vector2(0, 1))]]
	var res := {}
	for r: Array in rows:
		var v := _match(sim, ep, r[1], r[3])
		res[r[0] + "/" + r[2]] = v
		print("     %s contro %s: %+.2f" % [r[0], r[2], v])
	check("specchio equilibrato", absf(res["cavalieri/cavalieri"]) < 0.25)
	check("i fanti battono i cavalieri", res["cavalieri/fanti"] < -0.25)
	check("i cavalieri battono i balestrieri", res["cavalieri/balestrieri"] > 0.25)
	check("l'IA che vede cavalieri recluta picche e li batte", res["cavalieri/IA contro cavalieri"] < -0.15)
	check("contro i fanti l'IA non va peggio di prima delle picche (+0.57)", res["fanti/IA contro fanti"] < 0.57)
	check("contro i cavalieri l'IA fa più fanti", float(_ai_mix(Vector2(1, 0)).get(Defs.FANTE, 0.0)) > float(_ai_mix(Vector2.ZERO).get(Defs.FANTE, 0.0)) + 0.2)
	print("matchups: %d errori" % fails)
	quit(1 if fails > 0 else 0)
