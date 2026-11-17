extends SceneTree
## Bot che gioca una missione della storia, senza finestra, a velocità 6x.
##   godot --headless --path . -s tests/campaign_bot.gd -- N      (N = missione, 1-12)
## Negli assalti fa come l'IA: raduna l'armata fuori tiro e parte tutta insieme. Gli arieti vanno
## alla porta con i fanti, le macchine d'assedio mirano alle mura, e usa i poteri sbloccati
## (costruendo prima chiesa e botteghe).

const STAGE_MIN := 22  # soldati al raduno prima di partire
const STAGE_TIMEOUT := 70.0  # oltre, parte con quello che ha (se ne ha almeno la metà)

var sim: Sim
var unl: Dictionary
var home: Dictionary


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Game.force_view = true
	var k0: int = OS.get_cmdline_user_args()[0].to_int()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for k in 600:
		if main.menu != null and main.menu.revealed:
			break
		await create_timer(0.1).timeout
	main._start_game().start_solo(0, "", PackedStringArray(["--missione", str(k0)]))
	var g: Game = main.game
	for k in 600:
		if g.mission != null:
			break
		await create_timer(0.1).timeout
	await create_timer(0.5).timeout
	var ms: Mission = g.mission
	ms._start()
	if is_instance_valid(ms.hints):
		ms.hints._finish()
	sim = g.sim
	home = sim.castles[Campaign.HOME_CASTLE]
	Engine.time_scale = 6.0
	unl = Campaign.unlocked_at(k0)
	var all_units: Array = unl.units if not unl.all else range(Defs.UNIT_TYPES)
	if all_units.is_empty():
		all_units = [Defs.FANTE]
	# l'armata: soprattutto fanti, qualche tiratore, un ariete e una macchina d'assedio ogni tanto
	var mix: Array = []
	for t: int in [Defs.FANTE, Defs.FANTE, Defs.BALESTRIERE, Defs.FANTE, Defs.CAVALIERE, Defs.ARIETE, Defs.FANTE, Defs.CATAPULTA, Defs.FANTE, Defs.BOMBARDA, Defs.NONNA]:
		if t in all_units:
			mix.append(t)
	var r := 0
	var church := Vector3.ZERO
	var kind := String(ms.m.goal.kind)
	var tgt: int = int(ms.m.goal.get("castles", [Campaign.HOME_CASTLE])[0])
	var phase := "raduno"
	var phase_t := 0.0
	var assault_n := 0
	var next_log := 0.0
	while not ms.ended and sim.time - ms.start_time < 700.0:
		await create_timer(1.0).timeout
		if sim.news_t > 0.0:  # gli eventi fermano tutti col giornale: il bot lo legge subito
			sim.cmd_news_read(0)
		if kind == "faith":
			if not sim.has_building(0, Defs.B_CHIESA) and church == Vector3.ZERO:
				church = sim.find_spot(0, home)
				sim.cmd_build(0, Defs.B_CHIESA, church)
			elif sim.has_building(0, Defs.B_CHIESA):
				sim.cmd_recruit(0, Campaign.HOME_CASTLE, Defs.FRATE)
				var fr := PackedInt32Array()
				for u: Sim.U in sim.ulist:
					if u.team == 0 and u.type == Defs.FRATE and not u.has_order and u.pos.distance_to(church) > 8.0:
						fr.append(u.id)
				if not fr.is_empty():
					sim.cmd_order(0, fr, church, false)
			continue
		_build_shops()
		if kind == "capture":
			for cid: int in ms.m.goal.castles:  # il primo castello non ancora preso
				if int(sim.castles[cid].owner) != 0:
					if cid != tgt:
						tgt = cid
						phase = "raduno"
						phase_t = sim.time
					break
		var c: Dictionary = sim.castles[tgt]
		if sim.time >= next_log:
			next_log = sim.time + 30.0
			_log(ms, c, phase)
		# recluta lasciando da parte i fiorini per le botteghe che mancano
		if mix.size() > 0 and sim.houses[0].gold >= _reserve() + float(Defs.UNITS[mix[r % mix.size()]].cost):
			sim.cmd_recruit(0, Campaign.HOME_CASTLE, int(mix[r % mix.size()]))
			r += 1
		if kind != "capture":
			continue
		var to_home: Vector3 = (home.center as Vector3) - (c.center as Vector3)
		to_home.y = 0.0
		var sp: Vector3 = (c.center as Vector3) + to_home.normalized() * (float(Sim.TOWER_RANGE) + Sim.R + 14.0)
		sp.y = sim.world.top_y(int(sp.x), int(sp.z))
		if phase == "raduno":
			var idle := PackedInt32Array()
			var ready := PackedInt32Array()
			for u: Sim.U in sim.ulist:
				if u.team != 0 or u.type == Defs.FRATE or u.garrison:
					continue
				if Vector2(u.pos.x - sp.x, u.pos.z - sp.z).length() < 22.0:
					ready.append(u.id)
				elif not u.has_order:
					idle.append(u.id)
			if not idle.is_empty():
				sim.cmd_order(0, idle, sp, false)
			var waited := sim.time - phase_t
			if ready.size() >= STAGE_MIN or (waited > STAGE_TIMEOUT and ready.size() >= STAGE_MIN / 2):
				assault_n += 1
				print("t=%d ASSALTO %d su %s con %d soldati" % [sim.time - ms.start_time, assault_n, c.name, ready.size()])
				_assault(ready, c, sp)
				phase = "assalto"
				phase_t = sim.time
		else:
			# durante l'assalto: poteri appena pronti, macchine d'assedio di nuovo sulle mura,
			# rinforzi dritti al castello
			_powers(c, sp)
			var siege := PackedInt32Array()
			var fresh := PackedInt32Array()
			var near := 0
			for u: Sim.U in sim.ulist:
				if u.team != 0 or u.type == Defs.FRATE or u.garrison:
					continue
				if u.pos.distance_to(c.center) < Sim.R + 30.0:
					near += 1
				if u.has_order:
					continue
				if u.type == Defs.CATAPULTA or u.type == Defs.BOMBARDA:
					siege.append(u.id)
				elif u.pos.distance_to(c.center) > Sim.R + 20.0:
					fresh.append(u.id)
			if not siege.is_empty() and float(c.integrity) > 0.2:
				var wp := sim._pick_castle_voxel(c, sp)
				if wp.y > -0.5:
					sim.cmd_order(0, siege, wp, true)
			# l'assalto è finito male: si torna a radunarsi
			if near < 4 and sim.time - phase_t > 40.0:
				phase = "raduno"
				phase_t = sim.time
			elif fresh.size() >= 8:
				sim.cmd_order(0, fresh, c.center, false)
	_log(ms, sim.castles[tgt], phase)
	print("MISSIONE %d: %s dopo %.0f s" % [k0, ("VINTA" if ms.ended and ms.won() else ("PERSA" if ms.ended else "NON FINITA")), sim.time - ms.start_time])
	quit()


