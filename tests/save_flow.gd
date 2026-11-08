extends SceneTree
## Salva e riprende una partita dal gioco vero: pausa (Esc) -> Salva -> menu -> Continua.
## Il mondo ricaricato deve essere identico byte per byte; unità e botteghe tornano.
##   godot --path . -s tests/save_flow.gd -- OUTDIR

var fails := 0


func _init() -> void:
	_run.call_deferred()


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func key(k: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	SaveGame.PATH = "user://prova_flusso.sav"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.menu.play_solo.emit(2, "Prova")
	await create_timer(3.0).timeout
	var g: Game = main.game
	var sim: Sim = g.sim
	var ve: Dictionary = g.castles[2]
	var spot := sim.find_spot(2, ve)
	sim.build_now(2, Defs.B_CHIESA, spot)
	sim.houses[2].gold = 777.0
	await create_timer(1.0).timeout
	var hash_before := g.world.hash_world()
	var units_before := sim.ulist.size()
	var t_before := sim.time
	g.ctrl.selected_castle = -1  # Esc prima toglie la selezione, poi apre la pausa
	await key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	check("Esc apre la pausa", g.hud.pause_panel != null and g.hud.pause_panel.visible)
	check("in pausa la partita si ferma", sim.paused)
	await shot(out, "sv_pausa")
	var t_paused := sim.time
	await create_timer(0.5).timeout
	check("in pausa il tempo non scorre", is_equal_approx(sim.time, t_paused))
	g.hud._open_settings()
	await create_timer(0.3).timeout
	await shot(out, "sv_impostazioni")
	g.hud._settings_panel.queue_free()
	units_before = sim.ulist.size()  # in pausa: è esattamente ciò che finisce nel file
	hash_before = g.world.hash_world()
	g.hud._save_game()
	check("salvataggio scritto", SaveGame.exists())
	main.back_to_menu()
	await create_timer(0.8).timeout
	await shot(out, "sv_menu")
	main.menu.continue_game.emit()
	var g2: Game = main.game
	var units_loaded: int = g2.sim.ulist.size() if g2 != null and g2.sim != null else -1
	var hash_loaded: int = g2.world.hash_world() if g2 != null else 0
	await create_timer(3.0).timeout
	check("partita ripresa", g2 != null and g2.sim != null)
	if g2 != null and g2.sim != null:
		check("stessa casata", g2.my_house == 2)
		check("mondo identico byte per byte", hash_loaded == hash_before)
		check("stesse unità (%d / %d)" % [units_loaded, units_before], units_loaded == units_before)
		check("la chiesa c'è ancora", g2.sim.has_building(2, Defs.B_CHIESA))
		check("i fiorini sono quelli salvati", float(g2.sim.houses[2].gold) >= 777.0)
		check("il tempo riparte da dove era", g2.sim.time >= t_before)
		await shot(out, "sv_ripresa")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.PATH))
	print("FALLITI: ", fails)
	quit(1 if fails > 0 else 0)
