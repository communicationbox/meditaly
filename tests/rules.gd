extends SceneTree
## Regole senza grafica: conquista e vittoria, crateri, codifica delle modifiche, riparazioni.
##   godot --headless --path . -s tests/rules.gd

const CTRL_SCRIPT := preload("res://scripts/controller.gd")
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
	var enc := PackedInt64Array([(last << Defs.EDIT_SHIFT) | (Defs.TEAM0 + Defs.NEUTRAL)])
	enc = enc.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD).decompress(enc.size() * 8, FileAccess.COMPRESSION_ZSTD).to_int64_array()
	check("codifica: indice massimo", (enc[0] >> Defs.EDIT_SHIFT) == last)
	check("codifica: materiale massimo", (enc[0] & Defs.EDIT_MASK) == Defs.TEAM0 + Defs.NEUTRAL)
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
	# ripara tutto: si paga subito in base ai blocchi, ci vuole il tempo che serve, non si riclicca
	var own: Dictionary = g.castles[1]
	var bp: PackedInt64Array = own.blueprint
	var rm := PackedInt64Array()
	for k in range(0, 400, 2):
		rm.append((bp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(rm, false)
	sim._update_integrity(own)
	var i0: float = own.integrity
	var holes: int = own.missing
	check("blocchi mancanti contati (%d)" % holes, holes >= 150)
	sim.houses[1].gold = 500.0
	sim.cmd_repair(1, 1)
	var paid := 500.0 - float(sim.houses[1].gold)
	check("si paga subito tutto (%d fiorini per %d blocchi)" % [int(paid), holes], int(paid) == Sim.repair_cost(holes) and own.repair)
	sim.cmd_repair(1, 1)
	check("durante i lavori non si riclicca", 500.0 - float(sim.houses[1].gold) == paid)
	var tick := 1.0 / Defs.SIM_HZ
	var half := int(Sim.repair_secs(holes) * Defs.SIM_HZ * 0.5)
	for k in half:
		sim._repair(own, tick)
	var left_half: int = own.repair_left
	check("a metà tempo, metà lavoro (%d su %d)" % [left_half, holes], left_half > holes * 0.3 and left_half < holes * 0.7)
	check("l'avanzamento arriva ai client", absf(float(sim.state_array()[0][1][11]) - (1.0 - float(left_half) / holes)) < 0.02)
	for k in Sim.repair_secs(holes) * int(Defs.SIM_HZ) + 10:
		if own.repair:
			sim._repair(own, tick)
	sim._update_integrity(own)
	check("lavori finiti: mura intere (%.3f -> %.3f)" % [i0, own.integrity], not own.repair and own.missing == 0)
	sim.houses[1].gold = 500.0
	sim.cmd_repair(1, 1)
	check("mura intatte: niente lavori e niente spesa", not own.repair and float(sim.houses[1].gold) == 500.0)
	# sotto attacco i muratori vanno a un quarto
	var rc: Dictionary = g.castles[3]
	var rbp: PackedInt64Array = rc.blueprint
	var rrm := PackedInt64Array()
	for k in 300:
		rrm.append((rbp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(rrm, false)
	sim.houses[3].gold = 500.0
	sim.cmd_repair(3, 3)
	rc.under_attack = true
	var l0: int = rc.repair_left
	for k in int(Defs.SIM_HZ):
		sim._repair(rc, tick)
	var slow: int = l0 - int(rc.repair_left)
	rc.under_attack = false
	var l1: int = rc.repair_left
	for k in int(Defs.SIM_HZ):
		sim._repair(rc, tick)
	var fast: int = l1 - int(rc.repair_left)
	check("sotto attacco più lenta (%d al secondo) che di solito (%d)" % [slow, fast], absi(slow - int(Sim.REPAIR_PER_SEC_ATTACKED)) <= 1 and absi(fast - int(Sim.REPAIR_PER_SEC)) <= 1)
	# fiorini insufficienti: non parte e non spende niente
	var bc: Dictionary = g.castles[1]
	var bbp: PackedInt64Array = bc.blueprint
	var brm := PackedInt64Array()
	for k in range(1, 600, 2):
		brm.append((bbp[k] >> Defs.EDIT_SHIFT) << Defs.EDIT_SHIFT)
	g.push_edits(brm, false)
	sim.houses[1].gold = 6.0
	sim.cmd_repair(1, 1)
	check("senza fiorini a sufficienza non parte", not bc.repair and float(sim.houses[1].gold) == 6.0)
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
	# lancio a mano: parte da dove si è premuto, verso il vettore, e la lunghezza è la potenza
	h1.cd[Defs.P_PARMIGIANO] = 0.0
	h1.faith = 200.0
	sim.cmd_power(1, Defs.P_PARMIGIANO, aim, Vector3(Sim.WHEEL_AIM_MAX, 0, 0))
	check("il vettore decide la direzione", sim.wheels.size() == 1 and float((sim.wheels[0].vel as Vector3).x) > 0.0 and absf(float((sim.wheels[0].vel as Vector3).z)) < 0.01)
	check("vettore lungo, forma veloce", sim.wheels.size() == 1 and is_equal_approx((sim.wheels[0].vel as Vector3).length(), Sim.WHEEL_SPEED_MAX))
	sim.wheels.clear()
	h1.cd[Defs.P_PARMIGIANO] = 0.0
	h1.faith = 200.0
	sim.cmd_power(1, Defs.P_PARMIGIANO, aim, Vector3(0, 0, Sim.WHEEL_AIM_MIN))
	check("vettore corto, forma lenta", sim.wheels.size() == 1 and is_equal_approx((sim.wheels[0].vel as Vector3).length(), Sim.WHEEL_SPEED_MIN))
	sim.wheels.clear()
	# più chiese, più Fede
	for k in 2:
		var cs_p := sim.find_spot(1, mi)
		sim.build_now(1, Defs.B_CHIESA, cs_p)
	rates = sim._faith_rates(0.0)
	check("due chiese, Fede doppia (%.2f/s)" % float(rates[1]), is_equal_approx(float(rates[1]), 2.0 * Defs.FAITH_CHURCH * sim._stat(1, Defs.STAT_FEDE)))
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
	check("subito dopo la tregua l'IA lascia stare le casate", sim._ai_target(2, g.castles[2].center).is_empty())
	sim.time = Sim.TRUCE_TIME + Sim.AI_HOUSE_GRACE + 1.0
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
	# il limite di chi gioca cresce con i castelli ed è rispettato da reclute, milizia, cugini e mazzetta
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var me := 1
	var mine_c: Dictionary = g.castles[1]
	check("limite con un castello = %d" % Defs.unit_cap(1), sim.unit_cap(me) == Defs.unit_cap(1))
	var lent: Dictionary = g.castles[4]
	var lent_was: int = lent.owner
	lent.owner = me
	check("con due castelli il limite sale (%d)" % sim.unit_cap(me), sim.unit_cap(me) == Defs.unit_cap(1) + Defs.UNIT_CAP_PER_CASTLE)
	lent.owner = lent_was
	sim.houses[me].gold = 99999.0
	var cap1 := sim.unit_cap(me)
	for k in cap1 + 20:
		sim.cmd_recruit(me, 1, Defs.FANTE)
		var q: Array = mine_c.queue
		if not q.is_empty():
			q[0].t = 0.0
			sim._tick_castle(mine_c, 0.1)
	check("reclutando non si supera il limite (%d/%d)" % [sim.house_unit_count(me), cap1], sim.house_unit_count(me) + sim._queued(me) <= cap1)
	# al limite: niente milizia anche con il cortile vuoto
	for u: Sim.U in sim.ulist:
		if u.team == me:
			u.pos = (mine_c.center as Vector3) + Vector3(200, 0, 0)
	mine_c.queue = []
	var cap_before := sim.house_unit_count(me)
	for k in 5:
		mine_c.militia_t = 0.0
		sim._tick_castle(mine_c, 0.5)
	check("al limite non arriva milizia (%d → %d)" % [cap_before, sim.house_unit_count(me)], sim.house_unit_count(me) <= cap1)
	# i cugini (Normanni) restano a casa quando il limite è pieno, e ne arrivano solo quanti ci stanno
	var cug := 7
	var cug_c: Dictionary = g.castles[10]
	sim.houses[cug].ai = false
	sim.truce_until = 0.0
	for cs: Dictionary in g.castles:
		cs.queue = []  # anche le reclute in coda contano nel limite
	for k in sim.unit_cap(cug) - 2:
		sim.spawn_unit(Defs.FANTE, cug, (cug_c.center as Vector3) + Vector3(300, 0, 0))
	sim.houses[cug].sp_t = 0.0
	sim.cmd_special(cug, cug_c.center)
	check("cugini: ne arrivano solo 2, quanti ne stanno (%d/%d)" % [sim.house_unit_count(cug), sim.unit_cap(cug)], sim.house_unit_count(cug) == sim.unit_cap(cug))
	sim.houses[cug].sp_t = 0.0
	check("cugini: al limite il potere non parte", not sim.cmd_special(cug, cug_c.center))
	sim.houses[cug].ai = true
	# mazzetta (Medici): al limite non si compra nessuno
	var mz := 4
	sim.houses[mz].ai = false
	for k in sim.unit_cap(mz):
		sim.spawn_unit(Defs.FANTE, mz, (g.castles[5].center as Vector3) + Vector3(300, 0, 0))
	var bribe_at: Vector3 = (g.castles[7].center as Vector3) + Vector3(60, 0, 0)
	bribe_at.y = w.top_y(int(bribe_at.x), int(bribe_at.z))
	for k in 4:
		sim.spawn_unit(Defs.FANTE, 5, bribe_at + Vector3(k, 0, 0))
	sim.houses[mz].sp_t = 0.0
	check("mazzetta: al limite il potere non parte", not sim.cmd_special(mz, bribe_at))
	check("mazzetta: nessuno cambia bandiera", sim.house_unit_count(mz) == sim.unit_cap(mz))
	sim.houses[mz].ai = true
	# bandiera di raduno: le reclute del castello ci vanno; sul castello stesso si toglie
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	for cs: Dictionary in g.castles:
		cs.queue = []
	var fc: Dictionary = g.castles[1]
	var fp: Vector3 = (fc.center as Vector3) + Vector3(70, 0, 20)
	sim.cmd_rally(me, 1, fp)
	check("bandiera piantata", bool(fc.flag_on) and (fc.flag as Vector3).distance_to(Vector3(fp.x, fc.flag.y, fp.z)) < 0.1)
	check("la bandiera arriva ai client", sim.state_array()[0][1][10] != null)
	sim.cmd_rally(2, 1, fp + Vector3(5, 0, 0))
	check("la bandiera di un altro castello non si sposta", (fc.flag as Vector3).x == fp.x)
	sim.houses[me].gold = 999.0
	sim.cmd_recruit(me, 1, Defs.FANTE)
	(fc.queue[0] as Dictionary).t = 0.0
	sim._tick_castle(fc, 0.1)
	var rec: Sim.U = null
	for u: Sim.U in sim.ulist:
		if u.team == me:
			rec = u
	check("la recluta marcia verso la bandiera", rec != null and rec.has_order and rec.to_flag and Vector2(rec.target.x - fp.x, rec.target.z - fp.z).length() < 7.0)
	sim.cmd_rally(me, 1, fc.center)
	check("clic destro sul castello: bandiera tolta", not bool(fc.flag_on))
	sim.cmd_rally(me, 1, fp)
	sim.cmd_rally_clear(me, 1)
	check("tasto P: bandiera tolta", not bool(fc.flag_on) and sim.state_array()[0][1][10] == null)
	# due castelli: si può raggiungere il pentolone che c'è già, o metterne un altro
	var fc2: Dictionary = g.castles[4]
	var fc2_was: int = fc2.owner
	fc2.owner = me
	sim.cmd_rally(me, 1, fp)
	sim.cmd_rally(me, 4, fp + Vector3(3, 0, 2))
	check("accanto al pentolone di un altro castello: ci si unisce", (fc2.flag as Vector3).is_equal_approx(fc.flag))
	sim.cmd_rally_clear(me, 1)
	check("spento il pentolone di uno, l'altro resta", bool(fc2.flag_on) and not bool(fc.flag_on))
	sim.cmd_rally(me, 4, fp + Vector3(40, 0, 0))
	sim.cmd_rally(me, 1, fp)
	check("altrove: un pentolone a parte", Vector2(fc2.flag.x - fc.flag.x, fc2.flag.z - fc.flag.z).length() > 30.0)
	fc2.flag_on = false
	fc2.owner = fc2_was
	sim.cmd_rally(me, 1, fp)
	var fc_was: int = fc.owner
	sim._capture(fc, 2)
	check("chi conquista non eredita la bandiera", not bool(fc.flag_on))
	fc.owner = fc_was
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
	# castello distrutto: la coda delle reclute va più piano, in proporzione alle mura in piedi
	var rq: Dictionary = g.castles[1]
	rq.queue = [{"type": Defs.FANTE, "t": 2.0}]
	rq.integrity = 0.5
	sim._tick_castle(rq, 1.0)
	check("mura al 50%%: coda a metà velocità (%.2f)" % float(rq.queue[0].t), is_equal_approx(float(rq.queue[0].t), 1.5))
	rq.integrity = 0.05
	rq.queue = [{"type": Defs.FANTE, "t": 2.0}]
	sim._tick_castle(rq, 1.0)
	check("mura quasi rase: mai sotto il %d%%" % int(Sim.RECRUIT_MIN * 100.0), is_equal_approx(float(rq.queue[0].t), 2.0 - Sim.RECRUIT_MIN))
	rq.queue = []
	sim._update_integrity(rq)
	# chi conquista un castello si prende le botteghe che gli stanno attorno
	var shop_c: Dictionary = g.castles[5]
	var shop_far: Dictionary = g.castles[0]
	var shop_was: int = shop_c.owner
	var near_b := {"id": 9901, "type": Defs.B_CASEIFICIO, "owner": shop_was, "x": int(shop_c.center.x) + 50, "z": int(shop_c.center.z), "base": 12, "fx": 1, "fz": 0, "t": 0.0, "T": 1.0, "placed": 0, "fx_t": 0.0, "work": true, "idx": PackedInt32Array()}
	var far_b := near_b.duplicate()
	far_b.id = 9902
	far_b.x = int(shop_far.center.x) + 50
	far_b.z = int(shop_far.center.z)
	sim.buildings.append(near_b)
	sim.buildings.append(far_b)
	sim._capture(shop_c, 2)
	check("la bottega vicino al castello conquistato passa a chi conquista", int(near_b.owner) == 2 and sim.has_building(2, Defs.B_CASEIFICIO))
	check("quella vicino a un altro castello resta dov'è", int(far_b.owner) == shop_was)
	sim.buildings.erase(near_b)
	sim.buildings.erase(far_b)
	shop_c.owner = shop_was
	# signorie minori: Este si comprano, Malatesta voltagabbana, Arborea paga il tributo
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	sim.truce_until = 0.0
	var fe: Dictionary = g.castles[4]
	fe.owner = Defs.NEUTRAL
	sim.houses[1].gold = Defs.LORD_PRICE + 100.0
	sim.cmd_buy(1, 9)
	check("Bari (Comune libero) non si compra", int(g.castles[9].owner) != 1)
	sim.cmd_buy(1, 4)
	check("Ferrara si compra dagli Este", int(fe.owner) == 1 and is_equal_approx(float(sim.houses[1].gold), 100.0))
	fe.owner = Defs.NEUTRAL
	sim.houses[1].gold = 10.0
	sim.cmd_buy(1, 4)
	check("senza fiorini gli Este non vendono", int(fe.owner) == Defs.NEUTRAL)
	var an: Dictionary = g.castles[6]
	an.owner = Defs.NEUTRAL
	for k in 3:
		sim.spawn_unit(Defs.FANTE, Defs.NEUTRAL, an.rally)
	var ag: Vector3 = an.gate_out
	var adir: Vector3 = an.dir
	var aside := Vector3(-adir.z, 0, adir.x)
	for k in Defs.TURNCOAT_MIN - 1:
		sim.spawn_unit(Defs.FANTE, 2, ag + adir * (2.0 + k / 11 * 1.6) + aside * (k % 11 - 5) * 1.6)
	sim._tick_lords(0.5)
	check("Malatesta: %d soldati non bastano" % (Defs.TURNCOAT_MIN - 1), int(an.owner) == Defs.NEUTRAL)
	sim.spawn_unit(Defs.FANTE, 2, ag + adir * 2.0)
	sim._tick_lords(0.5)
	check("Malatesta: con %d cambiano bandiera" % Defs.TURNCOAT_MIN, int(an.owner) == 2)
	an.owner = Defs.NEUTRAL
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var orc: Dictionary = g.castles[13]
	orc.owner = Defs.NEUTRAL
	sim.spawn_unit(Defs.FANTE, 3, (g.castles[11].center as Vector3) + Vector3(30, 0, 0))
	sim.houses[1].gold = 0.0
	sim.houses[3].gold = 0.0
	sim.houses[1].arborea_until = 0.0
	orc.tribute_t = Defs.TRIBUTE_EVERY
	sim._tick_lords(0.5)
	check("Arborea paga chi lascia in pace la Sardegna", is_equal_approx(float(sim.houses[1].gold), Defs.TRIBUTE_GOLD))
	check("e non chi ci va con l'esercito", float(sim.houses[3].gold) == 0.0)
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	# terremoto: i nemici nel cerchio si spaventano per 10 secondi, i tuoi no
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	sim.truce_until = 0.0
	var qp: Vector3 = (g.castles[3].center as Vector3) + Vector3(0, 0, 40)
	qp.y = w.top_y(int(qp.x), int(qp.z))
	var scared := sim.spawn_unit(Defs.FANTE, 3, qp + Vector3(5, 0, 0))
	scared.hp = 99999.0
	var calm := sim.spawn_unit(Defs.FANTE, 1, qp + Vector3(-5, 0, 0))
	calm.hp = 99999.0
	sim._quake_pulse(qp, 1)
	check("terremoto: il nemico ha paura per %d s" % int(Sim.FEAR_T), is_equal_approx(scared.fear, Sim.FEAR_T))
	check("terremoto: i tuoi non hanno paura", calm.fear <= 0.0)
	scared.fear = 3.0
	sim._quake_pulse(qp, 1)
	check("la paura non si allunga a ogni scossa", is_equal_approx(scared.fear, 3.0))
	scared.hp = 0.0
	calm.hp = 0.0
	sim._cleanup_dead()
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
	# chi sta su un'isola non è al sicuro per geografia: pesa di più nella scelta del bersaglio
	check("Palermo conta come isolata", sim._isolation_factor(g.castles[10]) <= 0.55)
	check("Cagliari conta come isolata", sim._isolation_factor(g.castles[11]) <= 0.55)
	check("Napoli non è isolata", sim._isolation_factor(g.castles[8]) == 1.0)
	check("almeno 200 titoli di giornale", News.HEADLINES.size() >= 200)
	var k_shot := InputEventKey.new()
	k_shot.pressed = true
	k_shot.keycode = KEY_4
	k_shot.meta_pressed = true
	k_shot.shift_pressed = true
	var k_meta := InputEventKey.new()
	k_meta.pressed = true
	k_meta.keycode = KEY_META
	var k_space := InputEventKey.new()
	k_space.pressed = true
	k_space.keycode = KEY_SPACE
	check("lo screenshot non salta la scena del re", not CTRL_SCRIPT.skips_cinematic(k_shot) and not CTRL_SCRIPT.skips_cinematic(k_meta))
	check("un tasto normale salta la scena del re", CTRL_SCRIPT.skips_cinematic(k_space))
	var deaths_ok := Defs.KING_DEATHS.size() == 10
	for v in range(1, Defs.KING_DEATHS.size()):
		deaths_ok = deaths_ok and UnitModels.new().re_scena(Color.RED, v).get_surface_count() > 0
	check("ogni uscita di scena del re ha il suo modello", deaths_ok)
	# debug: ogni evento parte a comando, anche a campo vuoto
	var dbg_ok := true
	for e in Defs.EVENTS.size():
		for u: Sim.U in sim.ulist.duplicate():
			u.hp = 0.0
		sim._cleanup_dead()
		dbg_ok = dbg_ok and sim.debug_event(e, 4)
		sim.palio_until = 0.0
		sim.news_t = 0.0
	check("debug: tutti gli eventi partono a comando", dbg_ok)
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	# caratteri delle casate: stesso totale per tutte, e con «casate uguali» non contano
	var same_total := true
	for k in Defs.HOUSE_COUNT:
		var tot := 0
		for v: int in Defs.HOUSES[k].stats:
			tot += v
		same_total = same_total and tot == Defs.STAT_TOTAL
	check("stesso totale di cubetti per ogni casata", same_total)
	check("la Serenissima guadagna di più del Papato", sim._stat(2, Defs.STAT_SOLDI) > sim._stat(5, Defs.STAT_SOLDI))
	sim.equal_houses = true
	check("casate uguali: nessun bonus", sim._stat(2, Defs.STAT_SOLDI) == 1.0 and sim._stat(7, Defs.STAT_FORZA) == 1.0)
	sim.equal_houses = false
	# il potere di ogni casata fa davvero quello che promette
	var sp_at: Vector3 = (g.castles[5].gate_out as Vector3) + (g.castles[5].dir as Vector3) * 40.0
	for k in Defs.HOUSE_COUNT:
		for u: Sim.U in sim.ulist.duplicate():
			u.hp = 0.0
		sim._cleanup_dead()
		var other := (k + 1) % Defs.HOUSE_COUNT
		sim.houses[k].alive = true
		sim.houses[other].gold = 500.0
		sim.houses[k].gold = 0.0
		if sim._nearest_castle_of(k, sp_at).is_empty():
			g.castles[k].owner = k
		var fired := sim.debug_special(k, sp_at)
		var victim_u: Sim.U = null
		var my_u: Sim.U = null
		var mine_n := 0
		for u: Sim.U in sim.ulist:
			if u.team == other and victim_u == null:
				victim_u = u
			if u.team == k:
				mine_n += 1
				if my_u == null:
					my_u = u
		var ok := fired
		match k:
			0: ok = ok and victim_u.sleep > 0.0
			1: ok = ok and victim_u.feast > 0.0 and float(sim.houses[k].gold) > 0.0
			2: ok = ok and float(sim.houses[k].gold) > 0.0
			3: ok = ok and float(sim.houses[k].discount_until) > sim.time
			4: ok = ok and mine_n == 8
			5: ok = ok and float(sim.houses[other].get("excom_until", 0.0)) > sim.time
			6: ok = ok and my_u.drunk > 0.0
			7: ok = ok and mine_n == 9
			8: ok = ok and victim_u.flee > 0.0
		check("potere di %s" % Defs.HOUSES[k].name, ok)
		check("il potere di %s ha la sua attesa" % Defs.HOUSES[k].name, not sim.cmd_special(k, sp_at))
	sim.equal_houses = true
	sim.houses[2].sp_t = 0.0
	check("casate uguali: niente poteri", not sim.cmd_special(2, sp_at))
	sim.equal_houses = false
	# apericena sul castello con il re all'80%: chi lo difende non va allo spritz
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	var dc: Dictionary = g.castles[5]
	var down_owner := int(dc.owner)
	dc.owner = 2
	var guards: Array = []
	for k in 6:
		guards.append(sim.spawn_unit(Defs.FANTE, 2, (dc.rally as Vector3) + Vector3(k % 3 - 1, 0, k / 3) * 1.5))
	var passer := sim.spawn_unit(Defs.FANTE, 3, (dc.rally as Vector3) + Vector3(0, 0, 3))
	dc.king_hp = Sim.KING_HP * 0.2
	dc.king_calm = Sim.KING_CALM
	sim.houses[1].sp_t = 0.0
	sim.cmd_special(1, dc.rally)
	check("apericena: chi difende il re in pericolo non molla il posto", guards.all(func(u: Sim.U) -> bool: return u.feast <= 0.0))
	check("apericena: gli altri allo spritz ci vanno", passer.feast > 0.0)
	# lanciata prima che il re sia colpito: alla prima botta al re tornano tutti
	dc.king_hp = Sim.KING_HP
	dc.king_calm = 0.0
	sim.houses[1].sp_t = 0.0
	sim.cmd_special(1, dc.rally)
	var feasting := guards.filter(func(u: Sim.U) -> bool: return u.feast > 0.0).size()
	sim._hurt_king(dc, 10.0, 1)
	check("apericena: alla prima botta al re i difensori tornano (%d a tavola)" % feasting, feasting > 0 and guards.all(func(u: Sim.U) -> bool: return u.feast <= 0.0))
	dc.owner = down_owner
	dc.king_hp = Sim.KING_HP
	for u: Sim.U in sim.ulist.duplicate():
		u.hp = 0.0
	sim._cleanup_dead()
	# balestrieri sulle mura: con un ordine scendono e arrivano giù vivi e interi
	var gc: Dictionary = g.castles[13]
	gc.owner = 3
	var ai_was := sim.ai_enabled
	sim.ai_enabled = false
	var archer := sim.spawn_unit(Defs.BALESTRIERE, 3, gc.center)
	sim.cmd_garrison(3, gc.id)
	var up_y := archer.pos.y
	check("mura: il balestriere sale sulle mura", archer.garrison and up_y > float(gc.center.y) + 8.0)
	sim.cmd_order(3, PackedInt32Array([archer.id]), (gc.gate_out as Vector3) + (gc.dir as Vector3) * 25.0, false)
	for k in int(Defs.SIM_HZ * 12):
		sim.tick(1.0 / Defs.SIM_HZ)
	var full := float(Defs.UNITS[Defs.BALESTRIERE].hp)
	check("mura: scende dalle mura senza farsi male (vita %.0f/%.0f, quota %.0f → %.0f)" % [archer.hp, full, up_y, archer.pos.y], archer.hp >= full and archer.pos.y < up_y - 8.0)
	# una caduta vera (senza ordine di scendere) fa ancora male
	var faller := sim.spawn_unit(Defs.FANTE, 3, archer.pos)
	faller.pos.y = archer.pos.y + 14.0  # spawn_unit lo posa a terra: lo rimettiamo in aria
	for k in int(Defs.SIM_HZ * 2):
		sim._apply_fall(faller, archer.pos.y, 1.0 / Defs.SIM_HZ)
	check("mura: chi cade da 14 blocchi si fa male (vita %.0f)" % faller.hp, faller.hp < float(Defs.UNITS[Defs.FANTE].hp))
	faller.hp = 0.0
	archer.hp = 0.0
	sim._cleanup_dead()
	sim.ai_enabled = ai_was
	# modalità A tempo: allo scadere vince chi ha più castelli
	for cs: Dictionary in g.castles:
		cs.owner = cs.start_house
	g.castles[4].owner = 6
	g.castles[9].owner = 6
	sim.mode = Defs.MODE_TEMPO
	sim.time = Defs.TIME_LIMIT - 1.0
	sim._tick_mode(0.5)
	check("A tempo: prima dello scadere nessuno vince", sim.winner < 0)
	sim.time = Defs.TIME_LIMIT + 1.0
	sim._tick_mode(0.5)
	check("A tempo: vince chi ha più castelli (%d)" % sim.winner, sim.winner == 6)
	check("lo stato porta la modalità ai client", int((sim.state_array()[5] as Dictionary).mode) == Defs.MODE_TEMPO)
	sim.winner = -1
	# Palio: il Drappo si posa su un castello, chi lo tiene fa punti, poi si sposta lontano
	sim.mode = Defs.MODE_PALIO
	sim.drappo = -1
	sim.time = 1000.0
	sim.truce_until = 0.0
	sim._tick_mode(0.5)
	var d0: int = sim.drappo
	check("Palio: il Drappo c'è (%s)" % (g.castles[d0].name if d0 >= 0 else "-"), d0 >= 0)
	g.castles[d0].owner = 2
	for k in 20:
		sim._tick_mode(0.5)
	check("Palio: chi tiene il Drappo fa punti (%d)" % int(sim.drappo_pts[2]), int(sim.drappo_pts[2]) == 10)
	sim.time = sim.drappo_move_t + 0.1
	sim._tick_mode(0.5)
	var d1: int = sim.drappo
	check("Palio: dopo 4 minuti si sposta lontano (%s → %s)" % [g.castles[d0].name, g.castles[d1].name], d1 != d0 and (g.castles[d0].center as Vector3).distance_to(g.castles[d1].center) > 250.0)
	g.castles[d1].owner = 2
	sim.drappo_pts[2] = Defs.DRAPPO_GOAL - 0.2
	sim._tick_mode(0.5)
	check("Palio: a %d punti si vince" % int(Defs.DRAPPO_GOAL), sim.winner == 2)
	sim.winner = -1
	sim.mode = Defs.MODE_CONQUISTA
	# vittoria: tutti i castelli alla stessa casata
	for cs: Dictionary in g.castles:
		cs.owner = 1
	sim._check_winner()
	check("tutti i castelli = vittoria", sim.winner == 1)
	print("FALLITI: ", fails)
	quit(fails)
