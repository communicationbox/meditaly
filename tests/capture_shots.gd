extends SceneTree
## Screenshot di una conquista: assedio, re colpito sul gabinetto, cinematica, re in volo,
## bandiere che cambiano colore, balli di vittoria.
##   godot --path . -s tests/capture_shots.gd -- OUTDIR

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
	var marks := [0.4, 1.6, 3.0, 3.8, 4.8, 6.0, 7.0, 8.5, 11.0]
	var prev := 0.0
	for k in marks.size():
		await create_timer(marks[k] - prev).timeout
		prev = marks[k]
		await shot(out, "c3_%d_t%.1f" % [k, marks[k]])
	print("nuovo padrone: ", tgt.owner)
	var ce: Vector3 = tgt.center
	var side := Vector3(-(tgt.dir as Vector3).z, 0, (tgt.dir as Vector3).x)
	var inyard := 0
	var inkeep := 0
	for u: Sim.U in sim.ulist:
		if u.team == 1 and ids.has(u.id):
			if absf((u.pos - ce).dot(side)) > 9.0:
				inyard += 1
			else:
				inkeep += 1
	print("vincitori nelle fasce laterali: ", inyard, " altrove: ", inkeep)
	quit(0)
