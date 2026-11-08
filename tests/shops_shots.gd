extends SceneTree
## Screenshot delle botteghe: tutte e sei costruite in tre castelli, con i loro personaggi,
## più frati, nonne e menestrelli, e il pannello del castello con la riga delle botteghe.
##   godot --path . -s tests/shops_shots.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()


func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	main.menu.select_house(1)
	main.menu.play_solo.emit(1, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	var sim: Sim = g.sim
	sim.ai_enabled = false
	# tutte e sei le botteghe attorno a Milano, più una seconda chiesa
	var mi0: Dictionary = g.castles[1]
	var built: Array = []
	for type: int in [Defs.B_CHIESA, Defs.B_CASEIFICIO, Defs.B_STALLA, Defs.B_CANTINA, Defs.B_ASTROLOGO, Defs.B_SANTUARIO, Defs.B_CHIESA]:
		var spot := sim.find_spot(1, mi0)
		if spot.y > -0.5:
			built.append(sim.build_now(1, type, spot))
	for k in 4:
		var fr := sim.spawn_unit(Defs.FRATE, 1, (mi0.gate_out as Vector3) + Vector3(k * 2.0, 0, 0))
	var mi: Dictionary = g.castles[1]
	var ce: Vector3 = mi.center
	for k in 3:
		sim.spawn_unit(Defs.NONNA, 1, (mi.gate_out as Vector3) + Vector3(k * 2.0 - 2.0, 0, 3))
		sim.spawn_unit(Defs.MENESTRELLO, 1, (mi.gate_out as Vector3) + Vector3(k * 2.0 - 2.0, 0, 6))
	await create_timer(1.5).timeout
	var errs := 0
	g.ctrl.focus = mi.center
	g.ctrl.target_dist = 150.0
	g.ctrl.dist = 150.0
	await create_timer(1.6).timeout
	await shot(out, "s_attorno_milano")
	# primo piano di ogni bottega col suo personaggio
	for k in built.size():
		var bd: Dictionary = built[k]
		var fr: Array = Buildings.front(Vector2i(bd.x, bd.z), int(bd.base), Vector2i(bd.fx, bd.fz))
		var face: Vector3 = fr[1]
		var back := (face + Vector3(-face.z, 0, face.x) * 0.5).normalized()
		g.ctrl.focus = (fr[0] as Vector3) - face * 3.0
		g.ctrl.target_dist = 22.0
		g.ctrl.dist = 22.0
		g.ctrl.yaw = atan2(back.x, back.z)
		await create_timer(0.9).timeout
		await shot(out, "s_bottega_%d" % k)
	g.ctrl.focus = mi.gate_out
	g.ctrl.target_dist = 16.0
	g.ctrl.dist = 16.0
	await create_timer(1.2).timeout
	await shot(out, "s_nonne")
	g.ctrl.selected_castle = 1
	g.ctrl.focus = ce
	g.ctrl.target_dist = 60.0
	await create_timer(1.0).timeout
	await shot(out, "s_pannello")
	sim.houses[1].gold = 160.0
	await create_timer(0.3).timeout
	await shot(out, "s_tab_truppe")
	g.hud._set_tab(1)
	await create_timer(0.5).timeout
	await shot(out, "s_menu_botteghe")
	print("fatto, errori=", errs)
	quit(0)
