extends SceneTree
## Foto della bandiera di raduno e delle signorie minori, per il controllo visivo.
##   godot --path . -s tests/rally_shots.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()

func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	main.menu.select_house(1)
	main.menu.play_solo.emit(1, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	var sim: Sim = g.sim
	var mi: Dictionary = g.castles[1]
	var fp: Vector3 = (mi.gate_out as Vector3) + (mi.dir as Vector3) * 30.0 + Vector3(18, 0, 0)
	sim.houses[1].gold = 2000.0
	g.renderer.selected.clear()
	g.ctrl.selected_castle = 1
	g.send_cmd("rally", [1, fp])
	g.fx.flag_planted(fp)
	for k in 6:
		g.send_cmd("recruit", [1, Defs.FANTE])
	g.ctrl.focus = (mi.gate_out as Vector3).lerp(fp, 0.5)
	g.ctrl.target_dist = 60.0
	await create_timer(0.4).timeout
	await shot(out, "r_piantata")
	await create_timer(14.0).timeout
	await shot(out, "r_reclute")
	g.ctrl.focus = fp
	g.ctrl.target_dist = 28.0
	await create_timer(1.2).timeout
	await shot(out, "r_vicino")
	# la nonna parla ogni 7-11 secondi: qualche scatto per beccare il fumetto
	for k in 6:
		await create_timer(2.0).timeout
		await shot(out, "r_nonna_%d" % k)
	# una signoria minore: Ferrara degli Este
	g.ctrl.selected_castle = 4
	g.ctrl.focus = g.castles[4].center
	g.ctrl.target_dist = 120.0
	await create_timer(1.5).timeout
	await shot(out, "r_ferrara")
	# la pianura dall'alto: Milano, Genova, Ferrara, Firenze, Venezia
	g.ctrl.selected_castle = -1
	g.ctrl.focus = g.castles[4].center + Vector3(0, 0, -80)
	g.ctrl.target_dist = 420.0
	await create_timer(2.0).timeout
	await shot(out, "r_pianura")
	quit()
