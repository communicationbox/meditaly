extends SceneTree
## Storia, senza finestra: l'interfaccia cresce missione per missione e i comandi non sbloccati
## non passano.
##   godot --headless --path . -s tests/campaign.gd

var fails := 0
const H := Campaign.HERO_HOUSE
const HC := Campaign.HOME_CASTLE


func _init() -> void:
	_run.call_deferred()


func check(name_: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", name_])
	if not ok:
		fails += 1


func wait_s(s: float) -> void:
	await create_timer(s).timeout


func key(c: Controller, k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	c._unhandled_input(e)
	await process_frame


func _run() -> void:
	Game.force_view = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for k in 600:
		if main.menu != null and main.menu.revealed:
			break
		await wait_s(0.1)
	# il pulsante Storia apre l'elenco: la prima missione si gioca, le altre sono chiuse finché non vinci
	var saved0 := Settings.story_done
	Settings.story_done = 0
	main.menu._open_story()
	await wait_s(0.2)
	var b1: Button = main.menu.story_panel.find_child("Missione 1", true, false)
	var b2: Button = main.menu.story_panel.find_child("Missione 2", true, false)
	check("l'elenco ha la missione 1 aperta e la 2 chiusa", b1 != null and not b1.disabled and b2 != null and b2.disabled)
	main.menu.story_panel.queue_free()
	Settings.story_done = saved0
	main._start_game().start_solo(H, "", PackedStringArray(["--missione", "1"]))
	var g: Game = main.game
	for k in 600:
		if g.ctrl != null and not g.state.is_empty():
			break
		await wait_s(0.1)
	await wait_s(1.0)
	var sim: Sim = g.sim
	var hud: Hud = g.hud
	var c: Controller = g.ctrl
	c.end_cinematic()
	var ms: Mission = g.mission
	check("la missione 1 parte", ms != null and ms.n == 1)
	check("si apre col giornale e il gioco è fermo", is_instance_valid(hud.paper_layer) and sim.paused)
	check("il giornale ha il titolone della missione", _paper_has(hud, "Conte senza terre"))
	check("il castello del Conte si chiama Borgo Spigolo", String(g.castles[HC].name) == "Borgo Spigolo" and g.castle_owner(HC) == H)
	check("il Conte ha il suo nome", String(sim.houses[H].pname) == "Conte di Borgo Spigolo")
	check("nella storia non c'è tregua", g.state[3] == 0)
	_press(hud, "Si comincia")
	await wait_s(0.5)
	check("voltata pagina si gioca", not sim.paused and ms.running and not is_instance_valid(hud.paper_layer))
	check("in missione 1 partono i suggerimenti", is_instance_valid(ms.hints))
	check("l'obiettivo è scritto in alto (%s)" % ms.goal_lbl.text, ms.goal_lbl.text.contains("Ferrara"))
	sim.equal_houses = false  # con «casate tutte uguali» il potere della casata non c'è proprio
	sim.houses[H].gold = 5000.0
	sim.houses[H].faith = 150.0
	sim.houses[H].all_shops = true
	c.selected_castle = HC
	await wait_s(0.5)

	# missione 1: solo fanti, niente difesa, poteri, Fede, costruzioni, sfottò
	check("missione 1: si vede solo il Fante", _visible_units(hud) == [Defs.FANTE])
	check("missione 1: niente difesa", not hud.def_box.visible)
	check("missione 1: niente scheda Costruzioni", not hud.tab_bar.visible)
	check("missione 1: niente barra dei poteri", not hud.power_board.visible)
	check("missione 1: niente Fede in alto", not hud.faith_pair.visible)
	check("missione 1: niente sfottò", not hud.taunt_row.visible)
	check("missione 1: niente eventi", not sim.events_enabled)
	var q0 := (sim.castles[HC].queue as Array).size()
	g.send_cmd("recruit", [HC, Defs.BALESTRIERE])
	g.send_cmd("recruit", [HC, Defs.FANTE])
	await wait_s(0.2)
	check("missione 1: il balestriere non si recluta, il fante sì", (sim.castles[HC].queue as Array).size() == q0 + 1)
	await key(c, KEY_Z)
	check("missione 1: Z non arma il Parmigiano", c.pending.is_empty())
	await key(c, KEY_R)
	await wait_s(0.2)
	check("missione 1: R non ripara", not sim.castles[HC].repair)
	await key(c, KEY_T)
	var sel_n: int = g.renderer.selected.size()
	await key(c, KEY_1)
	check("missione 1: i gruppi non ci sono ancora (1 non tocca la selezione)", g.renderer.selected.size() == sel_n)
	c.selected_castle = HC
	g.renderer.selected.clear()

	# missione 3: balestrieri e Sulle mura, ancora niente mangano
	sim.set_story_locks(3)
	await wait_s(0.3)
	check("missione 3: Fante e Balestriere", _visible_units(hud) == [Defs.FANTE, Defs.BALESTRIERE])
	check("missione 3: Ripara e Sulle mura, senza Mangano e Olio", hud.def_box.visible and hud.def_btns["repair"].visible and hud.def_btns["garrison"].visible and not hud.def_btns["mangano"].visible and not hud.def_btns["oil"].visible)

	# missione 7: gruppi, mangano, olio
	sim.set_story_locks(7)
	await wait_s(0.3)
	check("missione 7: tutte e quattro le difese", hud.def_btns.values().all(func(b: Button): return b.visible))
	check("missione 7: ancora niente Costruzioni", not hud.tab_bar.visible)
	await key(c, KEY_BACKSPACE)
	check("missione 7: Backspace funziona", c.selected_castle >= 0)

	# missione 8: chiesa, frati, Fede
	sim.set_story_locks(8)
	await wait_s(0.3)
	check("missione 8: scheda Costruzioni con la sola Chiesa", hud.tab_bar.visible and _visible_builds(hud) == [Defs.B_CHIESA])
	check("missione 8: Fede in alto", hud.faith_pair.visible)
	check("missione 8: ancora niente poteri", not hud.power_board.visible)

	# missione 9: caseificio e Parmigiano
	sim.set_story_locks(9)
	await wait_s(0.3)
	check("missione 9: barra con il solo Parmigiano", hud.power_board.visible and hud.power_btns[Defs.P_PARMIGIANO].visible and not hud.power_btns[Defs.P_MUCCHE].visible)
	await key(c, KEY_B)
	check("missione 9: B non arma le mucche", c.pending.is_empty())
	await key(c, KEY_Z)
	check("missione 9: Z arma il Parmigiano", c.pending.get("kind", "") == "power")
	c.pending = {}

	# missione 11: nonna, menestrello, potere della casata, eventi, sfottò
	sim.set_story_locks(11)
	await wait_s(0.3)
	check("missione 11: tutti i soldati", _visible_units(hud).size() == Defs.UNIT_TYPES)
	check("missione 11: potere della casata (attesa %s)" % str(g.state[1][4][-2]), hud.special_btn.visible)
	check("missione 11: sfottò", hud.taunt_row.visible)
	check("missione 11: eventi accesi", sim.events_enabled)

	# missione 12: tutto, come la partita libera
	sim.set_story_locks(12)
	await wait_s(0.3)
	check("missione 12: niente blocchi", sim.locks.is_empty() and g.allowed("power", Defs.P_MUCCHE))
	# ogni missione: si prepara, si vince forzando l'obiettivo, si salvano i progressi
	var saved := Settings.story_done
	for k in range(1, Campaign.MISSIONS.size() + 1):
		if is_instance_valid(g.mission):
			if is_instance_valid(g.mission.hints):
				g.mission.hints._finish()
			g.mission.queue_free()
		hud.close_paper()
		var mk := Mission.new()
		g.add_child(mk)
		g.mission = mk
		mk.setup(g, k)
		await wait_s(0.1)
		mk._start()
		await wait_s(0.3)
		check("missione %d: il Conte ha Borgo Spigolo (%s)" % [k, mk.goal_text()], g.castles[HC].owner == H and not mk.won() and not mk.lost())
		_force_win(mk, sim)
		await wait_s(1.2)
		check("missione %d: vinta" % k, mk.ended and Settings.story_done >= k)
		var next := "Al banchetto!" if k == Campaign.MISSIONS.size() else "Missione successiva"
		check("missione %d: giornale finale con «%s»" % [k, next], is_instance_valid(hud.paper_layer) and hud.paper_layer.find_child(next, true, false) != null)
	Settings.story_done = saved
	Settings.save_all()
	print("FINE: %d errori" % fails)
	quit(1 if fails > 0 else 0)


func _visible_units(hud: Hud) -> Array:
	var out := []
	for t in hud.recruit_btns.size():
		if hud.recruit_btns[t].visible:
			out.append(t)
	return out


func _visible_builds(hud: Hud) -> Array:
	var out := []
	for k in hud.build_btns.size():
		if hud.build_btns[k].visible:
			out.append(k)
	return out


func _force_win(mk: Mission, sim: Sim) -> void:
	var gl: Dictionary = mk.m.goal
	match String(gl.kind):
		"capture":
			for cid: int in gl.castles:
				sim.castles[cid].owner = H
		"survive", "hold":
			mk.start_time -= float(gl.secs) + 1.0
			for cid: int in gl.get("castles", []):
				sim.castles[cid].owner = H
		"faith":
			sim.houses[H].faith = float(gl.amount) + 1.0
		"waves":
			mk.waves_sent = int(mk.m.setup.attack.times)
			mk.next_wave = 1e9
			for u: Sim.U in mk.wave_units:
				u.hp = 0.0


func _paper_has(hud: Hud, txt: String) -> bool:
	if not is_instance_valid(hud.paper_layer):
		return false
	for l: Label in hud.paper_layer.find_children("*", "Label", true, false):
		if l.text.contains(txt.substr(1)):
			return true
	return false


func _press(hud: Hud, name_: String) -> void:
	var b: Button = hud.paper_layer.find_child(name_, true, false)
	if b != null:
		b.pressed.emit()
