extends SceneTree
## Contro l'IA, «Ho letto» chiude subito il giornale e la guerra riparte.
##   godot --headless --path . -s tests/news_skip.gd

var fails := 0

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.force_view = true  # senza finestra la partita creerebbe solo la simulazione
	root.size = Vector2i(1600, 900)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	main.menu.select_house(1)
	main.menu.play_solo.emit(1, "")
	var t1 := Time.get_ticks_msec()
	while (main.game == null or not main.game.welcome_done) and Time.get_ticks_msec() - t1 < 60000:
		await process_frame
	var g: Game = main.game
	await create_timer(0.5).timeout
	var sim: Sim = g.sim
	sim._banner("Prova", "sotto", g.castles[1].center, 20.0)
	for k in 5:
		await process_frame
	check("il giornale è aperto", g.hud.paper_layer != null)
	g.hud._resume_paper()
	for k in 3:
		await process_frame
	check("dopo «Ho letto» il giornale sparisce subito", g.hud.paper_layer == null or not is_instance_valid(g.hud.paper_layer))
	check("e la guerra riparte", sim.news_t <= 0.0)
	# con la tastiera: Spazio, Esc o Invio voltano pagina
	for kc: Key in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
		sim._banner("Prova", "sotto", g.castles[1].center, 20.0)
		for k in 3:
			await process_frame
		var e := InputEventKey.new()
		e.keycode = kc
		e.physical_keycode = kc
		e.pressed = true
		root.push_input(e, true)
		for k in 3:
			await process_frame
		check("%s chiude il giornale" % OS.get_keycode_string(kc), g.hud.paper_layer == null and sim.news_t <= 0.0)
		check("%s non apre la pausa" % OS.get_keycode_string(kc), g.hud.pause_panel == null or not g.hud.pause_panel.visible)
	print("FALLITI: %d" % fails)
	quit(1 if fails > 0 else 0)
