class_name Game
extends Node
## Mozzo di rete e di partita. Il server esegue Sim; tutti i peer applicano modifiche ed eventi.

const SEED := 1453

var world: VoxelWorld
var sim: Sim
var castles: Array = []
var is_server := false
var is_view := false
var my_house := -1
var my_name := ""
var pref_house := 1
var peer_house: Dictionary = {}
var edit_log := PackedInt64Array()
var state: Array = []
var welcome_done := false
var vunits: Dictionary = {}
var test_args := PackedStringArray()
var net_multiplayer := false

var renderer: UnitRenderer
var fx: Fx
var hud: Hud
var ctrl: Controller
var tutorial: Tutorial
var mission: Mission
var _test_t := 0.0
var _hash_ok := 0
var _hash_fail := 0


# ---------------------------------------------------------------- avvio
func start_solo(pref: int, pname: String, args: PackedStringArray) -> void:
	test_args = args
	my_name = pname
	is_server = true
	_load_world()
	_create_sim()
	_assign(1, pref, pname)
	_enter_game()


## Riprende la partita salvata contro l'IA.
func start_loaded() -> bool:
	var d := SaveGame.load_data()
	if d.is_empty():
		return false
	is_server = true
	my_name = String(d.name)
	_load_world()
	var raw: PackedByteArray = d.edits
	edit_log = raw.decompress(int(d.edits_size), FileAccess.COMPRESSION_ZSTD).to_int64_array()
	world.apply_edits(edit_log)
	_create_sim()
	sim.load_state(d.sim)
	my_house = int(d.house)
	peer_house[1] = my_house
	state = sim.state_array()
	_enter_game()
	return true


func start_host(port: int, pref: int, pname: String) -> void:
	my_name = pname
	is_server = true
	net_multiplayer = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 16)
	if err != OK:
		push_error("Impossibile aprire la porta %d" % port)
		get_parent().call_deferred("back_to_menu")
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.peer_connected.connect(func(id: int): _patient(peer, id))
	_load_world()
	_create_sim()
	_assign(1, pref, pname)
	_enter_game()


func start_dedicated(port: int, args: PackedStringArray) -> void:
	test_args = args
	is_server = true
	net_multiplayer = true
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 16)
	if err != OK:
		print("ERRORE: porta %d non disponibile (%d)" % [port, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.peer_connected.connect(func(id: int): _patient(peer, id))
	_load_world()
	_create_sim()
	print("Server pronto sulla porta %d" % port)
	var ts := args.find("--time-scale")
	if ts >= 0:
		Engine.time_scale = args[ts + 1].to_float()
		Engine.max_physics_steps_per_frame = 64
	if "--test-server" in args:
		sim.ai_aggression = 3.0
		for h: Dictionary in sim.houses:
			h.gold = 3000.0
			h.faith = 150.0


func start_client(ip: String, port: int, pref: int, pname: String, args: PackedStringArray) -> void:
	test_args = args
	my_name = pname
	pref_house = pref
	net_multiplayer = true
	# l'Italia si genera prima di collegarsi: sono alcuni secondi in cui la rete non verrebbe
	# servita, e il server chiuderebbe la connessione per timeout
	_show_wait("Preparo l'Italia...")
	await get_tree().process_frame
	await get_tree().process_frame
	_load_world()
	if is_instance_valid(_wait_lbl):
		_wait_lbl.text = "Connessione a %s..." % ip
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		_connection_failed()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func():
		_patient(peer, 1)
		c_join.rpc_id(1, pname, pref))
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_connection_failed)


## La costruzione della mappa grande blocca per qualche secondo: ENet deve avere pazienza.
func _patient(peer: ENetMultiplayerPeer, id: int) -> void:
	var pp := peer.get_peer(id)
	if pp:
		pp.set_timeout(0, 20000, 60000)


func _connection_failed() -> void:
	print("Connessione fallita o server chiuso")
	if "--test-client" in test_args:
		get_tree().quit(2)
		return
	get_parent().call_deferred("back_to_menu")


