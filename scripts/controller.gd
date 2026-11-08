class_name Controller
extends Node3D
## Telecamera RTS, selezione, ordini e mira di poteri e difese.

var game: Node
var cam: Camera3D
var focus := Vector3(Defs.WX / 2.0, 12, Defs.WZ / 3.0)
var dist := 95.0
var target_dist := 95.0
var yaw := 0.0
var selected_castle := -1
var dragging := false
var drag_start := Vector2.ZERO
var drag_now := Vector2.ZERO
var pending: Dictionary = {}
var marker: MeshInstance3D
var marker_mat: StandardMaterial3D
var order_marks: Array = []
var _rng := RandomNumberGenerator.new()
var zoom_rate := 9.0
var home_castle := -1
## Inquadratura del re ucciso: per qualche secondo la telecamera è sua. Si salta con un clic o un tasto.
var cine: Dictionary = {}
const CINE_CLOSE := 3.2
const CINE_END := 5.6


func setup(g: Node) -> void:
	game = g
	cam = Camera3D.new()
	cam.far = 4000.0 * Defs.MAP_SCALE
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 4
	marker = MeshInstance3D.new()
	marker.mesh = t
	marker_mat = StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Color(1, 0.8, 0.2)
	marker_mat.no_depth_test = true
	marker.material_override = marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	add_child(marker)
	focus_home()


func focus_home() -> void:
	if game.my_house < 0:
		return
	for c: Dictionary in game.castles:
		if game.castle_owner(c.id) == game.my_house:
			focus = (c.center as Vector3)
			selected_castle = c.id
			home_castle = c.id
			if game.hud:
				game.hud.flash_home(c.id)
			return


## All'avvio la vista parte dall'alto e scende sul castello: si vede subito dove si è in Italia.
func start_intro() -> void:
	# si parte col proprio castello selezionato, anche se un clic del menu è arrivato in ritardo
	if selected_castle < 0 and game.renderer.selected.is_empty() and home_castle >= 0:
		selected_castle = home_castle
	dist = 560.0 * Defs.MAP_SCALE
	target_dist = 85.0
	zoom_rate = 1.5


var stage: KingStage


## Il re sul gabinetto ripreso sul set (stesso stile del mastio, ma largo e illuminato),
## poi stacco sul mastio vero mentre il re vola via dal tetto.
func king_cinematic(c: Dictionary, was: int) -> void:
	if not cine.is_empty():
		return
	if stage == null:
		stage = KingStage.new()
		game.add_child(stage)
		stage.setup(game.renderer.unit_material)
	stage.show_for(was)
	cine = {"t": 0.0, "c": c}
	if game.hud:
		game.hud.letterbox(true, "%s di %s, sorpreso sul trono. Quello piccolo." % ["Il Podestà" if game.castle_owner(c.id) == Defs.NEUTRAL else "Il Re", c.name])


func end_cinematic() -> void:
	if cine.is_empty():
		return
	var c: Dictionary = cine.c
	cine = {}
	if stage:
		stage.hide_stage()
	if game.hud:
		game.hud.letterbox(false)
		# il gran finale: chi ha conquistato e chi ha perso lo vedono scritto in grande
		var own: int = game.castle_owner(c.id)
		if own == game.my_house:
			game.hud.banner("%s è tua!" % c.name, "+%d fiorini · i soldati festeggiano nel cortile" % int(Defs.CAPTURE_REWARD), c.center)
		elif own >= 0 and own < Defs.HOUSES.size():
			game.hud.banner("%s è caduta!" % c.name, "ora sventola la bandiera dei %s" % Defs.HOUSES[own].name, c.center)


func cine_castle() -> int:
	return int(cine.c.id) if not cine.is_empty() else -1


