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
## Il trono a molla spara il re così in alto che sotto resta un'Italia piccolissima.
## Quanto dura, fuori dal castello, ogni uscita di scena (0 è il volo col gabinetto).
const EXIT_TIMES := [2.4, 4.4, 5.0, 4.6, 5.0, 8.5, 4.6, 3.8, 4.8, 5.4]
const CHASE_VARIANT := 5  # la camicia da notte si guarda dall'alto
const SKY_VARIANT := 2
const SKY_TIME := 5.0
const SKY_HEIGHT := 3000.0
const SKY_BACK := 500.0
const SKY_KING_GAP := 80.0
const SKY_FAR := 9000.0


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
func king_cinematic(c: Dictionary, was: int, variant := 0) -> void:
	if not cine.is_empty():
		return
	if stage == null:
		stage = KingStage.new()
		game.add_child(stage)
		stage.setup(game.renderer.unit_material)
	stage.show_for(was, variant)
	cine = {"t": 0.0, "c": c, "v": variant, "end": CINE_CLOSE + exit_time(variant), "far": cam.far}
	if game.hud:
		var who := Defs.castle_boss(c, game.castle_owner(c.id)).capitalize()
		game.hud.letterbox(true, String(Defs.KING_DEATHS[clampi(variant, 0, Defs.KING_DEATHS.size() - 1)]) % [who, c.name])


func end_cinematic() -> void:
	if cine.is_empty():
		return
	var c: Dictionary = cine.c
	cam.far = float(cine.far)
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


static func exit_time(variant: int) -> float:
	return float(EXIT_TIMES[clampi(variant, 0, EXIT_TIMES.size() - 1)])


func sky_camera() -> Vector3:
	return Vector3(Defs.WX * 0.5, SKY_HEIGHT, Defs.WZ * 0.5 + SKY_BACK)


## Dove finisce il re: appena sotto la telecamera, sopra il centro della penisola.
func sky_king_end() -> Vector3:
	var from := sky_camera()
	return from + (Vector3(Defs.WX * 0.5, 0.0, Defs.WZ * 0.5) - from).normalized() * SKY_KING_GAP


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
		var look_want: Vector3 = fk.global_position + Vector3(0, 2.6, 0) if fk else kp + Vector3(0, 20, 0)
		if not cine.has("look"):
			cine.look = look_want
		cine.look = (cine.look as Vector3).lerp(look_want, minf(dt * 9.0, 1.0))  # segue senza strappi
		look = cine.look
		var v_now := int(cine.v)
		var want := look + dir * 16.0 + side * 6.0 + Vector3(0, 5.0, 0)
		if v_now == 9:  # il conto: da dietro le spalle, per vedere il rotolo che non finisce mai
			want = look - dir * 15.0 + side * 13.0 + Vector3(0, 15.0, 0)
			look += dir * 9.0
		elif v_now == 8:  # di fronte, abbastanza lontano da tenere in quadro il re e la sua nuvoletta
			look += Vector3(0, 2.6, 0)
			want = look + dir * 26.0 + side * 2.0 + Vector3(0, 0.5, 0)
			want.y = maxf(want.y, float(game.world.top_y(int(want.x), int(want.z))) + 3.0)
		elif v_now == 6 or v_now == 7:  # di fronte e bassa: chi scappa corre verso di noi
			look -= dir * 5.0
			want = look + dir * 24.0 + side * 3.0 + Vector3(0, 3.0 if v_now == 6 else 8.0, 0)  # con la 7 sopra gli alberi
			want.y = maxf(want.y, float(game.world.top_y(int(want.x), int(want.z))) + 3.0)
		elif v_now != 0:  # più in alto, sopra le chiome degli alberi
			want = look + dir * 15.0 + side * 5.0 + Vector3(0, 13.0, 0)
		if not cine.has("chase"):
			cine.chase = want
		cine.chase = (cine.chase as Vector3).lerp(want, minf(dt * 4.0, 1.0))
		pos = cine.chase
	var up := Vector3.UP
	if t >= CINE_CLOSE and int(cine.v) == SKY_VARIANT and game.fx and is_instance_valid(game.fx.flying_king):
		# verso l'alto: «su» è il nord, così la vista non si ribalta quando guarda dritto in verticale
		# un'unica ripresa: lo si vede partire di lato, la telecamera lo supera e guarda giù
		var k := clampf((t - CINE_CLOSE) / SKY_TIME, 0.0, 1.0)
		var king_p: Vector3 = game.fx.flying_king.global_position
		var side_off := dir * 55.0 + side * 22.0 + Vector3(0, -6, 0)
		var over_off := sky_camera() - sky_king_end()
		pos = king_p + side_off.lerp(over_off, smoothstep(0.12, 0.55, k))
		look = king_p.lerp(Vector3(Defs.WX * 0.5, 0.0, Defs.WZ * 0.5), smoothstep(0.55, 1.0, k))
		# guardando dritto in giù «su» diventa il nord, così la vista non si ribalta
		up = Vector3.UP.lerp(Vector3(0, 0, -1), smoothstep(0.55, 0.9, absf((look - pos).normalized().y))).normalized()
		cam.far = SKY_FAR
	if t >= CINE_CLOSE and int(cine.v) == CHASE_VARIANT:
		# prima da terra, davanti al portone; poi la telecamera si alza e li guarda girare in tondo
		var f := clampf((t - CINE_CLOSE) / exit_time(CHASE_VARIANT), 0.0, 1.0)
		var rise := smoothstep(0.26, 0.5, f)
		var low: Vector3 = (c.gate_out as Vector3) + dir * 34.0 + side * 15.0 + Vector3(0, 8.0, 0)
		pos = low.lerp((c.center as Vector3) + Vector3(0, 135.0, 38.0), rise)
		var runner: Vector3 = game.fx.flying_king.global_position if game.fx and is_instance_valid(game.fx.flying_king) else c.gate_out
		look = (runner + Vector3(0, 2.0, 0)).lerp(c.center, rise)
		up = Vector3.UP.lerp(Vector3(0, 0, -1), smoothstep(0.55, 0.9, absf((look - pos).normalized().y))).normalized()
	cam.look_at_from_position(pos, look, up)
	if t >= float(cine.end):
		end_cinematic()


