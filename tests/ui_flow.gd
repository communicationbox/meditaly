extends SceneTree
## Test end-to-end con input sintetici: menu -> partita -> selezione, ordine, recluta, potere.
##   godot --path . -s tests/ui_flow.gd -- OUTDIR

var out := ""
var fails := 0


func _init() -> void:
	_run.call_deferred()


## Aspetta che lo stato con le botteghe sbloccate arrivi davvero all'interfaccia.
func wait_shops(g: Game) -> void:
	for k in 600:
		if g.has_shop(Defs.POWER_BUILDING[Defs.P_PARMIGIANO]) and g.has_shop(Defs.POWER_BUILDING[Defs.P_SCUDO]):
			return
		await process_frame


func check(name_: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", name_])
	if not ok:
		fails += 1


func wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func wait_s(s: float) -> void:
	await create_timer(s).timeout


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	root.warp_mouse(p)
	await wait_frames(2)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.position = p
		e.global_position = p
		e.pressed = pressed
		e.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		Input.parse_input_event(e)
		await wait_frames(2)


func drag_power(a: Vector2, b: Vector2) -> void:
	for step: Array in [[a, true, false], [b, false, true]]:
		root.warp_mouse(step[0])
		var m := InputEventMouseMotion.new()
		m.position = step[0]
		m.global_position = step[0]
		Input.parse_input_event(m)
		await wait_frames(3)
		if step[1]:
			var d := InputEventMouseButton.new()
			d.button_index = MOUSE_BUTTON_LEFT
			d.position = step[0]
			d.global_position = step[0]
			d.pressed = true
			d.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(d)
			await wait_frames(3)
	await wait_frames(3)
	await shot("ui_mira_trascina")
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.position = b
	u.global_position = b
	u.pressed = false
	Input.parse_input_event(u)
	await wait_frames(3)


func key(k: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_frames(2)


func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await wait_frames(5)
	check("all'avvio c'è la schermata di caricamento", not main.menu.revealed)
	var t0 := Time.get_ticks_msec()
	while not main.menu.revealed and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await wait_s(1.0)  # dissolvenza della schermata di caricamento
	check("il menu compare quando l'Italia è pronta (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0), main.menu.revealed)
	check("menu visibile", main.menu != null)
	await shot("ui_menu")
	var solo: Button = null
	for n: Node in main.menu.find_children("*", "Button", true, false):
		if (n as Button).text.contains("contro l'IA"):
			solo = n
	check("pulsante solitario presente", solo != null)
	# la casata si sceglie cliccando la città sulla mappa
	var firenze: Dictionary = Defs.CASTLES[5]
	await click((main.menu.shield_btns[4] as Control).get_global_rect().get_center())
	check("clic su Firenze sceglie i Medici", main.menu.house == 4)
	main.menu.name_edit.text = ""
	await click(solo.get_global_rect().get_center())
	check("senza nome non si parte", not main.menu._starting)
	main.menu.name_edit.text = "Prova"
	await click(solo.get_global_rect().get_center())
	check("dopo il clic compare la rotella", main.menu._starting)
	Settings.player_name = ""  # il nome di prova non deve restare nelle impostazioni di chi gioca
	Settings.save_all()
	while main.game == null:
		await process_frame
	await wait_s(1.0)
	var g: Game = main.game
	check("clic sul menu avvia la partita", g != null and g.welcome_done)
	check("casata scelta dal menu = Medici", g.my_house == 4)
	await wait_s(1.0)
	var c: Controller = g.ctrl
	check("castello di partenza selezionato", c.selected_castle == 5)
	if c.selected_castle != 5:
		print("     selezionato=%d casa=%d unità selezionate=%d trascina=%s" % [c.selected_castle, c.home_castle, g.renderer.selected.size(), c.dragging])
	check("il castello di partenza è indicato", c.home_castle == 5 and g.hud.rings[5].visible and g.hud.labels[5].text.contains("IL TUO CASTELLO"))
	check("gli altri castelli non hanno il segno", not g.hud.rings[4].visible and not g.hud.labels[4].text.contains("IL TUO"))
	var sim: Sim = g.sim
	var hud: Hud = g.hud
	# recluta con il pulsante dell'interfaccia
	var gold0: int = int(sim.houses[4].gold)
	await click(hud.recruit_btns[Defs.FANTE].get_global_rect().get_center())
	await wait_frames(2)
	check("pulsante Fante scala i fiorini", int(sim.houses[4].gold) <= gold0 - 15)
	check("Fante in coda", (sim.castles[5].queue as Array).size() == 1)
	await click(hud.recruit_btns[Defs.CATAPULTA].get_global_rect().get_center())
	await wait_s(4.0)
	# selezione a riquadro su tutto lo schermo centrale
	var sel: Dictionary = g.renderer.selected
	c.target_dist = 70.0
	await wait_s(0.6)
	var a := Vector2(150, 100)
	var b := Vector2(1450, 600)
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.position = a; dn.global_position = a; dn.pressed = true
	Input.parse_input_event(dn)
	await wait_frames(2)
	var mv := InputEventMouseMotion.new()
	mv.position = b; mv.global_position = b; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mv)
	await wait_frames(2)
	await shot("ui_riquadro")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = b; up.global_position = b; up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(3)
	check("riquadro seleziona proprie truppe (%d)" % sel.size(), sel.size() > 0)
	var all_mine := true
	for id: int in sel:
		if (g.vunits[id] as Game.VU).team != 4:
			all_mine = false
	check("solo truppe della propria casata", all_mine)
	# ordine col destro sul terreno: deve arrivare alla simulazione
	var id0: int = sel.keys()[0]
	# un punto di terreno fuori dalla porta (il castello ingrandito copre molto schermo)
	var hc: Dictionary = g.castles[5]
	# un punto di terreno inquadrato e fuori dalle mura: il castello ingrandito copre molto schermo
	var sp := Vector2(-1, -1)
	for ring in [Sim.R + 14.0, Sim.R + 30.0, Sim.R + 50.0]:
		for k in 24:
			var ang := k * TAU / 24.0
			var cand: Vector3 = (hc.center as Vector3) + Vector3(cos(ang), 0, sin(ang)) * ring
			cand.y = g.world.top_y(int(cand.x), int(cand.z))
			var q := c.cam.unproject_position(cand)
			if q.x < 420 or q.x > 1350 or q.y < 120 or q.y > 760 or c.cam.is_position_behind(cand):
				continue
			var hit: Dictionary = g.world.raycast(c.cam.project_ray_origin(q), c.cam.project_ray_normal(q))
			if hit.get("hit", false) and not hit.get("water", false):
				var vx: Vector3i = hit.voxel
				if g.world.get_v(vx.x, vx.y, vx.z) < Defs.STRUCT_MIN and g.castle_at(hit.point, 1.0) < 0:
					sp = q
					break
		if sp.x >= 0:
			break
	check("c'è terreno libero inquadrato", sp.x >= 0)
	await click(sp, MOUSE_BUTTON_RIGHT)
	await wait_frames(3)
	var u0: Sim.U = sim.by_id.get(id0)
	check("clic destro dà un ordine", u0 != null and u0.has_order)
	var p0: Vector3 = u0.pos
	await wait_s(2.0)
	check("l'unità si muove (%.1f)" % u0.pos.distance_to(p0), u0.pos.distance_to(p0) > 2.0)
	# tasto T: tutta l'armata
	await key(KEY_T)
	var mine := 0
	for u: Sim.U in sim.ulist:
		if u.team == 4:
			mine += 1
	check("T seleziona tutta l'armata", absi(sel.size() - mine) <= 1)
	# potere: tasto + clic sinistro
	sim.houses[4].faith = 150.0
	sim.houses[4].all_shops = true
	await wait_shops(hud.game)  # lo sblocco arriva all'interfaccia con lo stato successivo
	await key(KEY_1)
	check("tasto 1 arma il potere", c.pending.get("kind", "") == "power" and c.pending.get("id", -1) == Defs.P_PARMIGIANO)
	await wait_frames(3)
	await shot("ui_mira")
	await click(Vector2(800, 300))
	check("clic lancia il Parmigiano", sim.wheels.size() == 1 and c.pending.is_empty())
	# tenendo premuto e trascinando si sceglie direzione e potenza
	sim.wheels.clear()
	sim.houses[4].cd[Defs.P_PARMIGIANO] = 0.0
	sim.houses[4].faith = 150.0
	await key(KEY_1)
	await drag_power(Vector2(700, 380), Vector2(1000, 380))
	check("trascinando parte la forma col vettore scelto", sim.wheels.size() == 1 and c.pending.is_empty() and absf((sim.wheels[0].vel as Vector3).length() - 34.0) > 0.5)
	await wait_s(0.2)
	await wait_s(1.0)
	await shot("ui_forma")
	# pulsante potere dall'interfaccia, annullo col destro
	sim.houses[4].faith = 150.0
	sim.houses[4].all_shops = true
	await wait_shops(hud.game)
	await click(hud.power_btns[Defs.P_SCUDO].get_global_rect().get_center())
	check("pulsante potere arma la mira", c.pending.get("id", -1) == Defs.P_SCUDO)
	await click(Vector2(800, 300), MOUSE_BUTTON_RIGHT)
	check("clic destro annulla la mira", c.pending.is_empty())
	await key(KEY_MINUS)
	await wait_frames(3)
	check("il tasto - apre il debug", hud.debug_panel != null and hud.debug_panel.visible)
	await shot("ui_debug")
	await key(KEY_MINUS)
	# evento: dopo il titolo resta un'icona che porta sul posto, e sparisce quando finisce
	check("l'evento parte", sim._run_event(3))
	await wait_frames(3)
	check("arriva il giornale e il gioco si ferma", is_instance_valid(hud.paper_layer) and sim.news_t > 0.0)
	await wait_s(0.8)
	await shot("ui_giornale")
	hud._resume_paper()
	await wait_frames(3)
	check("girata la pagina si riprende", sim.news_t <= 0.0 and not is_instance_valid(hud.paper_layer))
	check("l'evento lascia un'icona", hud.event_icons.size() == 1)
	await shot("ui_evento")
	c.focus = Vector3(100, 20, 100)
	await click((hud.event_icons[0].btn as Button).get_global_rect().get_center())
	check("l'icona porta sull'evento", c.focus.distance_to(sim.castles[7].center) < 2.0)
	hud.event_icons[0].t = 0.05
	await wait_s(0.3)
	check("finito l'evento l'icona sparisce", hud.event_icons.is_empty())
	# difese da tastiera sul castello
	await key(KEY_SPACE)
	c.selected_castle = 5
	await key(KEY_R)
	await wait_frames(2)
	check("R attiva la riparazione", sim.castles[5].repair == true)
	await key(KEY_F1)
	check("F1 apre la guida", hud.help.visible)
	await wait_frames(2)
	await shot("ui_guida")
	var esci: Button = hud.help.find_children("*", "Button", true, false)[0]
	await click(esci.get_global_rect().get_center())
	await wait_frames(4)
	check("Esci torna al menu", main.menu != null and is_instance_valid(main.menu))
	print("FALLITI: ", fails)
	quit(fails)