func _log(ms: Mission, c: Dictionary, phase: String) -> void:
	var mine := 0
	for u: Sim.U in sim.ulist:
		if u.team == 0:
			mine += 1
	print("t=%d %s miei=%d oro=%d fede=%d %s: mura=%.2f re=%.0f padrone=%d" % [sim.time - ms.start_time, phase, mine, sim.houses[0].gold, sim.houses[0].faith, c.name, c.integrity, c.king_hp, c.owner])


## Tutti all'assalto: fanti, cavalieri e arieti al castello (passano dalla porta), le macchine
## d'assedio sulle mura dal lato del raduno, e subito i poteri.
func _assault(ids: PackedInt32Array, c: Dictionary, sp: Vector3) -> void:
	var siege := PackedInt32Array()
	var rest := PackedInt32Array()
	for id: int in ids:
		var u: Sim.U = sim.by_id[id]
		if u.type == Defs.CATAPULTA or u.type == Defs.BOMBARDA:
			siege.append(id)
		else:
			rest.append(id)
	if not siege.is_empty():
		var wp := sim._pick_castle_voxel(c, sp)
		if wp.y > -0.5:
			sim.cmd_order(0, siege, wp, true)
	sim.cmd_order(0, rest, c.center, false)
	_powers(c, sp)