var _wait_lbl: Label
func _show_wait(text: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cl := CanvasLayer.new()
	_wait_lbl = Label.new()
	_wait_lbl.text = text
	_wait_lbl.set_anchors_preset(Control.PRESET_CENTER)
	cl.add_child(_wait_lbl)
	add_child(cl)


## L'Italia già generata dal menu (sfondo): la partita la prende così com'è, senza rigenerarla.
static var prebuilt_world: VoxelWorld = null
static var prebuilt_castles: Array = []


func _load_world() -> void:
	if prebuilt_world != null and is_instance_valid(prebuilt_world) and not prebuilt_castles.is_empty():
		world = prebuilt_world
		castles = prebuilt_castles
		prebuilt_world = null
		prebuilt_castles = []
		if world.get_parent() != null:
			world.get_parent().remove_child(world)
		add_child(world)
		return
	world = VoxelWorld.new()
	add_child(world)
	castles = WorldGen.generate(world, SEED)


func _create_sim() -> void:
	sim = Sim.new()
	sim.name = "Sim"
	add_child(sim)
	sim.setup(self, castles)
	# la difficoltà scelta nelle impostazioni (i test e il server di prova la impostano da sé)
	var dd: Dictionary = Settings.diff()
	sim.ai_aggression = float(dd.aggr)
	sim.ai_income = float(dd.income)
	sim.ai_cap_mult = float(dd.cap)
	sim.equal_houses = Settings.equal_houses
	state = sim.state_array()


## Solo per i test senza finestra: crea lo stesso telecamera, interfaccia e soldati disegnati.
static var force_view := false


func _enter_game() -> void:
	is_view = DisplayServer.get_name() != "headless" or force_view
	world.build_all_blocking()
	welcome_done = true
	if not is_view:
		return
	var main_view: Node = (load("res://scripts/environment.gd") as GDScript).new()
	add_child(main_view)
	renderer = UnitRenderer.new()
	add_child(renderer)
	renderer.setup(self)
	fx = Fx.new()
	add_child(fx)
	fx.setup(self)
	ctrl = Controller.new()
	add_child(ctrl)
	ctrl.setup(self)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	var mi := test_args.find("--missione")
	if mi >= 0 and mi + 1 < test_args.size() and sim != null:
		mission = Mission.new()
		add_child(mission)
		mission.setup(self, test_args[mi + 1].to_int())
	if "--tutorial" in test_args:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self)
	if "--demo" in test_args:
		var demo: Node = (load("res://tests/demo_driver.gd") as GDScript).new()
		add_child(demo)
		demo.setup(self)
	if "--scena-re" in test_args:
		_king_scene_loop()
	if "--finale" in test_args:
		_finale_loop()


var finale: Finale


## Il gran finale di chi vince: parte appena finita la scena dell'ultimo re e il titolo del castello.
func play_finale() -> void:
	if finale != null or not is_view or my_house < 0:
		return
	await get_tree().create_timer(0.8).timeout
	while is_inside_tree() and ctrl and not ctrl.cine.is_empty():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree() and finale == null:
		start_finale()


func start_finale() -> Finale:
	finale = Finale.new()
	add_child(finale)
	finale.setup(self, my_house)
	return finale


## Solo il finale, ripetuto, per guardarlo senza dover conquistare l'Italia.
func _finale_loop() -> void:
	sim.ai_enabled = false
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		var f := start_finale()
		await f.finished
		finale = null


## Solo la scena del re sul gabinetto, ripetuta, per guardarla senza dover conquistare un castello.
func _king_scene_loop() -> void:
	sim.ai_enabled = false
	var k := 0
	while is_inside_tree():
		await get_tree().create_timer(1.5).timeout
		var c: Dictionary = castles[[5, 7, 2, 9][k % 4]]
		k += 1
		fx.event("king_dead", c.king, float(castle_owner(c.id) + 16 * my_house))
		while not ctrl.cine.is_empty():
			await get_tree().process_frame


# ---------------------------------------------------------------- comandi client -> server
func send_cmd(kind: String, args: Array) -> void:
	if is_server:
		_exec_cmd(1, kind, args)
	else:
		c_cmd.rpc_id(1, kind, args)


@rpc("any_peer", "reliable")
func c_cmd(kind: String, args: Array) -> void:
	if is_server:
		_exec_cmd(multiplayer.get_remote_sender_id(), kind, args)


