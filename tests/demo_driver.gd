extends Node
## Regia automatica per test visivi: assedio con poteri, screenshot e misura degli FPS.
##   godot --path . -- --demo --shots DIR

var game: Node
var t := 0.0
var step := 0
var dir := ""
var frames := 0
var min_fps := 999.0
var bologna: Dictionary
var script_steps: Array = []
var skip_frames := 0
var worst_ms := 0.0


func setup(g: Node) -> void:
	game = g
	var a := OS.get_cmdline_user_args()
	var i := a.find("--shots")
	dir = a[i + 1] if i >= 0 else OS.get_user_data_dir()
	var sim: Sim = game.sim
	bologna = game.castles[4]
	sim.houses[game.my_house].gold = 9000.0
	sim.houses[game.my_house].faith = 150.0
	sim.houses[game.my_house].all_shops = true
	var ce: Vector3 = bologna.center
	var spawn: Vector3 = ce + Vector3(0, 0, -58)
	var types := [Defs.FANTE, Defs.FANTE, Defs.FANTE, Defs.BALESTRIERE, Defs.CAVALIERE]
	for k in 44:
		var p := spawn + Vector3((k % 11 - 5) * 2.6, 0, -(k / 11) * 2.6)
		sim.spawn_unit(types[k % types.size()], game.my_house, p)
	for k in 3:
		sim.spawn_unit(Defs.CATAPULTA, game.my_house, spawn + Vector3(-12 + k * 12, 0, -14))
	sim.spawn_unit(Defs.BOMBARDA, game.my_house, spawn + Vector3(-18, 0, -14))
	sim.spawn_unit(Defs.ARIETE, game.my_house, spawn + Vector3(18, 0, -10))
	var c: Controller = game.ctrl
	c.focus = spawn + Vector3(0, 1, -2)
	c.target_dist = 22.0
	c.dist = 22.0
	c.yaw = PI * 0.82
	script_steps = [
		[0.5, func(): _shot("00_vicino")],
		[0.7, func(): _cam(spawn + Vector3(-14, 1, -12), 16.0, c.yaw)],
		[1.2, func(): _shot("01_assedio_vicino")],
		[1.4, _order_all],
		[1.5, func(): _cam(spawn + Vector3(0, 0, 18), 70.0, c.yaw)],
		[5.0, func(): _shot("02_marcia")],
		[9.0, func(): _cam(ce + Vector3(0, 0, -18), 62.0, c.yaw)],
		[11.0, func(): _shot("03_assedio")],
		[15.0, func(): _power(Defs.P_PARMIGIANO, ce + Vector3(0, 10, -8))],
		[17.2, func(): _shot("04_parmigiano")],
		[19.0, func(): _shot("05_breccia")],
		[20.0, func(): _power(Defs.P_MUCCHE, ce + Vector3(6, 10, 4))],
		[22.0, func(): _shot("06_mucche")],
		[24.0, func(): _power(Defs.P_TERREMOTO, ce + Vector3(0, 10, 2))],
		[27.0, func(): _shot("07_terremoto")],
		[29.0, func(): _power(Defs.P_MUCCHE, ce + Vector3(-8, 10, 8))],
		[29.1, func(): _power(Defs.P_SCUDO, ce + Vector3(0, 10, -30))],
		[29.2, func(): _power(Defs.P_VINO, ce + Vector3(0, 10, -10))],
		[31.0, func(): _shot("08_mucche_scudo")],
		[38.0, func(): _shot("09_macerie")],
		[38.1, func(): game.fx.event("king_dead", game.castles[5].king, float(4 + 16 * game.my_house))],
		[38.9, func(): _shot("09b_re")],
		[40.9, func(): _shot("09b_re_profilo")],
		[42.4, func(): _shot("09c_re_vola")],
		[44.4, func(): _cam(Vector3(Defs.WX / 2.0, 12, Defs.WZ / 2.0), 680.0 * Defs.MAP_SCALE, 0.0)],
		[46.4, func(): _shot("10_italia")],
		[47.4, _finish],
	]


func _cam(f: Vector3, d: float, y: float) -> void:
	var c: Controller = game.ctrl
	c.focus = f
	c.target_dist = d
	c.dist = d
	c.yaw = y


func _power(k: int, p: Vector3) -> void:
	game.sim.houses[game.my_house].faith = 150.0
	game.sim.houses[game.my_house].cd[k] = 0.0
	game.send_cmd("power", [k, p])


func _order_all() -> void:
	var ids := PackedInt32Array()
	for u: Sim.U in game.sim.ulist:
		if u.team == game.my_house:
			ids.append(u.id)
	game.renderer.selected.clear()
	for id in ids:
		game.renderer.selected[id] = true
	game.send_cmd("order", [ids, bologna.rally, false])


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [dir, n])
	var sim: Sim = game.sim
	print("%s t=%.1f fps=%d min=%d unita=%d frammenti=%d modifiche=%d integr=%.2f cattura=%.2f" % [n, t, Engine.get_frames_per_second(), int(min_fps), sim.ulist.size(), sim.fragments.size(), game.edit_log.size(), bologna.integrity, bologna.capture])
	min_fps = 999.0
	skip_frames = 2


func _finish() -> void:
	var w: VoxelWorld = game.world
	var empty: Array = []
	var bad: Array = []
	for k in VoxelWorld.CX * VoxelWorld.CZ:
		var mi: MeshInstance3D = w._inst[k]
		var seq: int = (w._mesh_chunk(k % VoxelWorld.CX, k / VoxelWorld.CX).v as PackedVector3Array).size()
		var n: int = mi.mesh.surface_get_array_len(0) if mi and mi.mesh else 0
		if n == 0 and seq > 0:
			empty.append(k)
		elif absi(n - seq) > 0:
			bad.append([k % VoxelWorld.CX, k / VoxelWorld.CX, n, seq, mi.visible, mi.is_inside_tree()])
	print("chunk vuoti ", empty.size(), " diversi ", bad.slice(0, 8))
	print("DEMO FINE")
	get_tree().quit(0)


func _process(dt: float) -> void:
	t += dt
	frames += 1
	if skip_frames > 0:
		skip_frames -= 1
	elif t > 1.0 and dt > 0.0:
		min_fps = minf(min_fps, 1.0 / dt)
	while step < script_steps.size() and t >= float(script_steps[step][0]):
		(script_steps[step][1] as Callable).call()
		step += 1