func _cine_tick(dt: float) -> void:
	cine.t = float(cine.t) + dt
	var t: float = cine.t
	var c: Dictionary = cine.c
	var kp: Vector3 = c.king
	var dir: Vector3 = c.dir
	var side := Vector3(-dir.z, 0, dir.x)
	var pos: Vector3
	var look: Vector3
	if t < CINE_CLOSE:
		# sul set: re intero, la telecamera gira piano da davanti verso il profilo
		# (da lì si capisce subito che è seduto sul gabinetto) e si avvicina un poco
		var k := smoothstep(0.0, 1.0, t / CINE_CLOSE)
		var ang := lerpf(0.25, 0.85, k)
		var d := lerpf(6.0, 4.6, k)
		pos = KingStage.POS + Vector3(sin(ang) * d, lerpf(2.4, 1.9, k), cos(ang) * d)
		look = KingStage.POS + Vector3(0, 1.2, 0)
	else:
		if stage and stage.visible:
			stage.hide_stage()
		# stacco sul mastio vero: la telecamera insegue il re che vola via dal tetto
		var fk: Node3D = game.fx.flying_king if game.fx and is_instance_valid(game.fx.flying_king) else null
		look = fk.global_position if fk else kp + Vector3(0, 20, 0)
		var want := look + dir * 16.0 + side * 6.0 + Vector3(0, 5.0, 0)
		if not cine.has("chase"):
			cine.chase = want
		cine.chase = (cine.chase as Vector3).lerp(want, minf(dt * 4.0, 1.0))
		pos = cine.chase
	cam.look_at_from_position(pos, look, Vector3.UP)
	if t >= CINE_END:
		end_cinematic()


## Il puntatore fuori dalla finestra non deve far scorrere: resterebbe fermo sull'ultimo bordo toccato.
var _mouse_in := true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in = true


const EDGE_PX := 10.0


## Direzione di scorrimento quando il puntatore è vicino al bordo della finestra.
func edge_pan(mp: Vector2, sz: Vector2) -> Vector2:
	var pan := Vector2.ZERO
	if mp.x < 0.0 or mp.y < 0.0 or mp.x > sz.x or mp.y > sz.y:
		return pan
	if mp.x < EDGE_PX: pan.x -= 1
	if mp.x > sz.x - EDGE_PX: pan.x += 1
	if mp.y < EDGE_PX: pan.y -= 1
	if mp.y > sz.y - EDGE_PX: pan.y += 1
	return pan


func _process(dt: float) -> void:
	if not cine.is_empty():
		_cine_tick(dt)
		return
	var pan := Vector2.ZERO
	if not _typing():
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): pan.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): pan.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): pan.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): pan.x += 1
		if Input.is_physical_key_pressed(KEY_Q): yaw += dt * 1.6
		if Input.is_physical_key_pressed(KEY_E): yaw -= dt * 1.6
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var sz := vp.get_visible_rect().size
	var paused: bool = game.hud != null and game.hud.pause_panel != null and game.hud.pause_panel.visible
	if _mouse_in and not paused and DisplayServer.window_is_focused():
		pan += edge_pan(mp, sz)
	var speed := dist * 1.15
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	focus += (right * pan.x + fwd * pan.y) * speed * dt
	focus.x = clampf(focus.x, 0.0, Defs.WX)
	focus.z = clampf(focus.z, 0.0, Defs.WZ)
	var ground := float(maxi(game.world.top_y(int(focus.x), int(focus.z)), Defs.SEA))
	focus.y = lerpf(focus.y, ground, minf(dt * 3.0, 1.0))
	dist = lerpf(dist, target_dist, minf(dt * zoom_rate, 1.0))
	if absf(dist - target_dist) < 3.0:
		zoom_rate = 9.0
	var pitch := lerpf(deg_to_rad(36.0), deg_to_rad(68.0), clampf((dist - 25.0) / 280.0, 0.0, 1.0))
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var pos := focus + back * dist
	var shake: float = game.fx.shake if game.fx else 0.0
	if shake > 0.0:
		pos += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 0.7
	# la telecamera resta sopra terreno e mura
	var above := float(game.world.top_y(int(pos.x), int(pos.z))) + 2.0
	if pos.y < above:
		pos.y = above
	cam.look_at_from_position(pos, focus, Vector3.UP)
	_update_marker()


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _pending_radius() -> float:
	match String(pending.get("kind", "")):
		"power":
			match int(pending.id):
				Defs.P_PARMIGIANO: return 5.0
				Defs.P_VINO: return 34.0
				Defs.P_TERREMOTO: return 24.0
				Defs.P_SCUDO: return 20.0
				Defs.P_MUCCHE: return 15.0
		"mangano": return 4.0
		"oil": return 7.0
		"build": return Buildings.FOOT * 0.72
	return 0.0