func _power_ok(k: int) -> bool:
	if not (unl.all or k in unl.powers):
		return false
	var h: Dictionary = sim.houses[0]
	return h.faith >= float(Defs.POWERS[k].cost) and float(h.cd[k]) <= 0.0 and sim.has_building(0, Defs.POWER_BUILDING[k])


## Lancia ciò che è pronto: Parmigiano dritto nella porta, Terremoto sulle mura, Vino e Scudo
## sull'armata che avanza, Mucche nel cortile; il potere della casata sul castello.
func _powers(c: Dictionary, sp: Vector3) -> void:
	var ce: Vector3 = c.center
	var dir: Vector3 = c.dir
	# il centro dell'armata che attacca
	var army := Vector3.ZERO
	var n := 0
	for u: Sim.U in sim.ulist:
		if u.team == 0 and u.type != Defs.FRATE and u.pos.distance_to(ce) < Sim.R + 60.0:
			army += u.pos
			n += 1
	if n > 0:
		army /= n
	else:
		army = sp
	if _power_ok(Defs.P_PARMIGIANO) and float(c.integrity) > 0.3:
		var start := ce + dir * (Sim.R + 30.0)
		sim.cmd_power(0, Defs.P_PARMIGIANO, start, -dir * 70.0)
	if _power_ok(Defs.P_TERREMOTO) and float(c.integrity) > 0.4:
		sim.cmd_power(0, Defs.P_TERREMOTO, _ground(ce + dir * Sim.R * 0.8))
	if n >= 6 and army.distance_to(ce) < Sim.R + 40.0:
		if _power_ok(Defs.P_SCUDO):
			sim.cmd_power(0, Defs.P_SCUDO, _ground(army))
		if _power_ok(Defs.P_VINO):
			sim.cmd_power(0, Defs.P_VINO, _ground(army))
	if _power_ok(Defs.P_MUCCHE) and army.distance_to(ce) < Sim.R + 25.0:
		sim.cmd_power(0, Defs.P_MUCCHE, _ground(ce))
	if (unl.all or unl.special) and not sim.equal_houses:
		sim.cmd_special(0, _ground(ce))


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, sim.world.top_y(int(p.x), int(p.z)), p.z)


## Prima la chiesa (la Fede viene solo da lì) con tre frati, poi una bottega per ogni potere sbloccato.
func _build_shops() -> void:
	var want := _next_shop()
	if want >= 0 and sim.houses[0].gold >= float(Defs.BUILDINGS[want].cost):
		var p := sim.find_spot(0, home)
		if p.y > -0.5:
			sim.cmd_build(0, want, p)
	if (unl.all or Defs.FRATE in unl.units) and sim.has_building(0, Defs.B_CHIESA) and sim.houses[0].gold >= 80.0:
		var friars := 0
		for u: Sim.U in sim.ulist:
			if u.team == 0 and u.type == Defs.FRATE:
				friars += 1
		if friars < 3:
			sim.cmd_recruit(0, Campaign.HOME_CASTLE, Defs.FRATE)


func _next_shop() -> int:
	var powers: Array = range(Defs.POWER_COUNT) if unl.all else unl.powers
	if powers.is_empty():
		return -1
	if (unl.all or Defs.B_CHIESA in unl.build) and not _has_or_building(Defs.B_CHIESA):
		return Defs.B_CHIESA
	for k: int in powers:
		var b: int = Defs.POWER_BUILDING[k]
		if not _has_or_building(b):
			return b
	return -1


func _has_or_building(type: int) -> bool:
	for b: Dictionary in sim.buildings:
		if int(b.owner) == 0 and int(b.type) == type:
			return true
	return false


func _reserve() -> float:
	var want := _next_shop()
	return float(Defs.BUILDINGS[want].cost) if want >= 0 else 0.0
