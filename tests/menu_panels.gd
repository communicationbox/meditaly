extends SceneTree
## Screenshot di caricamento, menu, impostazioni e pausa, per il controllo visivo.
##   godot --path . -s tests/menu_panels.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()


func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.5).timeout
	await shot(out, "m_caricamento")
	while not main.menu.revealed:
		await process_frame
	await create_timer(1.2).timeout
	await shot(out, "m_menu")
	main.menu._open_settings()
	await create_timer(0.4).timeout
	await shot(out, "m_impostazioni")
	for n in main.menu.get_children():
		if n is Settings.SettingsPanel:
			n.queue_free()
	main.menu.play_solo.emit(1, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	g.ctrl.selected_castle = -1
	g.hud.toggle_pause()
	await create_timer(0.4).timeout
	await shot(out, "m_pausa")
	quit()