func _exec_cmd(peer: int, kind: String, a: Array) -> void:
	var team: int = int(peer_house.get(peer, -1))
	if team < 0 or sim == null:
		return
	if not _args_ok(kind, a):
		return
	if not sim.cmd_allowed(team, kind, a):
		return  # storia: non ancora sbloccato
	match kind:
		"recruit": sim.cmd_recruit(team, a[0], a[1])
		"order": sim.cmd_order(team, a[0], _clamp_p(a[1]), a[2])
		"garrison": if _valid_castle(a[0]): sim.cmd_garrison(team, a[0])
		"repair": if _valid_castle(a[0]): sim.cmd_repair(team, a[0])
		"mangano": if _valid_castle(a[0]): sim.cmd_mangano(team, a[0], _clamp_p(a[1]))
		"oil": if _valid_castle(a[0]): sim.cmd_oil(team, a[0], _clamp_p(a[1]))
		"power": sim.cmd_power(team, a[0], _clamp_p(a[1]))
		"special": sim.cmd_special(team, _clamp_p(a[0]))
		"news_read": sim.cmd_news_read(team)
		"power_aim": sim.cmd_power(team, a[0], _clamp_p(a[1]), a[2])
		"build": sim.cmd_build(team, a[0], _clamp_p(a[1]))
		"taunt": sim.cmd_taunt(team, a[0])
		"rally": if _valid_castle(a[0]): sim.cmd_rally(team, a[0], _clamp_p(a[1]))
		"rally_clear": if _valid_castle(a[0]): sim.cmd_rally_clear(team, a[0])


## I comandi arrivano dalla rete: tipi e lunghezze vanno verificati.
func _args_ok(kind: String, a: Array) -> bool:
	var want: Array
	match kind:
		"recruit": want = [TYPE_INT, TYPE_INT]
		"build": want = [TYPE_INT, TYPE_VECTOR3]
		"order": want = [TYPE_PACKED_INT32_ARRAY, TYPE_VECTOR3, TYPE_BOOL]
		"garrison", "repair", "taunt", "rally_clear": want = [TYPE_INT]
		"rally": want = [TYPE_INT, TYPE_VECTOR3]
		"mangano", "oil", "power": want = [TYPE_INT, TYPE_VECTOR3]
		"power_aim": want = [TYPE_INT, TYPE_VECTOR3, TYPE_VECTOR3]
		"special": want = [TYPE_VECTOR3]
		"news_read": want = []
		_: return false
	if a.size() != want.size():
		return false
	for i in a.size():
		if typeof(a[i]) != want[i]:
			return false
	return true


func _valid_castle(c: int) -> bool:
	return c >= 0 and c < castles.size()


func _clamp_p(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, 2.0, Defs.WX - 3.0), clampf(p.y, 0.0, Defs.WY - 2.0), clampf(p.z, 2.0, Defs.WZ - 3.0))


# ---------------------------------------------------------------- ingresso giocatori
func _assign(peer: int, pref: int, pname: String) -> int:
	var h: int = -1
	if pref >= 0 and pref < Defs.HOUSE_COUNT and sim.houses[pref].ai and sim.houses[pref].alive:
		h = pref
	else:
		for k in Defs.HOUSE_COUNT:
			if sim.houses[k].ai and sim.houses[k].alive:
				h = k
				break
	peer_house[peer] = h
	if peer == 1:
		my_house = h
	if h >= 0:
		sim.houses[h].ai = false
		sim.houses[h].peer = peer
		sim.houses[h].pname = pname.substr(0, 20) if pname != "" else String(Defs.HOUSES[h].name)
		msg_all("%s prende il comando di %s" % [sim.houses[h].pname, Defs.HOUSES[h].name], Defs.HOUSES[h].color)
	return h


@rpc("any_peer", "reliable")
func c_join(pname: String, pref: int) -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer_house.has(peer):
		return
	var h := _assign(peer, pref, pname)
	var raw := edit_log.to_byte_array()
	r_welcome.rpc_id(peer, h, raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size(), sim.state_array())


func _on_peer_left(peer: int) -> void:
	var h: int = peer_house.get(peer, -1)
	peer_house.erase(peer)
	if h >= 0:
		sim.houses[h].ai = true
		sim.houses[h].peer = 0
		msg_all("%s ha lasciato: subentra l'IA" % sim.houses[h].pname, Defs.HOUSES[h].color)
		sim.houses[h].pname = ""


@rpc("authority", "reliable")
func r_welcome(house: int, edits: PackedByteArray, raw_size: int, st: Array) -> void:
	my_house = house
	state = st
	if is_instance_valid(_wait_lbl):
		_wait_lbl.get_parent().queue_free()
	if world == null:
		_load_world()
	if raw_size > 0:
		world.apply_edits(edits.decompress(raw_size, FileAccess.COMPRESSION_ZSTD).to_int64_array())
	_enter_game()
	print("Entrato in partita come casata ", house)


