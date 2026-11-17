extends SceneTree
## Comandi alla StarCraft, senza finestra: gruppi, Backspace sui castelli, poteri su Z X C V B e F,
## doppio clic sullo stesso tipo, squadre disegnate.
##   godot --headless --path . -s tests/controls.gd

var fails := 0
var c: Controller


func _init() -> void:
	_run.call_deferred()


func check(name_: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", name_])
	if not ok:
		fails += 1


func key(k: Key, ctrl := false, shift := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	e.pressed = true
	c._unhandled_input(e)
	await process_frame


func wait_s(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	Game.force_view = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# il menu prepara l'Italia: si parte appena è pronta
	for k in 600:
		if main.menu.revealed:
			break
		await wait_s(0.1)
	main.menu.play_solo.emit(4, "")
	for k in 600:
		if main.game != null and main.game.ctrl != null and not main.game.state.is_empty():
			break
		await wait_s(0.1)
	await wait_s(1.0)
	var g: Game = main.game
	var sim: Sim = g.sim
	c = g.ctrl
	c.end_cinematic()
	var ce: Vector3 = g.castles[5].gate_out
	for k in 9:
		sim.spawn_unit([Defs.FANTE, Defs.BALESTRIERE, Defs.CAVALIERE][k % 3], 4, ce + Vector3(k % 3 * 2.2, 0, k / 3 * 2.2 + 4))
	await wait_s(0.5)
	var sel: Dictionary = g.renderer.selected
	await key(KEY_T)
	var army_n := sel.size()
	check("T seleziona l'armata (%d)" % army_n, army_n >= 9)
	await key(KEY_1, true)
	await key(KEY_ESCAPE)
	check("Esc svuota la selezione", sel.is_empty())
	await wait_s(0.5)
	await key(KEY_1)
	check("1 riprende il gruppo", sel.size() == army_n)
	c.focus = Vector3(100, 20, 100)
	await key(KEY_1)
	check("1 due volte porta la vista sul gruppo", c.focus.distance_to(Vector3(100, 20, 100)) > 50.0)
	sel.clear()
	await key(KEY_F2)
	check("F2 seleziona l'armata", sel.size() == army_n)
	# un castello in un gruppo
	sel.clear()
	c.selected_castle = 5
	await key(KEY_2, true)
	c.selected_castle = -1
	await wait_s(0.5)
	await key(KEY_2)
	check("2 riprende il castello del gruppo", c.selected_castle == 5)
	# Backspace: da un castello mio all'altro
	sim.castles[6].owner = 4
	await wait_s(0.5)
	print("castelli: 5 → %d, 6 → %d, scelto %d" % [g.castle_owner(5), g.castle_owner(6), c.selected_castle])
	await key(KEY_BACKSPACE)
	var fc: Vector3 = g.castles[6].center
	check("Backspace passa al castello dopo (%d)" % c.selected_castle, c.selected_castle == 6 and Vector2(c.focus.x - fc.x, c.focus.z - fc.z).length() < 1.0)
	await key(KEY_BACKSPACE)
	check("Backspace ricomincia dal primo (%d)" % c.selected_castle, c.selected_castle == 5)
	await key(KEY_BACKSPACE, false, true)
	check("Maiusc+Backspace torna indietro (%d)" % c.selected_castle, c.selected_castle == 6)
	# poteri
	sim.houses[4].faith = 150.0
	sim.houses[4].all_shops = true
	await wait_s(0.5)
	for k in Controller.POWER_KEYS.size():
		c.pending = {}
		await key(Controller.POWER_KEYS[k])
		check("%s arma %s" % [Controller.POWER_KEY_NAMES[k], Defs.POWERS[k].short], c.pending.get("kind", "") == "power" and int(c.pending.get("id", -1)) == k)
	c.pending = {}
	await key(KEY_F)
	check("F arma il potere della casata", c.pending.get("kind", "") == "special")
	# squadre: tre fanti a vita piena per ogni fante
	var fanti := 0
	for vu: Game.VU in g.vunits.values():
		if vu.type == Defs.FANTE:
			fanti += 1
	c.focus = ce
	c.target_dist = 60.0
	c.dist = 60.0
	await wait_s(0.3)
	var drawn: int = g.renderer.counts[Defs.FANTE]
	check("i fanti si vedono in squadra (%d figure per %d fanti)" % [drawn, fanti], drawn > fanti and drawn <= (fanti + 3) * 3)  # qualcuno può morire fra i due conteggi
	# pannello del castello con la difesa: sta nello schermo e la difesa non è più larga delle truppe
	sel.clear()
	c.selected_castle = 5
	await wait_s(0.5)
	var hud: Hud = g.hud
	var pr: Rect2 = hud.castle_panel.get_global_rect()
	var dr: Rect2 = hud.def_box.get_global_rect()
	var rr: Rect2 = hud.recruit_box.get_global_rect()
	print("pannello %s, difesa %s, truppe %s, schermo %s" % [pr, dr, rr, root.get_visible_rect().size])
	check("il pannello del castello sta nello schermo", pr.position.y >= 0.0 and pr.end.y <= root.get_visible_rect().size.y + 1.0)
	check("la difesa sta dentro il pannello", dr.end.x <= pr.end.x + 0.5 and dr.size.x <= rr.size.x + 1.0)
	for k: String in hud.def_btns:
		var b: Button = hud.def_btns[k]
		var n: Label = hud.def_subs[k]
		check("la riga di %s sta nel pulsante" % k, n.get_global_rect().end.x <= b.get_global_rect().end.x + 1.0)
	print("FINE: %d errori" % fails)
	quit(1 if fails > 0 else 0)
