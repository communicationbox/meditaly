extends SceneTree
## Screenshot del menu principale: attesa, Italia pronta, cambio di casata, pannello amici.
##   godot --path . -s tests/menu_shots.gd -- OUTDIR

func _init() -> void:
	_run.call_deferred()


func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await shot(out, "m_attesa")
	await create_timer(14.0).timeout
	await shot(out, "m_menu")
	main.menu.select_house(4)
	await create_timer(6.0).timeout
	await shot(out, "m_medici")
	main.menu.friends_box.visible = true
	await create_timer(0.4).timeout
	await shot(out, "m_amici")
	quit(0)
