extends SceneTree
## Screenshot di menu e interfaccia nei vari stati, per il controllo visivo.
##   godot --path . -s tests/hud_shots.gd -- OUTDIR

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
	await shot(out, "h_menu")
	main.menu.select_house(4)
	main.menu.play_solo.emit(4, "")
	await create_timer(0.9).timeout
	await shot(out, "h_intro_a")
	await create_timer(3.0).timeout
	await shot(out, "h_intro_b")
	var g: Game = main.game
	var sim: Sim = g.sim
	sim.houses[4].gold = 800.0
	g.send_cmd("recruit", [5, Defs.FANTE])
	g.send_cmd("recruit", [5, Defs.CATAPULTA])
	g.send_cmd("recruit", [5, Defs.CAVALIERE])
	await create_timer(4.0).timeout
	await shot(out, "h_castello")
	var ce: Vector3 = (g.castles[5].gate_out as Vector3)
	for k in 10:
		sim.spawn_unit(k % 3 + 0, 4, ce + Vector3(k % 4 * 2.2 - 3, 0, k / 4 * 2.2 + 4))
	sim.spawn_unit(Defs.CATAPULTA, 4, ce + Vector3(10, 0, 8))
	await create_timer(0.4).timeout
	g.ctrl.select_army()
	g.ctrl.focus = ce
	g.ctrl.target_dist = 70.0
	await create_timer(1.0).timeout
	await shot(out, "h_armata")
	g.renderer.selected.clear()
	g.ctrl.selected_castle = 4
	g.ctrl.focus = g.castles[4].center
	await create_timer(1.0).timeout
	root.warp_mouse(g.ctrl.cam.unproject_position(g.castles[4].center))
	await create_timer(0.4).timeout
	await shot(out, "h_nemico")
	sim.houses[4].faith = 150.0
	sim.houses[4].all_shops = true
	g.ctrl.start_action("power", Defs.P_MUCCHE)
	await create_timer(0.4).timeout
	await shot(out, "h_mira")
	g.ctrl.pending = {}
	g.send_cmd("power", [Defs.P_MUCCHE, (g.castles[4].center as Vector3)])
	g.ctrl.selected_castle = 5
	g.ctrl.focus = g.castles[5].center
	for k in 8:
		var inv := sim.spawn_unit(Defs.CAVALIERE, 1, (g.castles[5].center as Vector3) + Vector3(k * 2 - 8, 0, -24))
		inv.hp = 5000.0
	await create_timer(1.5).timeout
	await shot(out, "h_allarme")
	print("allarme visibile: ", g.hud.alert_btn.visible, " castello ", g.hud.alert_castle)
	g.hud.toggle_help()
	await create_timer(0.3).timeout
	await shot(out, "h_guida")
	quit()