# ---------------------------------------------------------------- server -> tutti
func _has_peers() -> bool:
	return net_multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty()


func push_edits(edits: PackedInt64Array, debris := true) -> void:
	edit_log.append_array(edits)
	_apply_edits(edits, debris)
	if _has_peers():
		var raw := edits.to_byte_array()
		if raw.size() > 400:
			r_edits_z.rpc(raw.compress(FileAccess.COMPRESSION_ZSTD), raw.size(), debris)
		else:
			r_edits.rpc(edits, debris)


func _apply_edits(edits: PackedInt64Array, debris: bool) -> void:
	if fx and debris:
		fx.debris_from_edits(edits)
	world.apply_edits(edits)


@rpc("authority", "reliable")
func r_edits(edits: PackedInt64Array, debris: bool) -> void:
	if welcome_done:
		_apply_edits(edits, debris)


@rpc("authority", "reliable")
func r_edits_z(data: PackedByteArray, raw_size: int, debris: bool) -> void:
	if welcome_done:
		_apply_edits(data.decompress(raw_size, FileAccess.COMPRESSION_ZSTD).to_int64_array(), debris)


func fx_all(kind: String, p: Vector3, a: float) -> void:
	if fx:
		fx.event(kind, p, a)
	if _has_peers():
		r_fx.rpc(kind, p, a)


@rpc("authority", "reliable")
func r_fx(kind: String, p: Vector3, a: float) -> void:
	if fx:
		fx.event(kind, p, a)


## Evento a sorpresa: grande titolo al centro dello schermo per tutti.
func news_status_all(done: int, total: int) -> void:
	r_news_status(done, total)
	if _has_peers():
		r_news_status.rpc(done, total)


@rpc("authority", "reliable")
func r_news_status(done: int, total: int) -> void:
	if hud:
		hud.paper_status(done, total)


func banner_all(title: String, sub: String, p: Vector3, life := 0.0, ev := 0, news := PackedInt32Array()) -> void:
	r_banner(title, sub, p, life, ev, news)
	if _has_peers():
		r_banner.rpc(title, sub, p, life, ev, news)


@rpc("authority", "reliable")
func r_banner(title: String, sub: String, p: Vector3, life: float, ev: int, news: PackedInt32Array) -> void:
	if hud:
		if life > 0.0:
			hud.newspaper(ev, title, sub, news)
		else:
			hud.banner(title, sub, p)
		hud.event_mark(title, p, life)


func msg_all(text: String, col: Color) -> void:
	if hud:
		hud.notify(text, col)
	if _has_peers():
		r_msg.rpc(text, col)


## Messaggio solo al giocatore che comanda la casata (nessuno se è l'IA).
func msg_house(team: int, text: String, col: Color) -> void:
	if sim == null or team < 0 or team >= sim.houses.size() or sim.houses[team].ai:
		return
	if team == my_house and hud:
		hud.notify(text, col)
	var peer: int = sim.houses[team].peer
	if peer != 0 and _has_peers() and peer in multiplayer.get_peers():
		r_msg.rpc_id(peer, text, col)


@rpc("authority", "reliable")
func r_msg(text: String, col: Color) -> void:
	if hud:
		hud.notify(text, col)


func proj_all(id: int, kind: int, p: Vector3, v: Vector3) -> void:
	if fx:
		fx.projectile_start(id, kind, p, v)
	if _has_peers():
		r_proj.rpc(id, kind, p, v)


@rpc("authority", "reliable")
func r_proj(id: int, kind: int, p: Vector3, v: Vector3) -> void:
	if fx:
		fx.projectile_start(id, kind, p, v)


func proj_end_all(id: int) -> void:
	if fx:
		fx.projectile_end(id)
	if _has_peers():
		r_proj_end.rpc(id)


@rpc("authority", "reliable")
func r_proj_end(id: int) -> void:
	if fx:
		fx.projectile_end(id)


func frag_all(id: int, data: PackedInt64Array) -> void:
	_spawn_frag(id, data)
	if _has_peers():
		r_frag.rpc(id, data)


@rpc("authority", "reliable")
func r_frag(id: int, data: PackedInt64Array) -> void:
	if welcome_done:
		_spawn_frag(id, data)


var frag_nodes: Dictionary = {}

