extends SceneTree
## Filmato di una conquista vera: fotogrammi JPG del momento in cui muore il re e di quel che segue.
##   godot --path . -s tests/capture_movie.gd -- OUTDIR
##   poi: ffmpeg -framerate FPS -i OUTDIR/f%05d.jpg conquista.mp4

func _init() -> void:
	_run.call_deferred()


func shot(out: String, n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


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
	if g.tutorial:
		g.tutorial.queue_free()
	# il castello neutrale più vicino a Milano
	var mi: Dictionary = g.castles[1]
	var tgt: Dictionary = {}
	var bd := 1e9
	for c: Dictionary in g.castles:
		if int(c.owner) < 0 or Defs.HOUSES[int(c.owner)].get("neutral", false) or c.id != mi.id and int(c.owner) != 1:
			var d: float = (c.center as Vector3).distance_to(mi.center)
			if c.id != mi.id and d < bd and int(c.owner) != 1:
				bd = d
				tgt = c
	print("bersaglio: ", tgt.name, " owner=", tgt.owner)
	var go: Vector3 = tgt.gate_out
	var ids := PackedInt32Array()
	for k in 24:
		var u := sim.spawn_unit([Defs.FANTE, Defs.CAVALIERE, Defs.BALESTRIERE, Defs.NONNA][k % 4], 1, go + (tgt.dir as Vector3) * (6.0 + k / 6 * 2.0) + Vector3(k % 6 * 2.0 - 5, 0, 0))
		ids.append(u.id)
	sim.cmd_order(1, ids, tgt.center, true)
	g.ctrl.focus = tgt.center
	g.ctrl.target_dist = 70.0
	g.ctrl.dist = 70.0
	var t := 0.0
	while float(tgt.capture) < 0.35 and t < 60.0:
		await create_timer(0.5).timeout
		t += 0.5
	await shot(out, "c1_assedio")
	g.ctrl.selected_castle = tgt.id
	await create_timer(0.4).timeout
	await shot(out, "c2_assedio_pannello")
	g.ctrl.selected_castle = -1
	# colpo di grazia al re
	tgt.king_safe = 0.0
	sim._hurt_king(tgt, 1e6, 1)
	g.ctrl.target_dist = 50.0
	var t0 := Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t0 < 14000:
		await RenderingServer.frame_post_draw
		var im := root.get_texture().get_image()
		im.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
		im.save_jpg("%s/f%05d.jpg" % [out, n], 0.9)
		n += 1
	var fps := float(n) / (float(Time.get_ticks_msec() - t0) / 1000.0)
	print("FOTOGRAMMI %d FPS %.2f" % [n, fps])
	quit(0)