## Il puntatore fuori dalla finestra non deve far scorrere: resterebbe fermo sull'ultimo bordo toccato.
var _mouse_in := DisplayServer.get_name() != "headless"  # senza finestra non c'è mouse: niente scorrimento ai bordi


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
		"special": return Sim.SPECIAL_R
		"mangano": return 4.0
		"oil": return 7.0
		"build": return Buildings.FOOT * 0.72
	return 0.0


## La forma di Parmigiano si lancia a mano: si preme dove parte, si trascina verso dove deve
## andare, e la lunghezza del vettore è la potenza. Un clic senza trascinare resta il tiro automatico.
var aim: Dictionary = {}
var aim_arrow: Node3D
var aim_mat: StandardMaterial3D
var _aim_shaft: MeshInstance3D
var _aim_head: MeshInstance3D


func _is_wheel_pending() -> bool:
	return String(pending.get("kind", "")) == "power" and int(pending.get("id", -1)) == Defs.P_PARMIGIANO


func _aim_begin() -> void:
	var hit := _ray()
	if hit.get("hit", false):
		aim = {"start": hit.point, "vec": Vector3.ZERO}


func _aim_release() -> void:
	var v: Vector3 = aim.vec
	var start: Vector3 = aim.start
	aim = {}
	if v.length() >= Sim.WHEEL_AIM_MIN:
		game.send_cmd("power_aim", [Defs.P_PARMIGIANO, start, v])
	else:
		game.send_cmd("power", [Defs.P_PARMIGIANO, start])
	pending = {}


## Da 0 a 1: quanta potenza dà il vettore attuale.
func aim_power() -> float:
	if aim.is_empty():
		return 0.0
	return clampf(((aim.vec as Vector3).length() - Sim.WHEEL_AIM_MIN) / (Sim.WHEEL_AIM_MAX - Sim.WHEEL_AIM_MIN), 0.0, 1.0)