func _spawn_frag(id: int, data: PackedInt64Array) -> void:
	var f := Fragment.new()
	add_child(f)
	f.setup(self, id, data)
	frag_nodes[id] = f


func frag_break_all(id: int) -> void:
	_break_frag(id)
	if _has_peers():
		r_frag_break.rpc(id)


@rpc("authority", "reliable")
func r_frag_break(id: int) -> void:
	_break_frag(id)


func _break_frag(id: int) -> void:
	var f: Fragment = frag_nodes.get(id)
	if f == null:
		return
	frag_nodes.erase(id)
	if fx:
		fx.debris_from_fragment(f)
	f.queue_free()


func broadcast_state(st: Array) -> void:
	state = st
	if hud:
		hud.on_state()
	if _has_peers():
		r_state.rpc(st)


@rpc("authority", "reliable")
func r_state(st: Array) -> void:
	state = st
	if hud:
		hud.on_state()


func snapshot_all(buf: PackedByteArray, wheels: PackedFloat32Array, arrows: PackedFloat32Array) -> void:
	_apply_snapshot(buf, wheels, arrows)
	if _has_peers():
		r_snapshot.rpc(buf.compress(FileAccess.COMPRESSION_FASTLZ), buf.size(), wheels, arrows)


@rpc("authority", "unreliable_ordered")
func r_snapshot(data: PackedByteArray, raw_size: int, wheels: PackedFloat32Array, arrows: PackedFloat32Array) -> void:
	if not welcome_done:
		return
	var buf := data.decompress(raw_size, FileAccess.COMPRESSION_FASTLZ) if raw_size > 0 else PackedByteArray()
	_apply_snapshot(buf, wheels, arrows)


class VU:
	var id := 0
	var type := 0
	var team := 0
	var prev := Vector3.ZERO
	var cur := Vector3.ZERO
	var flags := 0
	var hp := 1.0
	var yaw := 0.0
	var prev_yaw := 0.0
	var phase := 0.0
	var stamp := 0


var _stamp := 0
var snap_interval := 0.1
var snap_time := 0.0

func _apply_snapshot(buf: PackedByteArray, wheels: PackedFloat32Array, arrows: PackedFloat32Array) -> void:
	_stamp += 1
	snap_time = Time.get_ticks_msec() / 1000.0
	var n := buf.size() / 12
	var o := 0
	for k in n:
		var id := buf.decode_u16(o)
		var u: VU = vunits.get(id)
		var p := Vector3(buf.decode_u16(o + 2) / 8.0, buf.decode_u16(o + 4) / 16.0, buf.decode_u16(o + 6) / 8.0)
		var yaw := buf[o + 11] / 255.0 * TAU
		if u == null:
			u = VU.new()
			u.id = id
			u.prev = p
			u.cur = p
			u.yaw = yaw
			u.phase = float(id) * 1.7
			vunits[id] = u
		else:
			u.prev = u.cur
			u.cur = p
		u.prev_yaw = u.yaw
		u.yaw = yaw
		var tt := buf[o + 8]
		u.type = tt >> 4
		u.team = tt & 15
		u.flags = buf[o + 9]
		u.hp = buf[o + 10] / 255.0
		u.stamp = _stamp
		o += 12
	if vunits.size() != n:
		for id: int in vunits.keys():
			var u: VU = vunits[id]
			if u.stamp != _stamp:
				if fx:
					fx.unit_died(u)
				vunits.erase(id)
	if fx:
		fx.update_wheels(wheels)
		fx.add_arrows(arrows)
	if is_server and "--campaign-log" in test_args:
		_campaign_log()
	# prova di coerenza del mondo tra server e client (solo nei test)
	if is_server and "--test-server" in test_args:
		_test_t += snap_interval
		if _test_t >= 5.0 and _has_peers():
			_test_t = 0.0
			r_check_hash.rpc(world.hash_world(), edit_log.size(), sim.ulist.size())


var _campaign_t := 0.0
func _campaign_log() -> void:
	_campaign_t += snap_interval
	if _campaign_t < 60.0 and sim.winner < 0:
		return
	_campaign_t = 0.0
	var counts := {}
	for c: Dictionary in castles:
		counts[c.owner] = int(counts.get(c.owner, 0)) + 1
	print("[campagna] t=%ds castelli=%s unita=%d modifiche=%d vincitore=%d" % [int(sim.time), str(counts), sim.ulist.size(), edit_log.size(), sim.winner])
	if sim.winner >= 0:
		get_tree().quit(0)


