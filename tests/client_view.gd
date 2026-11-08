extends SceneTree
## Client grafico connesso a un server remoto: controlla la vista e fotografa le truppe da vicino.
##   godot --path . -s tests/client_view.gd -- --connect 127.0.0.1 --port N --house 1 OUTDIR

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[a.size() - 1]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 600:
		await create_timer(0.05).timeout
		if main.game and main.game.welcome_done:
			break
	var g: Game = main.game
	print("welcome ", g.welcome_done, " casata ", g.my_house, " server? ", g.is_server, " sim ", g.sim)
	await create_timer(3.0).timeout
	print("unita viste ", g.vunits.size(), " stato ", g.state.size())
	var c: Controller = g.ctrl
	# inquadra il gruppo più numeroso
	var best := Vector3.ZERO
	var bestn := 0
	for u: Game.VU in g.vunits.values():
		var n := 0
		for o: Game.VU in g.vunits.values():
			if o.cur.distance_to(u.cur) < 12.0:
				n += 1
		if n > bestn:
			bestn = n
			best = u.cur
	c.focus = best
	c.target_dist = 26.0
	c.dist = 26.0
	c.yaw = 0.6
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/client_vicino.png")
	print("gruppo ", bestn, " a ", best)
	g.ctrl.select_army()
	c.target_dist = 120.0
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/client_lontano.png")
	print("selezionate ", g.renderer.selected.size(), " fps ", Engine.get_frames_per_second())
	quit(0)