func _update_aim_arrow() -> void:
	if aim.is_empty():
		if aim_arrow:
			aim_arrow.visible = false
		return
	var hit := _ray()
	if hit.get("hit", false):
		var v: Vector3 = (hit.point as Vector3) - (aim.start as Vector3)
		v.y = 0.0
		aim.vec = v.limit_length(Sim.WHEEL_AIM_MAX)
	if aim_arrow == null:
		aim_arrow = Node3D.new()
		game.add_child(aim_arrow)
		aim_mat = StandardMaterial3D.new()
		aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		aim_mat.no_depth_test = true
		_aim_shaft = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.5, 1.0)
		_aim_shaft.mesh = box
		_aim_shaft.material_override = aim_mat
		aim_arrow.add_child(_aim_shaft)
		_aim_head = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.4
		cone.height = 7.0
		_aim_head.mesh = cone
		_aim_head.material_override = aim_mat
		_aim_head.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		aim_arrow.add_child(_aim_head)
	var vec: Vector3 = aim.vec
	var len_v := maxf(vec.length(), 0.5)
	aim_arrow.visible = true
	aim_arrow.global_position = (aim.start as Vector3) + Vector3(0, 3.0, 0)
	aim_arrow.rotation = Vector3(0.0, atan2(vec.x, vec.z), 0.0)
	_aim_shaft.scale = Vector3(1.8, 1.0, len_v)
	_aim_shaft.position = Vector3(0, 0, len_v * 0.5)
	_aim_head.position = Vector3(0, 0, len_v + 3.0)
	aim_mat.albedo_color = Color(0.3, 0.95, 0.3).lerp(Color(1.0, 0.18, 0.1), aim_power())


func _update_marker() -> void:
	_update_aim_arrow()
	if pending.is_empty() or not aim.is_empty():
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


## Il potere della casata: quelli che agiscono su di te partono subito, gli altri chiedono dove.
func start_special() -> void:
	var h: int = game.my_house
	if h < 0 or h >= Defs.HOUSE_COUNT:
		return
	if bool(Defs.HOUSE_POWERS[h].self):
		game.send_cmd("special", [focus])
	else:
		pending = {"kind": "special", "id": h}


func start_action(kind: String, id: int) -> void:
	if kind == "power" and not game.has_shop(Defs.POWER_BUILDING[id]):
		if game.hud:
			game.hud.notify("%s: serve %s in un tuo castello" % [Defs.POWERS[id].name, Defs.BUILDINGS[Defs.POWER_BUILDING[id]].name], UiStyle.DANGER_TEXT)
		return
	pending = {"kind": kind, "id": id}


