extends SceneTree
## Le uscite di scena del re: per ognuna una foto sul set e una nel mondo.
##   godot --path . -s tests/king_deaths.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()


func shot(out: String, n: String) -> void:
	if DisplayServer.get_name() == "headless":  # senza finestra non si disegna: niente foto
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	while not main.menu.revealed:
		await create_timer(0.2).timeout
	main.menu.play_solo.emit(1, "Prova")
	await create_timer(5.0).timeout
	var g: Game = main.game
	g.sim.ai_enabled = false
	g.sim.events_enabled = false
	if g.tutorial:
		g.tutorial.queue_free()
	for v in Defs.KING_DEATHS.size():
		g.hud._debug_king(v)
		await create_timer(1.8).timeout
		await shot(out, "re_%d_set" % v)
		await create_timer(1.4 + Controller.exit_time(v) * 0.42).timeout
		await shot(out, "re_%d_mondo" % v)
		await create_timer(Controller.exit_time(v) * 0.42).timeout
		await shot(out, "re_%d_fine" % v)
		while not g.ctrl.cine.is_empty():  # il volo in cielo dura più delle altre
			await process_frame
		await create_timer(0.8).timeout
	print("FALLITI: 0")
	quit(0)