@rpc("authority", "reliable")
func r_check_hash(h: int, edits: int, units: int) -> void:
	if not welcome_done:
		return
	var mine := world.hash_world()
	var ok := mine == h
	if ok:
		_hash_ok += 1
	else:
		_hash_fail += 1
	print("[test] hash server=%d client=%d %s, modifiche=%d, unita=%d (viste %d)" % [h, mine, "OK" if ok else "DIVERSO", edits, units, vunits.size()])
	if "--test-client" in test_args and _hash_ok + _hash_fail >= 12:
		print("[test] RISULTATO ok=%d diversi=%d" % [_hash_ok, _hash_fail])
		get_tree().quit(0 if _hash_fail == 0 else 3)


## Dopo il test: esegue anche comandi via rete dal client di prova.
func _process(dt: float) -> void:
	if "--test-client" in test_args and welcome_done and my_house >= 0:
		_test_t += dt
		if _test_t > 4.0:
			_test_t = 0.0
			var cid := -1
			for i in castles.size():
				if state[0][i][0] == my_house:
					cid = i
					break
			if cid >= 0:
				send_cmd("recruit", [cid, Defs.CATAPULTA])
				var ids := PackedInt32Array()
				for id: int in vunits:
					if (vunits[id] as VU).team == my_house:
						ids.append(id)
				var target: Dictionary = castles[(cid + 1) % castles.size()]
				send_cmd("order", [ids, target.center, false])
				send_cmd("power", [Defs.P_MUCCHE, (target.center as Vector3) + Vector3(0, 10, 0)])


# ---------------------------------------------------------------- utilità client
func castle_at(p: Vector3, margin := 3.0) -> int:
	for c: Dictionary in castles:
		var ce: Vector3 = c.center
		if absf(p.x - ce.x) <= WorldGen.R + margin and absf(p.z - ce.z) <= WorldGen.R + margin:
			return c.id
	return -1


## La bandiera di raduno di un castello, o null se le reclute restano alla porta.
func castle_flag(id: int) -> Variant:
	if state.is_empty():
		return null
	var row: Array = state[0][id]
	return row[10] if row.size() > 10 else null


func castle_owner(id: int) -> int:
	if state.is_empty():
		return castles[id].start_house
	return state[0][id][0]


func gold() -> int:
	if state.is_empty() or my_house < 0:
		return 0
	return state[1][my_house][0]


## Fiorini al secondo spesi in riparazioni dalla mia casata.
func repair_spend() -> float:
	if state.is_empty() or my_house < 0 or (state[1][my_house] as Array).size() < 7:
		return 0.0
	return float(state[1][my_house][6])


## Edifici in piedi della propria casata (bit = tipo di edificio).
func shops() -> int:
	if state.is_empty() or my_house < 0 or (state[1][my_house] as Array).size() < 8:
		return 0
	return int(state[1][my_house][7])


## Edifici visti dal client: [id, tipo, padrone, x, z, base, fx, fz, avanzamento, in piedi].
func buildings() -> Array:
	return state[4] if state.size() > 4 else []


func building_at(p: Vector3) -> Array:
	var half := Buildings.FOOT / 2.0 + 0.5
	for b: Array in buildings():
		if absf(p.x - (float(b[3]) + 0.5)) <= half and absf(p.z - (float(b[4]) + 0.5)) <= half:
			return b
	return []


## Perché non si può costruire in p ("" = si può), con i dati che ha il client.
func spot_problem(p: Vector3) -> String:
	var owners: Array = []
	for c: Dictionary in castles:
		owners.append(castle_owner(c.id))
	var others: Array = []
	for b: Array in buildings():
		others.append([b[3], b[4]])
	return Buildings.check_spot(world, castles, owners, others, my_house, p)


## Storia: chi gioca può già usare questa cosa? Fuori dalla storia, o da client in rete, sempre sì.
func allowed(kind: String, id: Variant = null) -> bool:
	return sim == null or sim.allowed(my_house, kind, id)


func has_shop(type: int) -> bool:
	return (shops() >> type) & 1 == 1


func faith_rate() -> float:
	if state.is_empty() or my_house < 0 or (state[1][my_house] as Array).size() < 9:
		return 0.0
	return float(state[1][my_house][8])


func faith() -> int:
	if state.is_empty() or my_house < 0:
		return 0
	return state[1][my_house][1]
