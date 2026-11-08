extends SceneTree
## Regole senza grafica: conquista e vittoria, crateri, codifica delle modifiche, riparazioni.
##   godot --headless --path . -s tests/rules.gd

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
	var sim: Sim = g.sim
	sim.events_enabled = false  # gli eventi a sorpresa si provano a parte, in fondo
	var w: VoxelWorld = g.world
	# codifica: l'ultimo voxel del mondo deve sopravvivere al giro nell'int64 (e al passaggio in rete)
	var last := Defs.WX * Defs.WZ * Defs.WY - 1
	var enc := PackedInt64Array([(last << Defs.EDIT_SHIFT) | (Defs.TEAM0 + 8)])
	enc = enc.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD).decompress(enc.size() * 8, FileAccess.COMPRESSION_ZSTD).to_int64_array()
	check("codifica: indice massimo", (enc[0] >> Defs.EDIT_SHIFT) == last)
	check("codifica: materiale massimo", (enc[0] & Defs.EDIT_MASK) == Defs.TEAM0 + 8)
	check("codifica: valore positivo", enc[0] > 0)
	# crateri ripetuti non arrivano mai al livello del mare
	var c: Dictionary = g.castles[0]
	var ce: Vector3 = c.center
	var p := ce + Vector3(30, 0, 30)
	p.y = w.top_y(int(p.x), int(p.z))
	for k in 30:
		p.y = w.top_y(int(p.x), int(p.z))  # ogni colpo scava più a fondo
		sim.blast(p, 6.0, 4.0, 0, 0.0, "")
	var lowest := 999
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			lowest = mini(lowest, w.top_y(int(p.x) + dx, int(p.z) + dz))
	check("30 esplosioni: il cratere resta sopra il mare (%d > %d)" % [lowest, Defs.SEA], lowest > Defs.SEA)
	# crollo: tagliata la base, la torre si stacca e diventa un corpo rigido
	var tp: Vector3 = c.towers[0]
	var removed := PackedInt64Array()
	var tx := int(tp.x)
	var tz := int(tp.z)
	var base: int = c.base
	var y_cut := base + 3
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			if w.get_v(tx + dx, y_cut, tz + dz) >= Defs.STRUCT_MIN:
				removed.append(w.index(tx + dx, y_cut, tz + dz) << Defs.EDIT_SHIFT)
	var integrity_top := w.get_v(tx, base + 10, tz)
	check("torre integra prima del taglio", integrity_top != 0)
	g.push_edits(removed)
	var cut := PackedInt32Array()
	for e in removed:
		cut.append(e >> Defs.EDIT_SHIFT)
	var before := sim.fragments.size()
	sim._collapse_check(cut)
	# la torre è ancora attaccata alle mura: taglia anche i collegamenti
	check("torre appoggiata alle mura non crolla da sola", w.get_v(tx, base + 10, tz) != 0 or sim.fragments.size() > before)
	var fx := int(ce.x) + 60
	var fz := int(ce.z) + 60
	var fy := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			fy = maxi(fy, w.top_y(fx + dx, fz + dz) + 4)  # lontana anche dai pendii vicini
	var col := PackedInt64Array()
	for y in range(fy, fy + 6):
		col.append((w.index(fx, y, fz) << Defs.EDIT_SHIFT) | Defs.STONE)
	g.push_edits(col, false)
	var seeds := PackedInt32Array()
	for e in col:
		seeds.append(e >> Defs.EDIT_SHIFT)
	var n0 := sim.fragments.size()
	sim._collapse_check(seeds)
	check("colonna sospesa diventa frammento", sim.fragments.size() == n0 + 1)
	check("colonna sospesa tolta dalla griglia", w.get_v(fx, fy + 2, fz) == 0)
	# riparazione: rimette i voxel mancanti e consuma oro
	var own: Dictionary = g.castles[1]
	var bp: PackedInt64Array = own.blueprint
	var rm := PackedInt64Array()
	for k in range(0, 400, 2):
		rm.append((bp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(rm, false)
	sim._update_integrity(own)
	var i0: float = own.integrity
	sim.houses[1].gold = 500.0
	sim.cmd_repair(1, 1)
	for k in 60:
		sim._repair(own, 0.5)
	sim._update_integrity(own)
	check("riparazione ripristina le mura (%.3f -> %.3f)" % [i0, own.integrity], float(own.integrity) > i0)
	check("riparazione costa fiorini", sim.houses[1].gold < 500.0)
	# sotto attacco la riparazione rallenta a un quarto
	var rc: Dictionary = g.castles[3]
	var rbp: PackedInt64Array = rc.blueprint
	var rrm := PackedInt64Array()
	for k in 300:
		rrm.append((rbp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(rrm, false)
	sim.houses[3].gold = 500.0
	var missing := func() -> int:
		var n := 0
		for k in 300:
			if w.vox[rbp[k] >> Defs.EDIT_SHIFT] == 0:
				n += 1
		return n
	var m0: int = missing.call()
	rc.under_attack = true
	rc.repair_i = 0
	sim._repair(rc, 0.5)
	var m1: int = missing.call()
	rc.under_attack = false
	sim._repair(rc, 0.5)
	var m2: int = missing.call()
	check("riparazione sotto attacco lenta (%d) e normale (%d)" % [m0 - m1, m1 - m2], m0 - m1 == sim.REPAIR_PER_TICK_ATTACKED and m1 - m2 == sim.REPAIR_PER_TICK)
	# fiorini finiti: la riparazione si ferma invece di mangiarsi tutto l'incasso
	var bc: Dictionary = g.castles[1]
	var bbp: PackedInt64Array = bc.blueprint
	var brm := PackedInt64Array()
	for k in range(1, 600, 2):
		brm.append((bbp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(brm, false)
	sim.houses[1].gold = 6.0
	sim.houses[1].repair_spent = 0.0
	bc.repair = false
	sim.cmd_repair(1, 1)
	sim._repair(bc, 0.5)
	check("riparazione senza fiorini si ferma da sola", bc.repair == false)
	check("riparazione non va sotto zero (%.1f)" % sim.houses[1].gold, float(sim.houses[1].gold) >= 0.0)
	check("spesa in riparazioni registrata (%.1f)" % sim.houses[1].repair_spent, float(sim.houses[1].repair_spent) >= 5.0)
	sim._tick_slow(0.5)
	var hs1: Array = sim.state_array()[1][1]
	check("lo snapshot porta la spesa in riparazioni (%.1f/s)" % hs1[6], hs1.size() >= 7 and float(hs1[6]) > 0.0)
	sim.houses[1].gold = 500.0
	# la forma di Parmigiano non rompe mai i castelli di chi la lancia
	var ve: Dictionary = g.castles[2]
	var vc: Vector3 = ve.center
	sim._update_integrity(ve)
	var i_before: float = ve.integrity
	sim.wheels.append({"id": 9001, "pos": vc + Vector3(-60, 8, 0), "vel": Vector3(34, 0, 0), "t": 13.0, "team": 2, "roll": 0.0})
	while not sim.wheels.is_empty():
		sim._tick_wheels(1.0 / Defs.SIM_HZ)
	sim._update_integrity(ve)
	check("forma lanciata contro il proprio castello: mura intatte", is_equal_approx(float(ve.integrity), i_before))
	sim._spawn_wheel(2, vc + Vector3(0, 0, Sim.R + 18.0))
	var wh: Dictionary = sim.wheels[0]
	var w_from: Vector3 = wh.pos
	var w_dir: Vector3 = (wh.vel as Vector3).normalized()
	var clear := sim._segment_distance_2d(w_from, w_from + w_dir * 125.0, vc)
	check("bersaglio accanto al proprio castello: percorso lontano (%.0f)" % clear, clear > sim.WHEEL_OWN_MARGIN)
	while not sim.wheels.is_empty():
		sim._tick_wheels(1.0 / Defs.SIM_HZ)
	sim._update_integrity(ve)
	check("forma lanciata vicino al proprio castello: mura intatte", is_equal_approx(float(ve.integrity), i_before))
	var truce_save := sim.truce_until
	sim.truce_until = sim.time + 100.0
	sim.wheels.append({"id": 9003, "pos": vc + Vector3(-60, 8, 0), "vel": Vector3(34, 0, 0), "t": 13.0, "team": 1, "roll": 0.0})
	while not sim.wheels.is_empty():
		sim._tick_wheels(1.0 / Defs.SIM_HZ)
	sim._update_integrity(ve)
	check("in tregua la forma non sfonda il castello di un'altra casata", is_equal_approx(float(ve.integrity), i_before))
	sim.truce_until = 0.0
	sim.wheels.append({"id": 9002, "pos": vc + Vector3(-60, 8, 0), "vel": Vector3(34, 0, 0), "t": 13.0, "team": 1, "roll": 0.0})
	while not sim.wheels.is_empty():
		sim._tick_wheels(1.0 / Defs.SIM_HZ)
	sim.truce_until = truce_save
	sim._update_integrity(ve)
	var carved_n := int((i_before - float(ve.integrity)) * float(ve.bp_size))
	check("forma nemica sfonda le mura (%d blocchi)" % carved_n, carved_n > 150)
	# comandi non validi dalla rete vengono scartati
	var u0: Sim.U = sim.ulist[0]
	check("tipo errato rifiutato", not g._args_ok("order", [1, 2, 3]))
	check("comando sconosciuto rifiutato", not g._args_ok("boom", []))
	var foreign := PackedInt32Array([u0.id])
	var had := u0.has_order
	sim.cmd_order((u0.team + 1) % 8, foreign, Vector3(50, 12, 50), false)
	check("non si comandano le truppe altrui", u0.has_order == had)
	# conquista: si prende il castello solo uccidendo il re sul gabinetto nel mastio
	var target: Dictionary = g.castles[4]
	for u: Sim.U in sim.ulist.duplicate():
		if u.team == target.owner or u.team == 1:
			u.hp = 0.0
	sim._cleanup_dead()
	sim.ai_enabled = false
	target.militia_t = 99999.0
	var step := 1.0 / Defs.SIM_HZ
	var run := func(sec: float, until: Callable) -> float:
		var t0 := sim.time
		var ms := Time.get_ticks_msec()
		while sim.time - t0 < sec and not until.call():
			sim.tick(step)
		print("     (%.0f s simulati in %d ms)" % [sim.time - t0, Time.get_ticks_msec() - ms])
		return sim.time - t0
	# balestrieri fuori dalle mura: il re non lo vedono
	var ce4: Vector3 = target.center
	var outside: Array = []
	for k in 6:
		var op: Vector3 = ce4 - (target.dir as Vector3) * (Sim.R + 8.0) + Vector3(k - 3, 0, 0)
		op.y = w.top_y(int(op.x), int(op.z))
		outside.append(sim.spawn_unit(Defs.BALESTRIERE, 1, op))
	run.call(10.0, func() -> bool: return false)
	check("da fuori le mura il re non si colpisce (%.0f/%.0f)" % [target.king_hp, Sim.KING_HP], float(target.king_hp) >= Sim.KING_HP)
	for u: Sim.U in outside:
		u.hp = 0.0
	sim._cleanup_dead()
	var defender := sim.spawn_unit(Defs.FANTE, target.owner, target.rally)
	defender.hp = 99999.0
	for k in 12:
		# resistenti: qui si prova il re, non le difese (torri, olio e mangano li sfoltirebbero)
		var att := sim.spawn_unit(Defs.FANTE, 1, (target.rally as Vector3) + Vector3(k % 4 - 2, 0, k / 4 - 1))
		att.hp = 5000.0
	run.call(8.0, func() -> bool: return false)
	check("con un difensore vivo si combatte lui, non il re", target.owner != 1 and float(target.king_hp) >= Sim.KING_HP)
	defender.hp = 0.0
	sim._cleanup_dead()
	var hurt_seen := [false]
	var took: float = run.call(60.0, func() -> bool:
		if float(target.king_hp) < Sim.KING_HP:
			hurt_seen[0] = true
		return target.owner == 1)
	check("i soldati entrano nel mastio e feriscono il re", hurt_seen[0])
	check("re ucciso: castello conquistato in %.0f s" % took, target.owner == 1)
	check("il nuovo re si siede e per un po' non lo si tocca", float(target.king_safe) > 0.0 and float(target.king_hp) >= Sim.KING_HP)
	# senza colpi il re si riprende
	target.king_hp = Sim.KING_HP * 0.5
	target.king_calm = 0.0
	sim._tick_castle(target, 5.0)
	check("senza colpi il re si riprende", float(target.king_hp) > Sim.KING_HP * 0.5)
	sim.ai_enabled = true
	var banner_ok := true
	for i in (target.banners as PackedInt32Array):
		if w.vox[i] != 0 and w.vox[i] != Defs.TEAM0 + 1:
			banner_ok = false
	check("gli stendardi prendono il colore del conquistatore", banner_ok)
	check("la conquista paga %d fiorini" % int(Defs.CAPTURE_REWARD), float(sim.houses[1].gold) >= Defs.CAPTURE_REWARD)
	# edifici e fede: si parte senza niente; si costruisce fuori dalle mura, vicino ai propri castelli
	sim.truce_until = 0.0  # qui si provano attacchi fra casate: la tregua è finita
	var mi: Dictionary = g.castles[1]
	check("all'inizio nessuna chiesa", not sim.has_building(1, Defs.B_CHIESA) and sim.buildings.is_empty())
	var rates: Array = sim._faith_rates(0.0)
	check("senza chiesa niente Fede", float(rates[1]) == 0.0)
	var h1: Dictionary = sim.houses[1]
	h1.faith = 150.0
	h1.cd[Defs.P_PARMIGIANO] = 0.0
	h1.gold = 2000.0
	var aim: Vector3 = g.castles[3].center
	sim.cmd_power(1, Defs.P_PARMIGIANO, aim)
	check("senza caseificio niente Parmigiano", float(h1.cd[Defs.P_PARMIGIANO]) == 0.0 and float(h1.faith) == 150.0)
	check("dentro le mura non si costruisce", sim.spot_problem(1, mi.center) != "")
	check("lontano dai propri castelli non si costruisce", sim.spot_problem(1, (mi.center as Vector3) + Vector3(Buildings.RANGE + 40.0, 0, 0)) != "")
	check("davanti alla porta non si costruisce", sim.spot_problem(1, (mi.center as Vector3) + (mi.dir as Vector3) * (Sim.R + 30.0)) != "")
	var spot := sim.find_spot(1, mi)
	check("c'è posto per costruire attorno a Milano", spot.y > -0.5)
	sim.cmd_build(1, Defs.B_CASEIFICIO, spot)
	check("costruire costa fiorini", float(h1.gold) == 2000.0 - Defs.BUILDINGS[Defs.B_CASEIFICIO].cost)
	check("il cantiere non dà ancora il potere", not sim.has_building(1, Defs.B_CASEIFICIO))
	sim._tick_buildings(30.0)
	sim._tick_buildings(0.5)
	var shop: Dictionary = sim.buildings[0]
	var sidx: PackedInt32Array = shop.idx
	check("il caseificio è finito e in piedi (%d voxel)" % sidx.size(), sim.has_building(1, Defs.B_CASEIFICIO) and sidx.size() > 100 and w.vox[sidx[0]] != 0)
	check("vicino a un caseificio non se ne costruisce un altro sopra", sim.spot_problem(1, spot) != "")
	sim.cmd_power(1, Defs.P_PARMIGIANO, aim)
	check("col caseificio il Parmigiano parte", float(h1.cd[Defs.P_PARMIGIANO]) > 0.0)
	sim.wheels.clear()
	# più chiese, più Fede
	for k in 2:
		var cs_p := sim.find_spot(1, mi)
		sim.build_now(1, Defs.B_CHIESA, cs_p)
	rates = sim._faith_rates(0.0)
	check("due chiese, Fede doppia (%.2f/s)" % float(rates[1]), is_equal_approx(float(rates[1]), 2.0 * Defs.FAITH_CHURCH))
	var q1: int = (mi.queue as Array).size()
	sim.cmd_recruit(1, mi.id, Defs.FRATE)
	check("con una chiesa si reclutano frati", (mi.queue as Array).size() == q1 + 1)
	# i fanti nemici abbattono la bottega: chi la possiede perde il vantaggio
	var raiders: Array = []
	var front: Array = Buildings.front(Vector2i(shop.x, shop.z), int(shop.base), Vector2i(shop.fx, shop.fz))
	for k in 8:
		var r := sim.spawn_unit(Defs.FANTE, 2, (front[0] as Vector3) + Vector3(k % 4 - 2, 0, k / 4) * 1.5)
		r.hp = 9999.0
		r.btgt = int(shop.id)
		raiders.append(r)
	var shop_id: int = shop.id
	var razed: float = run.call(90.0, func() -> bool: return not sim.bldg_by_id.has(shop_id))
	check("i fanti abbattono il caseificio (%.0f s)" % razed, not sim.bldg_by_id.has(shop_id))
	check("caseificio abbattuto: il Parmigiano non c'è più", not sim.has_building(1, Defs.B_CASEIFICIO))
	for r: Sim.U in raiders:
		r.hp = 0.0
	sim._cleanup_dead()
	# salvataggio: tutto torna com'era (file a parte, la partita del giocatore non si tocca)
	SaveGame.PATH = "user://prova_salvataggio.sav"
	var n_units := sim.ulist.size()
	var n_bld := sim.buildings.size()
	var t_now := sim.time
	check("la partita si salva", SaveGame.save(g))
	var sd := SaveGame.load_data()
	check("il salvataggio si rilegge", not sd.is_empty() and int(sd.house) == g.my_house)
	var d_sim: Dictionary = sd.sim
	check("salvati unità (%d), botteghe (%d) e tempo" % [(d_sim.units as Array).size(), (d_sim.buildings as Array).size()], (d_sim.units as Array).size() == n_units and (d_sim.buildings as Array).size() == n_bld and is_equal_approx(float(d_sim.time), t_now))
	var raw: PackedByteArray = sd.edits
	check("salvate tutte le modifiche al mondo", raw.decompress(int(sd.edits_size), FileAccess.COMPRESSION_ZSTD).to_int64_array().size() == g.edit_log.size())
	sim.load_state(d_sim)
	check("ricaricata la partita: stesse unità e botteghe", sim.ulist.size() == n_units and sim.buildings.size() == n_bld)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))
	SaveGame.PATH = "user://partita.sav"
	# il menestrello stona: i nemici vicini combattono peggio
	var vict := sim.spawn_unit(Defs.FANTE, 2, (mi.center as Vector3) + Vector3(40, 0, 40))
	var bard := sim.spawn_unit(Defs.MENESTRELLO, 1, vict.pos + Vector3(3, 0, 0))
	sim.bards.clear()
	sim.bards.append(bard)
	sim._retarget(vict, 10.0)
	check("vicino al menestrello nemico si stona", vict.sung)
	vict.hp = 0.0
	bard.hp = 0.0
	sim._cleanup_dead()
	# tregua: l'IA non punta nessun castello, neanche quelli senza padrone
	sim.time = 10.0
	sim.truce_until = Sim.TRUCE_TIME
	for cs: Dictionary in g.castles:
		cs.owner = cs.start_house
	check("in tregua l'IA non attacca neanche i castelli liberi", sim._ai_target(2, g.castles[2].center).is_empty())
	for cs: Dictionary in g.castles:
		if cs.owner == Defs.NEUTRAL:
			cs.owner = 0
	sim.time = Sim.TRUCE_TIME + 1.0
	check("dopo la tregua l'IA può attaccare", not sim._ai_target(2, g.castles[2].center).is_empty())
	# un castello che nessuno disturba da tanto (Palermo, sull'isola) attira le IA anche da lontano
	for cs: Dictionary in g.castles:
		cs.owner = cs.start_house
		cs.quiet_t = 0.0
	var pa: Dictionary = g.castles[10]
	var near_t := sim._ai_target(6, g.castles[8].center)
	check("all'inizio Napoli non punta Palermo (%s)" % near_t.get("name", "-"), near_t.get("id", -1) != 10)
	pa.quiet_t = Sim.QUIET_FULL + 1.0
	check("Palermo tranquillo da tanto: diventa un bersaglio", sim._quiet_factor(pa) <= Sim.QUIET_MIN + 0.001)
	for cs: Dictionary in g.castles:
		cs.owner = cs.start_house
	# guarnigione: chi resta a casa non parte
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	for k in 12:
		sim.spawn_unit(Defs.FANTE, 2, (g.castles[2].rally as Vector3) + Vector3(k % 4 - 2, 0, k / 4))
	check("l'IA lascia %d soldati di guardia" % Sim.AI_GUARD, sim._ai_army(2).size() == 12 - Sim.AI_GUARD)
	# il limite di truppe cresce con i castelli
	sim.houses[2].gold = 99999.0
	var base_cap: int = Defs.AI_UNIT_CAP + Defs.AI_UNIT_CAP_PER_CASTLE
	for k in 40:
		sim.cmd_recruit(2, 2, Defs.FANTE)
		(g.castles[2].queue as Array).clear()
		sim.spawn_unit(Defs.FANTE, 2, g.castles[2].rally)
	check("limite truppe IA = %d con un castello" % base_cap, sim.house_unit_count(2) >= base_cap)
	# milizia: arriva solo se non ci sono nemici vicini
	var mc: Dictionary = g.castles[8]
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	mc.queue = []  # le reclute in coda non sono milizia
	var enemy := sim.spawn_unit(Defs.FANTE, 2, mc.rally)
	enemy.hp = 99999.0
	mc.militia_t = 0.0
	sim._tick_castle(mc, 0.5)
	check("nessuna milizia con il nemico nel cortile", sim.house_unit_count(mc.owner) == 0)
	enemy.hp = 0.0
	sim._cleanup_dead()
	mc.militia_t = 0.0
	sim._tick_castle(mc, 0.5)
	check("la milizia arriva quando il nemico se n'è andato (%d)" % sim.house_unit_count(mc.owner), sim.house_unit_count(mc.owner) == 1)
	# eventi a sorpresa
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var ec: Dictionary = g.castles[2]
	var ep: Vector3 = (ec.gate_out as Vector3) + (ec.dir as Vector3) * 14.0
	var eaters: Array = []
	for k in 10:
		eaters.append(sim.spawn_unit(Defs.FANTE, ec.owner, ep + Vector3(k % 5 * 1.5, 0, k / 5 * 1.5)))
		eaters.append(sim.spawn_unit(Defs.FANTE, (int(ec.owner) + 1) % 8, ep + Vector3(k % 5 * 1.5, 0, 4 + k / 5 * 1.5)))
	check("la sagra parte con gente in campo", sim._run_event(0))
	var all_eat := true
	var hp0 := 0.0
	for u: Sim.U in eaters:
		all_eat = all_eat and u.feast > 0.0
		hp0 += u.hp
	check("alla sagra vanno tutti, di ogni casata", all_eat)
	for k in Defs.SIM_HZ * 3:
		sim.tick(1.0 / Defs.SIM_HZ)
	var hp1 := 0.0
	for u: Sim.U in eaters:
		hp1 += u.hp
	check("a tavola non si combatte", is_equal_approx(hp0, hp1))
	for u: Sim.U in eaters:
		u.feast = 0.0
	var lead := sim._leader()
	check("c'è una casata in testa", lead >= 0)
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var lc: Dictionary = {}
	for cs: Dictionary in g.castles:
		if int(cs.owner) == lead:
			lc = cs
	var strikers: Array = []
	for k in 8:
		strikers.append(sim.spawn_unit(Defs.BALESTRIERE, lead, (lc.gate_out as Vector3) + (lc.dir as Vector3) * 16.0 + Vector3(k * 1.5, 0, 0)))
	sim.spawn_unit(Defs.FANTE, lead, (lc.gate_out as Vector3) + (lc.dir as Vector3) * 16.0)
	check("lo sciopero parte", sim._run_event(1))
	var ids := PackedInt32Array()
	var sp0: Vector3 = (strikers[0] as Sim.U).pos
	for u: Sim.U in strikers:
		ids.append(u.id)
	sim.cmd_order(lead, ids, sp0 + Vector3(40, 0, 0), false)
	for k in Defs.SIM_HZ * 2:
		sim.tick(1.0 / Defs.SIM_HZ)
	check("in sciopero non si muovono nemmeno con un ordine", (strikers[0] as Sim.U).pos.distance_to(sp0) < 1.0 and (strikers[0] as Sim.U).sleep > 0.0)
	for u: Sim.U in strikers:
		u.sleep = 0.0
	check("la mamma chiama", sim._run_event(2))
	var called := 0
	for u: Sim.U in sim.ulist:
		if u.team == lead and u.feast > 0.0:
			called += 1
	check("metà armata torna a casa (%d)" % called, called >= 4 and called <= 5)
	sim.houses[1].faith = 150.0
	sim.houses[1].all_shops = true
	check("la processione parte", sim._run_event(3))
	sim.cmd_power(1, Defs.P_VINO, ep)
	check("in processione niente poteri", float(sim.houses[1].faith) == 150.0)
	sim.procession_until = 0.0
	sim.cmd_taunt(1, 0)
	var cd1: float = sim.taunt_cd[1]
	sim.cmd_taunt(1, 1)
	check("sfottò: uno ogni %d secondi" % int(Sim.TAUNT_CD), cd1 >= sim.time + Sim.TAUNT_CD - 0.01 and is_equal_approx(float(sim.taunt_cd[1]), cd1))
	# tregua: le casate non si combattono, i castelli liberi sì
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var t_save := sim.time
	sim.truce_until = sim.time + 100.0
	var ta := sim.spawn_unit(Defs.FANTE, 1, ep)
	var tb := sim.spawn_unit(Defs.FANTE, 3, ep + Vector3(1.5, 0, 0))
	var tn := sim.spawn_unit(Defs.FANTE, Defs.NEUTRAL, ep + Vector3(0, 0, 1.5))
	tn.hp = 99999.0
	ta.hp = 99999.0
	tb.hp = 99999.0
	var hb := tb.hp
	for k in Defs.SIM_HZ * 2:
		sim.tick(1.0 / Defs.SIM_HZ)
	check("in tregua le casate non si picchiano", is_equal_approx(tb.hp, hb))
	check("in tregua i neutrali si combattono", tn.hp < 99999.0)
	sim._splash(tb.pos, 5.0, 50.0, 1)
	check("in tregua il danno ad area non tocca le altre casate", is_equal_approx(tb.hp, hb))
	var hc2: Dictionary = {}
	for cs: Dictionary in g.castles:
		if int(cs.owner) == 3:
			hc2 = cs
	sim.cmd_order(1, PackedInt32Array([ta.id]), hc2.center, false)
	check("in tregua non si ordina l'attacco a un'altra casata", not ta.has_order or ta.goal != hc2.id)
	sim.houses[1].faith = 150.0
	sim.houses[1].all_shops = true
	sim.cmd_power(1, Defs.P_MUCCHE, hc2.center)
	check("in tregua niente poteri sulle altre casate", float(sim.houses[1].faith) == 150.0)
	sim.truce_until = 0.0
	sim.time = t_save
	# palio: i cavalieri corrono, il primo vince i fiorini
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var riders: Array = []
	for k in 3:
		riders.append(sim.spawn_unit(Defs.CAVALIERE, 1, ep + Vector3(k * 2.0, 0, -6)))
		riders.append(sim.spawn_unit(Defs.CAVALIERE, 3, ep + Vector3(k * 2.0, 0, 6)))
	sim.ai_enabled = false  # l'IA spenderebbe i fiorini del premio prima del controllo
	check("il palio parte", sim._run_event(4))
	var g1: float = sim.houses[1].gold
	var g3: float = sim.houses[3].gold
	var palio_t0 := sim.time
	for k in Defs.SIM_HZ * 46:
		sim.tick(1.0 / Defs.SIM_HZ)
		if sim.palio_until <= 0.0:
			break
	print("     palio finito in %.1f s, traguardo a %.0f m" % [sim.time - palio_t0, sim.palio_pos.distance_to(ep)])
	check("qualcuno vince il palio", sim.palio_until <= 0.0 and (float(sim.houses[1].gold) >= g1 + Defs.PALIO_PRIZE or float(sim.houses[3].gold) >= g3 + Defs.PALIO_PRIZE))
	# scomunica: la casata in testa resta senza Fede
	var lead2 := sim._leader()
	sim._run_event(5)
	check("scomunica: niente Fede", float(sim._faith_rates(0.5)[lead2]) == 0.0)
	sim.houses[lead2].excom_until = 0.0
	# davanti alla forma si scappa urlando
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var victim := sim.spawn_unit(Defs.FANTE, 3, ep + Vector3(12, 0, 0))
	victim.hp = 99999.0
	sim.wheels.append({"id": 9100, "pos": ep + Vector3(0, 4, 0), "vel": Vector3(30, 0, 0), "t": 5.0, "team": 1, "roll": 0.0})
	sim._tick_wheels(1.0 / Defs.SIM_HZ)
	check("davanti alla forma si scappa", victim.flee > 0.0)
	sim.wheels.clear()
	# vittoria: tutti i castelli alla stessa casata
	for cs: Dictionary in g.castles:
		cs.owner = 1
	sim._check_winner()
	check("tutti i castelli = vittoria", sim.winner == 1)
	print("FALLITI: ", fails)
	quit(fails)
