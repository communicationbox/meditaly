extends SceneTree
## I fumetti non si sovrappongono: tanti soldati ammassati che parlano, da vicino e da lontano,
## fermi e in marcia. Controlla i rettangoli sullo schermo e salva uno screenshot per zoom.
##   godot --path . -s tests/bubble_layout.gd -- OUTDIR

var fails := 0


func _init() -> void:
	_run.call_deferred()


func overlaps(fx: Node, what: String) -> void:
	var rects: Array[Rect2] = []
	for b: Dictionary in fx.bubbles:
		var l: Label = b.node
		if l.visible:
			rects.append(Rect2(l.position, l.size))
	var n := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				n += 1
	print("%s: fumetti visibili=%d sovrapposti=%d" % [what, rects.size(), n])
	if n > 0:
		fails += 1
	if rects.size() < 2:
		print("  ATTENZIONE: troppo pochi fumetti per dire qualcosa")
		fails += 1


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	while not main.menu.revealed:
		await create_timer(0.2).timeout
	main.menu.select_house(1)
	main.menu.play_solo.emit(1, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	var sim: Sim = g.sim
	sim.ai_enabled = false
	sim.events_enabled = false
	sim.truce_until = 0.0
	g.fx.bubble_cooldown = 0.0
	g.fx.bubble_repeat = 0.0
	if g.tutorial:
		g.tutorial.queue_free()
	var mi: Dictionary = g.castles[1]
	var ep: Vector3 = (mi.gate_out as Vector3) + (mi.dir as Vector3) * 30.0
	var us: Array = []
	var ids := PackedInt32Array()
	for k in 16:
		var u: Sim.U = sim.spawn_unit(Defs.FANTE, 1, ep + Vector3(k % 4 * 1.5, 0, k / 4 * 1.5))
		us.append(u)
		ids.append(u.id)
	await create_timer(0.3).timeout
	for d: float in [40.0, 110.0, 170.0]:
		g.ctrl.focus = ep
		g.ctrl.target_dist = d
		g.ctrl.dist = d
		await create_timer(0.5).timeout
		for k in 6:
			sim._say(us[k * 2], Defs.SAY_CARICA, true)
		await create_timer(0.6).timeout
		overlaps(g.fx, "fermi, distanza %d" % d)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/b_%d.png" % [out, d])
		await create_timer(3.5).timeout
	# in marcia: i soldati si incrociano mentre parlano
	g.ctrl.target_dist = 70.0
	g.ctrl.dist = 70.0
	sim.cmd_order(1, ids, ep + (mi.dir as Vector3) * 30.0, false)
	await create_timer(0.4).timeout
	for k in 6:
		sim._say(us[k * 2], Defs.SAY_CARICA, true)
	for k in 5:
		await create_timer(0.4).timeout
		overlaps(g.fx, "in marcia %d" % k)
	print("RISULTATO fumetti: ", "OK" if fails == 0 else "FALLITO (%d)" % fails)
	quit(1 if fails > 0 else 0)
