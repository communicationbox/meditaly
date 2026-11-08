extends SceneTree
## Truppe incastrate: partita tra sole IA, senza grafica. Ogni secondo guarda chi vorrebbe
## muoversi (ordine o castello da raggiungere) ma in 15 s non ha fatto 2 metri, e dice dove si trova.
##   godot --headless --path . -s tests/stuck.gd -- [--seed 1] [--min 12] [--max-stuck 0.01] [--trace [--trace-id N]]

const HG := preload("res://tests/balance.gd")
const WINDOW := 15

var hist := {}  # id -> Array di posizioni, una al secondo
var flagged := {}  # id -> descrizione la prima volta che è incastrata
var seen := {}
var trace_id := -1
var trace_left := 0


func _init() -> void:
	_run.call_deferred()


func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 else def


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var minutes := _opt(a, "--min", "12").to_float()
	var max_ratio := _opt(a, "--max-stuck", "0.01").to_float()
	var world := VoxelWorld.new()
	var castles := WorldGen.generate(world, Game.SEED)
	var g = HG.HeadlessGame.new()
	g.world = world
	var sim := Sim.new()
	g.sim = sim
	sim.events_enabled = false
	sim.seed_override = _opt(a, "--seed", "1").to_int()
	sim.setup(g, castles)
	var step := 1.0 / Defs.SIM_HZ
	var next_s := 1.0
	while sim.winner < 0 and sim.time < minutes * 60.0:
		sim.tick(step)
		if trace_left > 0 and sim.by_id.has(trace_id):
			trace_left -= 1
			var tu: Sim.U = sim.by_id[trace_id]
			if trace_left % 3 == 0:
				print("  trace t=%.2f pos=(%.2f,%.2f,%.2f) yaw=%.2f moving=%s stuck=%.2f inside_own=%d exiting=%d goal=%d ordine=%s verso (%.1f,%.1f) tgt=%s" % [sim.time, tu.pos.x, tu.pos.y, tu.pos.z, tu.yaw, tu.moving, tu.stuck, tu.inside_own, tu.exiting, tu.goal, tu.has_order, tu.target.x, tu.target.z, tu.tgt != null])
		var i: int = g.pending.size() - 1
		while i >= 0:
			if float(g.pending[i][0]) <= sim.time:
				var e: Array = g.pending[i]
				g.pending.remove_at(i)
				sim.fragment_landed(e[1], e[2])
			i -= 1
		if sim.time >= next_s:
			next_s += 1.0
			_sample(sim)
	var kinds := {}
	for id: int in flagged:
		var k: String = flagged[id].kind
		kinds[k] = int(kinds.get(k, 0)) + 1
	print("unità viste: %d, incastrate almeno una volta: %d" % [seen.size(), flagged.size()])
	for k: String in kinds:
		print("  %-40s %d" % [k, kinds[k]])
	var shown := 0
	for id: int in flagged:
		if shown < 12:
			print("  esempio: ", flagged[id].text)
			shown += 1
	var ratio := float(flagged.size()) / maxf(seen.size(), 1.0)
	print("RISULTATO incastrate=%.1f%% (limite %.1f%%)" % [ratio * 100.0, max_ratio * 100.0])
	quit(0 if ratio <= max_ratio else 1)


func _sample(sim: Sim) -> void:
	var alive := {}
	for u: Sim.U in sim.ulist:
		if u.hp <= 0.0:
			continue
		alive[u.id] = true
		seen[u.id] = true
		# vuole muoversi e non sta combattendo: solo così una sosta conta come incastro
		var busy: bool = not (u.has_order or u.goal >= 0) or u.attacking or u.garrison or u.tgt != null
		var h: Array = hist.get(u.id, [])
		h.append([u.pos, busy])
		if h.size() > WINDOW:
			h.pop_front()
		hist[u.id] = h
		if h.size() < WINDOW or flagged.has(u.id):
			continue
		var any_busy := false
		for e: Array in h:
			if e[1]:
				any_busy = true
				break
		if any_busy:
			continue
		var p0: Vector3 = h[0][0]
		var moved := Vector2(p0.x - u.pos.x, p0.z - u.pos.z).length()
		if moved < 2.0:
			flagged[u.id] = _describe(sim, u)
			var want_id := _opt(OS.get_cmdline_user_args(), "--trace-id", "-1").to_int()
			if trace_id < 0 and OS.get_cmdline_user_args().has("--trace") and (want_id < 0 or want_id == u.id):
				trace_id = u.id
				trace_left = 60
				print("TRACE ", flagged[u.id].text)
	for id: int in hist.keys():
		if not alive.has(id):
			hist.erase(id)


func _describe(sim: Sim, u: Sim.U) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for c: Dictionary in sim.castles:
		var d: float = Vector2((c.center as Vector3).x - u.pos.x, (c.center as Vector3).z - u.pos.z).length()
		if d < bd:
			bd = d
			best = c
	var ce: Vector3 = best.center
	var ax := absf(u.pos.x - ce.x)
	var az := absf(u.pos.z - ce.z)
	var where := "fuori"
	if ax < Sim.R - 1.0 and az < Sim.R - 1.0:
		where = "cortile"
	elif ax < Sim.R + 3.0 and az < Sim.R + 3.0:
		where = "mura"
	elif bd > Sim.R + 20.0:
		where = "campagna"
	var rel := "proprio" if int(best.owner) == u.team else "nemico"
	var ground := sim.world.top_y(int(u.pos.x), int(u.pos.z))
	var kind := "%s %s%s%s" % [where, rel, " (esce dal proprio)" if u.inside_own >= 0 else "", " sopra struttura" if u.pos.y > ground + 2.5 else ""]
	var text := "%s #%d %s a %s (%.0f,%.1f,%.0f) goal=%d ordine=%s verso (%.0f,%.0f) stuck=%.1f acqua=%s" % [
		Defs.UNITS[u.type].name, u.id, Defs.HOUSES[u.team].name, best.name, u.pos.x, u.pos.y, u.pos.z,
		u.goal, u.has_order, u.target.x, u.target.z, u.stuck, u.water]
	return {"kind": kind, "text": text}