func _update_marker() -> void:
	if pending.is_empty():
		marker.visible = false
		return
	var hit := _ray()
	if not hit.get("hit", false):
		marker.visible = false
		return
	marker.visible = true
	marker.global_position = (hit.point as Vector3) + Vector3(0, 0.6, 0)
	var r := _pending_radius()
	marker.scale = Vector3(r, 0.4, r)
	if String(pending.kind) == "build":
		# verde dove si può costruire, rosso dove no
		var why: String = game.spot_problem(hit.point)
		marker_mat.albedo_color = Color(0.3, 1.0, 0.4) if why == "" else Color(1.0, 0.25, 0.2)
		pending.why = why
	else:
		marker_mat.albedo_color = Color(1, 0.8, 0.2)


func _ray() -> Dictionary:
	var mp := get_viewport().get_mouse_position()
	return game.world.raycast(cam.project_ray_origin(mp), cam.project_ray_normal(mp))


func start_action(kind: String, id: int) -> void:
	if kind == "power" and not game.has_shop(Defs.POWER_BUILDING[id]):
		if game.hud:
			game.hud.notify("%s: serve %s in un tuo castello" % [Defs.POWERS[id].name, Defs.BUILDINGS[Defs.POWER_BUILDING[id]].name], UiStyle.DANGER_TEXT)
		return
	pending = {"kind": kind, "id": id}


