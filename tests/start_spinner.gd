extends SceneTree
## Dal clic su «gioca» alla partita: la rotella deve girare davvero (fotogrammi brevi) e il
## blocco finale deve essere corto. T non prende i frati.
##   godot --path . -s tests/start_spinner.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/caricamento.png" % out)
	while not main.menu.revealed:
		await process_frame
	await create_timer(1.2).timeout
	var menu = main.menu
	menu._go(func(): menu.play_solo.emit(1, ""))
	var t0 := Time.get_ticks_msec()
	var last := t0
	var worst := 0
	var frames := 0
	var shot_done := false
	while main.game == null:
		await process_frame
		var now := Time.get_ticks_msec()
		var freeze := now - last
		last = now
		if main.game == null:
			worst = maxi(worst, freeze)
			frames += 1
		else:
			print("ultimo blocco (creazione partita): %d ms" % freeze)
		if not shot_done and now - t0 > 300:
			shot_done = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/rotella.png" % out)
	print("attesa con rotella: %d ms, fotogrammi: %d, fotogramma peggiore: %d ms" % [last - t0, frames, worst])
	var g: Game = main.game
	var ok := g != null and g.welcome_done and g.world._dirty.size() < 40
	print("mondo pronto: ", ok, " pezzi ancora da rifare: ", g.world._dirty.size())
	var sim: Sim = g.sim
	var ep: Vector3 = g.castles[g.my_house].gate_out
	var fr: Sim.U = sim.spawn_unit(Defs.FRATE, g.my_house, ep)
	var fa: Sim.U = sim.spawn_unit(Defs.FANTE, g.my_house, ep + Vector3(2, 0, 0))
	await create_timer(0.6).timeout
	g.ctrl.select_army()
	var okt: bool = g.renderer.selected.has(fa.id) and not g.renderer.selected.has(fr.id)
	print("T prende il fante e lascia il frate: ", okt)
	var cc: Controller = g.ctrl
	var sz := Vector2(1600, 900)
	var oke: bool = cc.edge_pan(Vector2(2, 450), sz) == Vector2(-1, 0) and cc.edge_pan(Vector2(1598, 450), sz) == Vector2(1, 0) and cc.edge_pan(Vector2(800, 2), sz) == Vector2(0, -1) and cc.edge_pan(Vector2(800, 898), sz) == Vector2(0, 1) and cc.edge_pan(Vector2(800, 450), sz) == Vector2.ZERO and cc.edge_pan(Vector2(-5, 450), sz) == Vector2.ZERO
	print("bordi: ", oke)
	# un mondo già costruito rifà solo i pezzi cambiati (è il caso di «Continua»)
	var ix := Defs.WX / 2 + Defs.WZ / 2 * Defs.WX
	g.world.apply_edits(PackedInt64Array([(ix << Defs.EDIT_SHIFT) | 1]))
	var before: int = g.world._dirty.size()
	g.world.build_all_blocking()
	var okd: bool = before > 0 and g.world._dirty.is_empty()
	print("pezzi cambiati rifatti: ", okd, " (", before, ")")
	var fail := not ok or not okt or worst > 200 or not oke or not okd
	print("RISULTATO: ", "FALLITO" if fail else "OK")
	quit(1 if fail else 0)