## Salta la scena del re un tasto normale o un clic. Le combinazioni con Cmd, Ctrl, Alt e i soli
## tasti modificatori no: Cmd+Maiusc+4, per esempio, serve a fare uno screenshot.
static func skips_cinematic(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if not event is InputEventKey:
		return false
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.meta_pressed or k.ctrl_pressed or k.alt_pressed:
		return false
	return not k.keycode in [KEY_SHIFT, KEY_META, KEY_CTRL, KEY_ALT, KEY_CAPSLOCK]


## Tab passa da un tuo castello all'altro. Va preso prima dell'interfaccia: in Godot Tab sposterebbe
## il fuoco tra i pulsanti, e il tasto non arriverebbe mai qui sotto.
func _input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo or ke.physical_keycode != KEY_TAB:
		return
	if game == null or game.hud == null or (game.hud.paper_layer != null and is_instance_valid(game.hud.paper_layer)):
		return
	get_viewport().set_input_as_handled()
	if game.allowed("groups"):
		cycle_castle(-1 if ke.shift_pressed else 1)


func _unhandled_input(event: InputEvent) -> void:
	if not cine.is_empty():
		if skips_cinematic(event):
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
				if _is_wheel_pending():
					_aim_begin()
				elif not pending.is_empty():
					_confirm_action()
				else:
					dragging = true
					drag_start = e.position
					drag_now = e.position
			elif not aim.is_empty():
				_aim_release()
			elif dragging:
				dragging = false
				_finish_selection(e.position, e.shift_pressed, e.ctrl_pressed or e.meta_pressed)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if not pending.is_empty():
				pending = {}
				aim = {}
			else:
				_give_order()
	elif event is InputEventMouseMotion:
		if dragging:
			drag_now = (event as InputEventMouseMotion).position
		if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			yaw -= (event as InputEventMouseMotion).relative.x * 0.005
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke := event as InputEventKey
		# il meno va riconosciuto dal carattere: sulla tastiera italiana sta su un altro tasto fisico
		if ke.unicode == 45 or ke.keycode == KEY_MINUS or ke.keycode == KEY_KP_SUBTRACT:
			game.hud.toggle_debug()
			return
		var digit := _digit(ke.physical_keycode)
		if digit >= 0 and game.allowed("groups"):
			_on_group(digit, ke.ctrl_pressed or ke.meta_pressed, ke.shift_pressed)
			return
		if ke.physical_keycode == KEY_BACKSPACE and game.allowed("groups"):  # come Tab, per chi ci è abituato
			cycle_castle(-1 if ke.shift_pressed else 1)
			return
		_on_key(ke.physical_keycode)


## I tasti dei poteri, nell'ordine di Defs.POWERS: sotto la mano sinistra, accanto a WASD.
const POWER_KEYS: Array[Key] = [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B]
const POWER_KEY_NAMES := ["Z", "X", "C", "V", "B"]
const SPECIAL_KEY := KEY_F
const SPECIAL_KEY_NAME := "F"
## Toglie la bandiera di raduno del castello selezionato.
const RALLY_CLEAR_KEY := KEY_P
const RALLY_CLEAR_KEY_NAME := "P"


func _on_key(k: Key) -> void:
	var pk := POWER_KEYS.find(k)
	if pk >= 0 and game.allowed("power", pk):
		start_action("power", pk)
		return
	match k:
		SPECIAL_KEY:
			if game.allowed("special"): start_special()
		KEY_F2:
			select_army()
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
			if selected_castle >= 0 and game.allowed("defense", "garrison"): game.send_cmd("garrison", [selected_castle])
		KEY_R:
			if selected_castle >= 0 and game.allowed("defense", "repair"): game.send_cmd("repair", [selected_castle])
		KEY_M:
			if selected_castle >= 0 and game.allowed("defense", "mangano"): start_action("mangano", selected_castle)
		KEY_O:
			if selected_castle >= 0 and game.allowed("defense", "oil"): start_action("oil", selected_castle)
		KEY_F1:
			game.hud.toggle_help()
		KEY_H:
			game.hud.toggle_ui()
		RALLY_CLEAR_KEY:
			clear_flag()


# ---------------------------------------------------------------- gruppi e castelli, come in StarCraft
## Gruppi 1-0: Ctrl (o Cmd) + numero li assegna, Maiusc + numero aggiunge, il numero li riprende,
## due volte di fila porta la vista lì. Un gruppo può essere anche un castello.
var groups: Array = []
var _last_group := -1
var _last_group_ms := 0
const DOUBLE_TAP_MS := 350


static func _digit(k: Key) -> int:
	if k >= KEY_0 and k <= KEY_9:
		return (int(k) - int(KEY_0) + 9) % 10  # 1 → 0, …, 0 → 9
	return -1


func _on_group(n: int, assign: bool, add: bool) -> void:
	if groups.is_empty():
		groups.resize(10)
		for i in 10:
			groups[i] = {"units": [], "castle": -1}
	var g: Dictionary = groups[n]
	var sel: Dictionary = game.renderer.selected
	var label := str((n + 1) % 10)
	if assign or add:
		if not sel.is_empty():
			var ids: Array = g.units.duplicate() if add and g.castle < 0 else []
			for id: int in sel:
				if not id in ids:
					ids.append(id)
			groups[n] = {"units": ids, "castle": -1}
			_group_note("Gruppo %s: %d soldati" % [label, ids.size()])
		elif selected_castle >= 0 and game.castle_owner(selected_castle) == game.my_house:
			groups[n] = {"units": [], "castle": selected_castle}
			_group_note("Gruppo %s: %s" % [label, game.castles[selected_castle].name])
		return
	var now := Time.get_ticks_msec()
	var again := n == _last_group and now - _last_group_ms < DOUBLE_TAP_MS
	_last_group = n
	_last_group_ms = now
	if int(g.castle) >= 0:
		if game.castle_owner(int(g.castle)) != game.my_house:
			groups[n] = {"units": [], "castle": -1}
			return
		game.renderer.selected.clear()
		selected_castle = int(g.castle)
		if again:
			focus = (game.castles[selected_castle].center as Vector3)
		return
	var alive: Array = []
	for id: int in g.units:
		var vu: Game.VU = game.vunits.get(id)
		if vu != null and vu.team == game.my_house:
			alive.append(id)
	g.units = alive
	if alive.is_empty():
		return
	sel.clear()
	for id: int in alive:
		sel[id] = true
	selected_castle = -1
	if again:
		var c := Vector3.ZERO
		for id: int in alive:
			c += (game.vunits[id] as Game.VU).cur
		focus = c / alive.size()


func _group_note(t: String) -> void:
	if game.hud:
		game.hud.notify(t, UiStyle.INK, 1.5)


## Tab (o Backspace): il prossimo castello mio (Maiusc: il precedente), selezionato e inquadrato.
func cycle_castle(step: int) -> void:
	var mine: Array[int] = []
	for c: Dictionary in game.castles:
		if game.castle_owner(c.id) == game.my_house:
			mine.append(int(c.id))
	if mine.is_empty():
		return
	var at := mine.find(selected_castle)
	var next: int = mine[posmod(at + step, mine.size())] if at >= 0 else (mine[0] if step > 0 else mine[-1])
	game.renderer.selected.clear()
	selected_castle = next
	focus = (game.castles[next].center as Vector3)
	if game.hud:
		game.hud.flash_home(next)


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
		"special": game.send_cmd("special", [p])
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
		if selected_castle >= 0 and game.castle_owner(selected_castle) == game.my_house:
			_plant_flag()
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


## Clic destro con un tuo castello selezionato: pianta lì la bandiera di raduno delle sue reclute.
## Sul castello stesso la toglie.
func _plant_flag() -> void:
	var hit := _ray()
	if not hit.get("hit", false):
		return
	var p: Vector3 = hit.point
	if game.castle_at(p, 2.0) == selected_castle:
		clear_flag()
		return
	game.send_cmd("rally", [selected_castle, p])
	game.fx.flag_planted(p)


## Toglie la bandiera del castello selezionato: le reclute tornano ad aspettare alla porta.
func clear_flag() -> void:
	if selected_castle < 0 or game.castle_owner(selected_castle) != game.my_house:
		return
	if game.castle_flag(selected_castle) != null:
		game.fx.sfx.play_flat("boing", -12.0)
	game.send_cmd("rally_clear", [selected_castle])


var _last_click_ms := 0
var _last_click_at := Vector2.ZERO


func _finish_selection(at: Vector2, additive: bool, same_type := false) -> void:
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
		# doppio clic (o Ctrl+clic): tutti i soldati di quel tipo che si vedono sullo schermo
		var now := Time.get_ticks_msec()
		if now - _last_click_ms < DOUBLE_TAP_MS and at.distance_to(_last_click_at) < 12.0:
			same_type = true
		_last_click_ms = now
		_last_click_at = at
		if same_type:
			var screen := get_viewport().get_visible_rect()
			for u: Game.VU in game.vunits.values():
				if u.team == game.my_house and u.type == best.type and not cam.is_position_behind(u.cur) \
						and screen.has_point(cam.unproject_position(u.cur + Vector3(0, 1, 0))):
					sel[u.id] = true
		sel[best.id] = true
		selected_castle = -1
		return
	var hit := _ray()
	if hit.get("hit", false):
		selected_castle = game.castle_at(hit.point)
	else:
		selected_castle = -1
