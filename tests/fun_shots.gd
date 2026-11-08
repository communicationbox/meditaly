extends SceneTree
## Screenshot del pacchetto comico: sagra della porchetta, fumetti, sciopero, sfottò.
##   godot --path . -s tests/fun_shots.gd -- OUTDIR

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
	main.menu.select_house(1)
	main.menu.play_solo.emit(1, "")
	await create_timer(4.0).timeout
	var g: Game = main.game
	var sim: Sim = g.sim
	sim.ai_enabled = false
	sim.events_enabled = false
	if g.tutorial:
		g.tutorial.queue_free()
	var mi: Dictionary = g.castles[1]
	var ep: Vector3 = (mi.gate_out as Vector3) + (mi.dir as Vector3) * 30.0
	for k in 14:
		sim.spawn_unit([Defs.FANTE, Defs.BALESTRIERE, Defs.CAVALIERE, Defs.NONNA][k % 4], 1, ep + Vector3(k % 5 * 2.0 - 4, 0, -12 - k / 5 * 2.0))
		sim.spawn_unit([Defs.FANTE, Defs.CAVALIERE, Defs.MENESTRELLO][k % 3], 2, ep + Vector3(k % 5 * 2.0 - 4, 0, 12 + k / 5 * 2.0))
	await create_timer(0.5).timeout
	sim._run_event(0)
	var spot := ep
	for u: Sim.U in sim.ulist:
		if u.feast > 0.0:
			spot = u.feast_pos
	g.ctrl.focus = spot
	g.ctrl.target_dist = 42.0
	g.ctrl.dist = 42.0
	await create_timer(0.7).timeout
	await shot(out, "f_sagra_titolo")
	await create_timer(5.0).timeout
	var said := 0
	for u: Sim.U in sim.ulist:
		if said < 4 and u.feast > 0.0:
			sim._say(u, Defs.SAY_SAGRA, true)
			said += 1
	await create_timer(0.5).timeout
	await shot(out, "f_sagra")
	for u: Sim.U in sim.ulist:
		u.feast = 0.0
	sim._run_event(1)
	await create_timer(0.6).timeout
	await shot(out, "f_sciopero_titolo")
	sim.cmd_taunt(1, 2)
	await create_timer(0.6).timeout
	await shot(out, "f_sfotto")
	# palio
	for u: Sim.U in sim.ulist:
		u.sleep = 0.0
		u.hp = 0.0
	sim._cleanup_dead()
	var pp: Vector3 = ep + (mi.dir as Vector3) * 30.0
	for k in 4:
		sim.spawn_unit(Defs.CAVALIERE, 1, pp + Vector3(-30, 0, k * 3.0))
		sim.spawn_unit(Defs.CAVALIERE, 3, pp + Vector3(30, 0, k * 3.0))
	await create_timer(0.5).timeout
	sim._run_event(4)
	g.ctrl.focus = sim.palio_pos
	g.ctrl.target_dist = 70.0
	g.ctrl.dist = 70.0
	await create_timer(2.0).timeout
	await shot(out, "f_palio")
	await create_timer(4.0).timeout
	await shot(out, "f_palio_fine")
	# fuga dal parmigiano
	for u: Sim.U in sim.ulist:
		u.hp = 0.0
	sim._cleanup_dead()
	for k in 12:
		var v := sim.spawn_unit(Defs.FANTE, 3, pp + Vector3(20 + k % 4 * 2.5, 0, k / 4 * 2.5 - 2.5))
		v.hp = 9999.0
	await create_timer(0.4).timeout
	g.ctrl.focus = pp + Vector3(22, 0, 0)
	g.ctrl.target_dist = 45.0
	g.ctrl.dist = 45.0
	sim.wheels.append({"id": 9100, "pos": pp + Vector3(-5, 6, 0), "vel": Vector3(30, 0, 0), "t": 6.0, "team": 1, "roll": 0.0})
	await create_timer(0.6).timeout
	await shot(out, "f_panico")
	# ballo di vittoria
	for u: Sim.U in sim.ulist:
		u.hp = 0.0
	sim._cleanup_dead()
	sim.wheels.clear()
	for k in 12:
		sim.spawn_unit([Defs.FANTE, Defs.NONNA, Defs.CAVALIERE][k % 3], 1, (mi.rally as Vector3) + Vector3(k % 4 * 2.5 - 4, 0, k / 4 * 2.5))
	await create_timer(0.4).timeout
	g.ctrl.focus = mi.rally
	g.ctrl.target_dist = 30.0
	g.ctrl.dist = 30.0
	g.fx.event("dance", mi.center, 1.0)
	for u: Sim.U in sim.ulist.slice(0, 3):
		sim._say(u, Defs.SAY_VITTORIA, true)
	await create_timer(1.0).timeout
	await shot(out, "f_ballo")
	print("fatto")
	quit(0)