func _unhandled_input(event: InputEvent) -> void:
	if not cine.is_empty():
		if (event is InputEventKey and (event as InputEventKey).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
			end_cinematic()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom_rate = 9.0
			target_dist = maxf(target_dist * 0.88, 18.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom_rate = 9.0
			target_dist = minf(target_dist * 1.14, 800.0 * Defs.MAP_SCALE)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if not pending.is_empty():
					_confirm_action()
				else:
					dragging = true
					drag_start = e.position
					drag_now = e.position
			elif dragging:
				dragging = false
				_finish_selection(e.position, e.shift_pressed)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if not pending.is_empty():
				pending = {}
			else:
				_give_order()
	elif event is InputEventMouseMotion:
		if dragging:
			drag_now = (event as InputEventMouseMotion).position
		if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			yaw -= (event as InputEventMouseMotion).relative.x * 0.005
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_on_key((event as InputEventKey).physical_keycode)


func _on_key(k: Key) -> void:
	match k:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			start_action("power", int(k) - int(KEY_1))
		KEY_6, KEY_7, KEY_8, KEY_9:
			game.send_cmd("taunt", [int(k) - int(KEY_6)])
		KEY_0:
			game.send_cmd("taunt", [4])
		KEY_ESCAPE:
			# prima annulla mira e selezione; se non c'è niente da annullare apre la pausa
			if game.hud.build_menu.visible:
				game.hud.build_menu.visible = false
				return
			if pending.is_empty() and game.renderer.selected.is_empty() and selected_castle < 0:
				game.hud.toggle_pause()
			pending = {}
			game.renderer.selected.clear()
			selected_castle = -1
		KEY_SPACE:
			focus_home()
		KEY_T:
			select_army()
		KEY_G:
			if selected_castle >= 0: game.send_cmd("garrison", [selected_castle])
		KEY_R:
			if selected_castle >= 0: game.send_cmd("repair", [selected_castle])
		KEY_M:
			if selected_castle >= 0: start_action("mangano", selected_castle)
		KEY_O:
			if selected_castle >= 0: start_action("oil", selected_castle)
		KEY_F1:
			game.hud.toggle_help()
		KEY_H:
			game.hud.toggle_ui()


func select_army() -> void:
	game.renderer.selected.clear()
	for id: int in game.vunits:
		var vu: Game.VU = game.vunits[id]
		# T è la chiamata alle armi: i frati restano a pregare
		if vu.team == game.my_house and vu.type != Defs.FRATE:
			game.renderer.selected[id] = true
	selected_castle = -1


func _confirm_action() -> void:
	var hit := _ray()
	if not hit.get("hit", false):
		return
	var p: Vector3 = hit.point
	match String(pending.kind):
		"power": game.send_cmd("power", [int(pending.id), p])
		"mangano": game.send_cmd("mangano", [int(pending.id), p])
		"oil": game.send_cmd("oil", [int(pending.id), p])
		"build":
			var why: String = game.spot_problem(p)
			if why != "":
				if game.hud:
					game.hud.notify(why, UiStyle.DANGER_TEXT)
				return  # resta in modalità costruzione: si prova un altro punto
			game.send_cmd("build", [int(pending.id), p])
	pending = {}


func _give_order() -> void:
	var sel: Dictionary = game.renderer.selected
	if sel.is_empty():
		return
	var hit := _ray()
	if not hit.get("hit", false):
		return
	var p: Vector3 = hit.point
	var ids := PackedInt32Array()
	for id: int in sel:
		ids.append(id)
	var on_struct := false
	if not hit.get("water", false):
		var vx: Vector3i = hit.voxel
		var cid: int = game.castle_at(p, 1.0)
		if game.world.get_v(vx.x, vx.y, vx.z) >= Defs.STRUCT_MIN and cid >= 0 and game.castle_owner(cid) != game.my_house:
			on_struct = true
			p = Vector3(vx) + Vector3(0.5, 0.5, 0.5)
		# un edificio nemico: lo si abbatte
		var bb: Array = game.building_at(p)
		if not bb.is_empty() and int(bb[2]) != game.my_house:
			on_struct = true
			p = Vector3(vx) + Vector3(0.5, 0.5, 0.5)
	game.send_cmd("order", [ids, p, on_struct])
	game.fx.sfx.play("hit", p, -8.0, 0.2)
	for k in 10:
		var a := k * TAU / 10.0
		game.fx._spawn_debris(p + Vector3(cos(a) * 2.4, 0.6, sin(a) * 2.4), Vector3(-cos(a) * 3.0, 1.0, -sin(a) * 3.0), Color(1.0, 0.3, 0.2) if on_struct else Color(0.5, 1.0, 0.5), 0.5, 0.0, 0.3)


func _finish_selection(at: Vector2, additive: bool) -> void:
	var sel: Dictionary = game.renderer.selected
	var moved := at.distance_to(drag_start) > 8.0
	if not additive:
		sel.clear()
	if moved:
		var rect := Rect2(drag_start, Vector2.ZERO).expand(at)
		for u: Game.VU in game.vunits.values():
			if u.team != game.my_house or cam.is_position_behind(u.cur):
				continue
			if rect.has_point(cam.unproject_position(u.cur + Vector3(0, 1, 0))):
				sel[u.id] = true
		if not sel.is_empty():
			selected_castle = -1
		return
	# clic singolo: unità più vicina al cursore
	var best: Game.VU = null
	var bd := 26.0
	for u: Game.VU in game.vunits.values():
		if u.team != game.my_house or cam.is_position_behind(u.cur):
			continue
		var d := cam.unproject_position(u.cur + Vector3(0, 1, 0)).distance_to(at)
		if d < bd:
			bd = d
			best = u
	if best != null:
		sel[best.id] = true
		selected_castle = -1
		return
	var hit := _ray()
	if hit.get("hit", false):
		selected_castle = game.castle_at(hit.point)
	else:
		selected_castle = -1
