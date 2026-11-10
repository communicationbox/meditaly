extends SceneTree
## Il finale di chi vince, fotografato a ogni inquadratura; poi la vittoria vera deve farlo partire.
##   godot --path . -s tests/finale_shots.gd -- OUTDIR

var ok := 0
var bad := 0


func check(name_: String, cond: bool) -> void:
	if cond:
		ok += 1
		print("OK   ", name_)
	else:
		bad += 1
		print("FAIL ", name_)


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
	while not main.menu.revealed:
		await process_frame
	main.menu.play_solo.emit(4, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	g.sim.ai_enabled = false
	var f := g.start_finale()
	# il corteo gira attorno alla tavola: niente pali, alberi o case sulla sua strada
	var worst := 99.0
	for c: Array in f.colliders:
		var p: Vector3 = c[0]
		var gap := absf(Vector2(p.x, p.z).length() - Finale.R_PROC) - float(c[1]) - Finale.SHIELD_R
		worst = minf(worst, gap)
	print("     spazio minimo attorno al corteo: %.1f m" % worst)
	check("il corteo non passa dentro pali, alberi e case", worst > 0.3)
	check("attorno c'è il bosco", f.colliders.size() > 40)
	for at: float in [2.0, 5.5, 10.0, 16.5, 22.0, 25.0]:
		while f._t < at:
			await process_frame
		await shot(out, "finale_%02d" % int(at))
	f.skip()
	await create_timer(1.0).timeout
	await shot(out, "finale_fine")
	check("il cartello FINE c'è", is_instance_valid(f) and f._card != null)
	check("l'interfaccia di gioco è nascosta", is_instance_valid(f) and not g.hud.visible)
	if is_instance_valid(f):
		f.close()
	await create_timer(0.5).timeout
	check("resta a guardare: torna la mappa", g.hud.visible and g.ctrl.cam.current and g.finale == null or not is_instance_valid(g.finale))
	g.finale = null
	# vittoria vera: l'ultimo castello cade e il finale parte da solo
	for c: Dictionary in g.sim.castles:
		c.owner = 4
	g.sim._check_winner()
	var waited := 0.0
	while g.finale == null and waited < 15.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check("alla vittoria parte il finale", g.finale != null)
	print("FALLITI: ", bad)
	quit()
