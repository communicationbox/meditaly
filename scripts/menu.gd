extends Control
## Menu principale: dietro, l'Italia vera del gioco in voxel, con la telecamera che vola attorno al
## castello della casata scelta; davanti, titolo, stemmi delle casate e pochi pulsanti in ordine d'importanza.
## L'Italia generata qui si riusa per la partita (Game.prebuilt_*): si risparmiano i secondi di generazione.

signal tutorial(house: int, pname: String)
signal play_solo(house: int, pname: String)
signal host(house: int, pname: String, port: int)
signal join(ip: String, house: int, pname: String, port: int)
signal continue_game

var name_edit: LineEdit
var ip_edit: LineEdit
var house := 1
var house_title: Label
var house_sub: Label
var shield_btns: Array[Control] = []
var stat_bars: Array = []
var _logo: TextureRect
var friends_box: Control
var _loading: Control
var _loading_lbl: Label
var _load_bar: ColorRect
var _load_bar_bg: Control
var _load_pct: Label
var _load_tip: Label
var _load_shown := 0.0
var _tip_t := 0.0
var _tip_i := 0
var _near: Array = []  # pezzi d'Italia attorno alla telecamera: si mostra il menu quando sono disegnati
var _ready_t := -1.0
## Vero quando la schermata di caricamento è sparita e il menu si vede (i test aspettano questo).
var revealed := false
signal shown

const LOAD_STAGES := ["Srotolo la pergamena", "Disegno lo Stivale", "Alzo le Alpi e gli Appennini", "Scavo il Po", "Traccio le strade romane", "Riempio le valli", "Costruisco castelli e campanili", "Pianto ulivi e cipressi", "Do una spolverata", "Accendo il tramonto"]
const START_LINES := ["Sveglio il re", "Il re cerca la corona", "Lucido le corone", "Conto i fiorini", "Stappo la cantina", "Chiamo le nonne a raccolta"]
var _starting := false
const LOAD_TIPS := [
	"Il re si nasconde nel mastio. Trovalo.",
	"Alla sagra chi è a tavola non si tocca.",
	"Le nonne sono lente, ma col mattarello non perdonano.",
	"I frati pregano accanto alla chiesa. Quando non dormono.",
	"Tasti 6-0: sfottò agli amici, uno ogni 15 secondi.",
	"Ogni potere ha la sua bottega: se te la abbattono, lo perdi.",
	"Davanti al Parmigiano si scappa. Nella direzione sbagliata.",
	"Chi se ne sta tranquillo attira gli invidiosi.",
]
var _backdrop: Node3D
var _cam: Camera3D
var _cam_ang := 0.0
var _cam_focus := Vector3(Defs.WX * 0.4, 30, Defs.WZ * 0.2)
var _thread: Thread
var _world: VoxelWorld
var _castles: Array = []
var _world_ready := false

const LEFT_W := 620.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_scrim()
	_build_panel()
	_build_loading()
	select_house(house)
	_start_world()


# ---------------------------------------------------------------- sfondo: l'Italia in voxel
func _build_backdrop() -> void:
	_backdrop = Node3D.new()
	add_child(_backdrop)
	var env: Node3D = (load("res://scripts/environment.gd") as GDScript).new()
	_backdrop.add_child(env)
	# luce calda e bassa: il menu è un tramonto
	for n in env.get_children():
		if n is DirectionalLight3D:
			var sun := n as DirectionalLight3D
			sun.rotation_degrees = Vector3(-22, -60, 0)
			sun.light_color = Color(1.0, 0.78, 0.55)
			sun.light_energy = 1.5
		elif n is WorldEnvironment:
			var e: Environment = (n as WorldEnvironment).environment
			e.fog_light_color = Color(0.95, 0.78, 0.62)
			e.fog_density = 0.0009
			e.ambient_light_color = Color(0.72, 0.62, 0.6)
			e.adjustment_enabled = true
			e.adjustment_saturation = 1.12
			e.adjustment_contrast = 1.05
			var sm := e.sky.sky_material as ProceduralSkyMaterial
			sm.sky_top_color = Color(0.20, 0.32, 0.58)
			sm.sky_horizon_color = Color(0.98, 0.74, 0.52)
			sm.ground_horizon_color = Color(0.9, 0.7, 0.55)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_cam.far = 6000.0
	_backdrop.add_child(_cam)
	_cam.current = true
	_cam.global_position = _cam_focus + Vector3(0, 120, 200)


## Generazione in un thread: il menu resta vivo, intanto si vede la schermata d'attesa.
func _start_world() -> void:
	if Game.prebuilt_world != null and is_instance_valid(Game.prebuilt_world):
		_world = Game.prebuilt_world
		_castles = Game.prebuilt_castles
		_attach_world()
		return
	_world = VoxelWorld.new()
	_thread = Thread.new()
	_thread.start(func(): return WorldGen.generate(_world, Game.SEED))


func _attach_world() -> void:
	if _world.get_parent() != null:
		_world.get_parent().remove_child(_world)
	_backdrop.add_child(_world)
	_world_ready = true
	# i pezzi vicini alla telecamera per primi: l'Italia appare attorno ai castelli
	var order: Array = []
	var f := _focus_of(house)
	for k in VoxelWorld.CX * VoxelWorld.CZ:
		var cx := k % VoxelWorld.CX
		var cz := k / VoxelWorld.CX
		order.append([Vector2((cx + 0.5) * VoxelWorld.CH - f.x, (cz + 0.5) * VoxelWorld.CH - f.z).length(), k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e: Array in order:
		_world._dirty[e[1]] = true
	Game.prebuilt_world = _world
	Game.prebuilt_castles = _castles
	# il menu si mostra quando sono pronti i pezzi che la telecamera inquadra all'inizio
	_near.clear()
	for e: Array in order:
		if float(e[0]) < 300.0:
			_near.append(e[1])


## Prima di passare il mondo alla partita: se il thread lavora ancora, lo si aspetta.
func finish_world() -> void:
	if _thread != null and _thread.is_started():
		_castles = _thread.wait_to_finish()
		_thread = null
		if not _world_ready:
			_attach_world()


func _process(dt: float) -> void:
	if _thread != null and not _world_ready and not _thread.is_alive():
		_castles = _thread.wait_to_finish()
		_thread = null
		_attach_world()
	if _loading.visible and not revealed:
		_update_loading(dt)
	# volo lento attorno al castello scelto
	_cam_ang += dt * 0.06
	var target := _focus_of(house)
	_cam_focus = _cam_focus.lerp(target, minf(dt * 0.9, 1.0))
	var r := 165.0
	var want := _cam_focus + Vector3(cos(_cam_ang) * r, 72.0, sin(_cam_ang) * r)
	_cam.global_position = _cam.global_position.lerp(want, minf(dt * 1.2, 1.0))
	# si guarda un po' a sinistra del castello: così il castello sta nella metà destra, libera dal pannello
	var fwd := (_cam_focus - _cam.global_position)
	fwd.y = 0.0
	var right := fwd.normalized().cross(Vector3.UP)
	_cam.look_at(_cam_focus + Vector3(0, 6, 0) - right * 62.0, Vector3.UP)


func _focus_of(h: int) -> Vector3:
	for c: Dictionary in Defs.CASTLES:
		if int(c.house) == h:
			var g := Defs.geo(c.lon, c.lat)
			return Vector3(g.x, Defs.SEA + 6.0, g.y)
	return Vector3(Defs.WX * 0.5, 20, Defs.WZ * 0.5)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	# il mondo passa alla partita: non va liberato con il menu
	if _world != null and _world.get_parent() == _backdrop:
		_backdrop.remove_child(_world)


# ---------------------------------------------------------------- velo e pannello
func _build_scrim() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.035, 0.025, 0.94))
	grad.set_color(1, Color(0.05, 0.035, 0.025, 0.0))
	grad.add_point(0.55, Color(0.05, 0.035, 0.025, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	var scrim := TextureRect.new()
	scrim.texture = gt
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	scrim.visible = false  # ora la colonna è un cartello di legno
	scrim.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scrim.offset_right = LEFT_W + 380.0
	# vignettatura in basso, per la riga dei crediti e la profondità
	var g2 := Gradient.new()
	g2.set_color(0, Color(0, 0, 0, 0.0))
	g2.set_color(1, Color(0.03, 0.02, 0.01, 0.6))
	var gt2 := GradientTexture2D.new()
	gt2.gradient = g2
	gt2.fill_from = Vector2(0, 0)
	gt2.fill_to = Vector2(0, 1)
	gt2.width = 4
	gt2.height = 256
	var bot := TextureRect.new()
	bot.texture = gt2
	bot.stretch_mode = TextureRect.STRETCH_SCALE
	bot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -220


func _build_panel() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	m.offset_right = LEFT_W
	for side: String in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(side, 34)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	add_child(m)
	var sign_board := UiStyle.panel(18)
	sign_board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.add_child(sign_board)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	sign_board.add_child(v)
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/ui/logo.svg")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(0, 128)
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_logo)
	v.add_child(_gap(14))
	v.add_child(UiStyle.label("Scegli la tua casata", 18, UiStyle.GOLD, true))
	v.add_child(_gap(10))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	for i in Defs.HOUSE_COUNT:
		var s := HouseShield.new()
		s.house = i
		s.menu = self
		s.custom_minimum_size = Vector2(50, 62)
		s.tooltip_text = "%s · %s" % [Defs.HOUSES[i].name, Defs.HOUSES[i].city]
		sh.add_child(s)
		shield_btns.append(s)
	v.add_child(sh)
	v.add_child(_gap(10))
	house_title = UiStyle.label("", 38, UiStyle.INK, true)
	house_title.add_theme_font_override("font", UiStyle.display_font())
	house_title.add_theme_constant_override("outline_size", 8)
	v.add_child(house_title)
	house_sub = UiStyle.label("", 17, UiStyle.MUTED)
	v.add_child(house_sub)
	v.add_child(_gap(10))
	for k in Defs.STAT_NAMES.size():
		var row_s := HBoxContainer.new()
		row_s.add_theme_constant_override("separation", 10)
		var ln := UiStyle.label(String(Defs.STAT_NAMES[k]), 18, UiStyle.INK, true)
		ln.custom_minimum_size = Vector2(96, 0)
		row_s.add_child(ln)
		var bar := StatBar.new()
		bar.fill = StatBar.COLORS[k]
		bar.custom_minimum_size = Vector2(5 * StatBar.CUBE + 4 * StatBar.GAP, StatBar.CUBE)
		row_s.add_child(bar)
		v.add_child(row_s)
		v.add_child(_gap(4))
		stat_bars.append(bar)
	var eq := CheckBox.new()
	eq.text = "Casate uguali: stessi valori per tutti"
	eq.focus_mode = Control.FOCUS_NONE
	eq.add_theme_font_override("font", UiStyle.body_font())
	eq.add_theme_font_size_override("font_size", 16)
	eq.add_theme_color_override("font_color", UiStyle.INK)
	eq.add_theme_color_override("font_hover_color", UiStyle.GOLD)
	eq.add_theme_color_override("font_pressed_color", UiStyle.INK)
	eq.add_theme_icon_override("unchecked", _tick_icon(false))
	eq.add_theme_icon_override("checked", _tick_icon(true))
	eq.tooltip_text = "Spegne i caratteri delle casate: tutte con 3 cubetti per voce"
	eq.button_pressed = Settings.equal_houses
	eq.toggled.connect(func(on: bool) -> void:
		Settings.equal_houses = on
		Settings.save_all()
		_show_stats())
	v.add_child(eq)
	v.add_child(_gap(10))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Scrivi il tuo nome"
	name_edit.text = Settings.player_name
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(0, 40)
	_style_edit(name_edit)
	v.add_child(name_edit)
	v.add_child(_gap(14))
	var solo := _primary("Gioca contro l'IA", "Partita libera contro le altre casate")
	solo.pressed.connect(func(): _go(func(): play_solo.emit(house, name_edit.text)))
	v.add_child(solo)
	v.add_child(_gap(10))
	# sotto il pulsante principale, tutte le altre voci con lo stesso peso
	var more := GridContainer.new()
	more.columns = 2
	more.add_theme_constant_override("h_separation", 10)
	more.add_theme_constant_override("v_separation", 10)
	var sv := SaveGame.summary()
	if not sv.is_empty():
		var cont := _secondary("Continua", "%s, %d minuti di gioco · %s" % [Defs.HOUSES[int(sv.house)].name, int(sv.minutes), sv.date])
		cont.pressed.connect(func(): _go(func(): continue_game.emit(), false))
		more.add_child(cont)
	var tut := _secondary("Tutorial guidato", "Prima volta? Ti guida passo passo")
	tut.pressed.connect(func(): _go(func(): tutorial.emit(house, name_edit.text)))
	more.add_child(tut)
	var fr := _secondary("Gioca con gli amici", "Ospita una partita o entra in quella di un amico")
	fr.pressed.connect(func():
		friends_box.visible = not friends_box.visible
		_logo.visible = not friends_box.visible)  # il cartello resta tutto dentro lo schermo
	more.add_child(fr)
	var st := _secondary("Impostazioni", "Audio, schermo e difficoltà")
	st.pressed.connect(_open_settings)
	more.add_child(st)
	var ex := _secondary("Esci", "Chiude il gioco")
	ex.pressed.connect(func(): get_tree().quit())
	more.add_child(ex)
	for k: Node in more.get_children():
		(k as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(more)
	v.add_child(_gap(12))
	friends_box = _friends()
	friends_box.visible = false
	v.add_child(friends_box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)


func _friends() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var hostb := _secondary("Ospita una partita", "Gli altri entrano con il tuo indirizzo. Online serve aprire la porta UDP %d." % Defs.PORT)
	hostb.pressed.connect(func(): _go(func(): host.emit(house, name_edit.text, Defs.PORT)))
	box.add_child(hostb)
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 8)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Indirizzo di chi ospita"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.custom_minimum_size = Vector2(0, 40)
	_style_edit(ip_edit)
	jr.add_child(ip_edit)
	var jb := _secondary("Entra in partita", "Se la tua casata è già presa, ti viene assegnata un'altra")
	jb.custom_minimum_size.x = 170
	jb.pressed.connect(func(): _go(func(): join.emit(ip_edit.text.strip_edges(), house, name_edit.text, Defs.PORT)))
	jr.add_child(jb)
	box.add_child(jr)
	return box


## Schermata di caricamento: copre tutto (anche il pannello) finché l'Italia non è generata
## e i pezzi inquadrati non sono disegnati. Così il menu appare già con il paesaggio dietro.
func _build_loading() -> void:
	_loading = Control.new()
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP
	# il paesaggio vero del gioco, già dal primo fotogramma; sfuma nel menu con la stessa vista
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/splash.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# scuro in basso, dove stanno titolo e barra: il testo si legge su qualunque punto dell'immagine
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.035, 0.025, 0.0), Color(0.05, 0.035, 0.025, 0.25), Color(0.05, 0.035, 0.025, 0.86), Color(0.05, 0.035, 0.025, 0.96)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.offset_left = -260
	col.offset_right = 260
	col.offset_top = -470
	col.offset_bottom = -100
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var load_logo := TextureRect.new()
	load_logo.texture = load("res://assets/ui/logo.svg")
	load_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	load_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	load_logo.custom_minimum_size = Vector2(0, 240)
	load_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(load_logo)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)
	_loading_lbl = _caps(LOAD_STAGES[0].to_upper(), 19, UiStyle.INK, 3)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_loading_lbl)
	# barra: fondo scuro con bordo oro, riempimento oro
	_load_bar_bg = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.045)
	sb.border_color = UiStyle.GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	_load_bar_bg.add_theme_stylebox_override("panel", sb)
	_load_bar_bg.custom_minimum_size = Vector2(520, 8)
	_load_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_bar = ColorRect.new()
	_load_bar.color = UiStyle.GOLD
	_load_bar.position = Vector2(2, 2)
	_load_bar.size = Vector2(0, 4)
	_load_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_bar_bg.add_child(_load_bar)
	col.add_child(_load_bar_bg)
	_load_pct = UiStyle.label("0%", 18, UiStyle.MUTED)
	_load_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_load_pct)
	_loading.add_child(col)
	_load_tip = UiStyle.label(LOAD_TIPS[0], 15, UiStyle.MUTED)
	_load_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_load_tip.offset_left = -400
	_load_tip.offset_right = 400
	_load_tip.offset_top = -80
	_load_tip.offset_bottom = -50
	_load_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(_load_tip)
	_tip_i = randi() % LOAD_TIPS.size()
	_load_tip.text = LOAD_TIPS[_tip_i]
	add_child(_loading)


func _update_loading(dt: float) -> void:
	var gen := WorldGen.progress if not _world_ready else 1.0
	var stage: int = WorldGen.stage if not _world_ready else 9
	var near_left := 0
	if _world_ready:
		for k: int in _near:
			if _world._dirty.has(k) or _world._busy.has(k):
				near_left += 1
	var mesh := 1.0 - float(near_left) / maxf(_near.size(), 1.0) if _world_ready else 0.0
	var target := gen * 0.8 + mesh * 0.2
	# la barra non salta: insegue il valore vero, e fra una fase e l'altra avanza piano da sola
	_load_shown = minf(maxf(lerpf(_load_shown, target, minf(dt * 4.0, 1.0)), _load_shown + dt * 0.01), maxf(target, _load_shown))
	_load_bar.size.x = (_load_bar_bg.size.x - 4.0) * clampf(_load_shown, 0.0, 1.0)
	_load_pct.text = "%d%%" % int(clampf(_load_shown, 0.0, 1.0) * 100.0)
	_loading_lbl.text = String(LOAD_STAGES[clampi(stage, 0, LOAD_STAGES.size() - 1)]).to_upper()
	_tip_t += dt
	if _tip_t > 3.5:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % LOAD_TIPS.size()
		_load_tip.text = LOAD_TIPS[_tip_i]
	if _world_ready and near_left == 0:
		if _ready_t < 0.0:
			_ready_t = 0.0
		_ready_t += dt
		# qualche fotogramma in più: i pezzi appena installati devono comparire a schermo
		if _ready_t > 0.25:
			_reveal()


func _reveal() -> void:
	revealed = true
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_bar.size.x = _load_bar_bg.size.x - 4.0
	_load_pct.text = "100%"
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _loading.visible = false)
	shown.emit()


## Prima di cominciare: il mondo del menu deve essere pronto per passare alla partita.
func _go(start: Callable, need_name := true) -> void:
	if _starting:
		return  # doppio clic
	if need_name:
		var nm := name_edit.text.strip_edges()
		if nm == "":
			name_edit.grab_focus()
			name_edit.placeholder_text = "Scrivi prima il tuo nome!"
			name_edit.add_theme_color_override("font_placeholder_color", Color(0.72, 0.14, 0.12))
			return
		name_edit.text = nm
		Settings.player_name = nm
		Settings.save_all()
	_starting = true
	_show_starting()
	# prima si lascia disegnare la rotella, poi si prepara il mondo a piccole dosi
	await get_tree().process_frame
	await get_tree().process_frame
	finish_world()
	while not _world.prebuild_step():
		await get_tree().process_frame
	await get_tree().process_frame
	start.call()


## Schermata fra il clic su «gioca» e la partita: velo, rotella che gira, frase.
func _show_starting() -> void:
	var over := ColorRect.new()
	over.color = Color(0.05, 0.035, 0.025, 0.78)
	over.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -300
	col.offset_right = 300
	col.offset_top = -80
	col.offset_bottom = 80
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(col)
	var wheel := Spinner.new()
	wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(wheel)
	var lbl := _caps(String(START_LINES[randi() % START_LINES.size()]).to_upper(), 15, UiStyle.INK, 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)


func select_house(i: int) -> void:
	house = i
	var h: Dictionary = Defs.HOUSES[i]
	house_title.text = String(h.name)
	house_sub.text = "%s · %s" % [h.city, h.motto]
	_show_stats()
	for s in shield_btns:
		s.queue_redraw()


## Casella disegnata in oro: quella del tema, scura su scuro, non si vedeva.
func _tick_icon(on: bool) -> ImageTexture:
	var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	img.fill(UiStyle.OUTLINE)
	img.fill_rect(Rect2i(2, 2, 14, 14), Color(0.96, 0.89, 0.72))
	if on:
		img.fill_rect(Rect2i(5, 5, 8, 8), Color(0.72, 0.14, 0.12))
	return ImageTexture.create_from_image(img)


func _show_stats() -> void:
	for k in stat_bars.size():
		(stat_bars[k] as StatBar).set_value(3 if Settings.equal_houses else int(Defs.HOUSES[house].stats[k]))


func _open_settings() -> void:
	var p := Settings.SettingsPanel.new()
	add_child(p)
	p.closed.connect(p.queue_free)


# ---------------------------------------------------------------- stile
func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Maiuscolette spaziate (Optima con spaziatura fra le lettere).
func _caps(text: String, size: int, col: Color, spacing: int) -> Label:
	var fv := FontVariation.new()
	fv.base_font = load(UiStyle.FONT_UI)  # una variante di una variante perderebbe i caratteri di riserva
	fv.spacing_glyph = spacing
	var l := UiStyle.label(text, size, col, true)
	l.add_theme_font_override("font", fv)
	return l


func _primary(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 58)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiStyle.title_font())
	b.add_theme_font_size_override("font_size", 27)
	var n := _box(Color(1.0, 0.76, 0.22), UiStyle.OUTLINE, 3)
	n.border_width_bottom = 7
	var hv := n.duplicate() as StyleBoxFlat
	hv.bg_color = Color(1.0, 0.86, 0.38)
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.92, 0.66, 0.16)
	pr.border_width_bottom = 3
	pr.content_margin_top = 12.0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, Color(0.17, 0.09, 0.03))
	return b


func _secondary(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiStyle.title_font())
	b.add_theme_font_size_override("font_size", 19)
	UiStyle.style_button(b)
	return b


func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(11)
	sb.set_content_margin_all(8)
	return sb


func _style_edit(e: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.89, 0.72)
	sb.border_color = UiStyle.OUTLINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(9)
	e.add_theme_stylebox_override("normal", sb)
	var f := sb.duplicate() as StyleBoxFlat
	f.border_color = Color(0.72, 0.16, 0.13)
	f.set_border_width_all(3)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_font_override("font", UiStyle.body_font())
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", UiStyle.OUTLINE)
	e.add_theme_color_override("font_placeholder_color", Color(0.45, 0.32, 0.2))
	e.add_theme_color_override("caret_color", UiStyle.GOLD)


## Filetto d'oro con un rombo al centro, sotto il titolo.
## Barra a cinque cubetti del carattere di una casata.
class StatBar:
	extends Control
	const CUBE := 21.0
	const GAP := 5.0
	const COLORS := [Color(1.0, 0.76, 0.22), Color(0.86, 0.2, 0.16), Color(0.36, 0.78, 0.32), Color(0.36, 0.62, 0.98)]
	var value := 0
	var fill := Color.WHITE

	func set_value(v: int) -> void:
		value = v
		queue_redraw()

	func _draw() -> void:
		for i in 5:
			var r := Rect2(i * (CUBE + GAP), 0.0, CUBE, CUBE)
			draw_rect(r, fill if i < value else Color(0.38, 0.23, 0.11))
			if i < value:  # luce in alto: il cubetto ha volume, come quelli del mondo
				draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(CUBE - 6, 4)), fill.lightened(0.45))
			draw_rect(r, UiStyle.OUTLINE, false, 2.5)


## Stendardo rosso a coda di rondine con il nome del gioco: il primo segno che si vede.
class TitleBanner:
	extends Control
	const TITLE := "Signori d'Italia"

	func _init() -> void:
		custom_minimum_size = Vector2(0, 98)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var t := 6.0
		var b := h - 10.0
		var pts := PackedVector2Array([Vector2(0, t), Vector2(w, t), Vector2(w - 26, (t + b) * 0.5), Vector2(w, b), Vector2(0, b), Vector2(26, (t + b) * 0.5)])
		draw_colored_polygon(pts + PackedVector2Array(), Color(0.72, 0.13, 0.12))
		draw_rect(Rect2(14, t + 3, w - 28, 7), Color(0.88, 0.27, 0.2))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, UiStyle.OUTLINE, 4.0, true)
		var f: Font = UiStyle.display_font()
		var fs := 58
		while fs > 30 and f.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 70.0:
			fs -= 1
		var sz := f.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2((w - sz.x) * 0.5, (t + b) * 0.5 + f.get_ascent(fs) * 0.36)
		draw_string_outline(f, pos + Vector2(0, 2), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 11, UiStyle.OUTLINE)
		draw_string(f, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.GOLD)


class Ornament:
	extends Control
	var centered := false  # nel caricamento sta al centro; nel pannello del menu segue il titolo a sinistra

	func _init() -> void:
		custom_minimum_size = Vector2(0, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var w := minf(size.x, 420.0)
		var x0 := (size.x - w) * 0.5 if centered else 0.0
		var col := Color(0.93, 0.72, 0.30, 0.8)
		draw_line(Vector2(x0, y), Vector2(x0 + w * 0.5 - 12, y), col, 1.0, true)
		draw_line(Vector2(x0 + w * 0.5 + 12, y), Vector2(x0 + w, y), col, 1.0, true)
		var c := Vector2(x0 + w * 0.5, y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(7, 0), c + Vector2(0, 6), c + Vector2(-7, 0)]), col)
		draw_circle(Vector2(x0, y), 2.0, col)
		draw_circle(Vector2(x0 + w, y), 2.0, col)


## Rotella di attesa: dodici punti dorati che girano a scatti.
class Spinner:
	extends Control
	const N := 12
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		t += dt
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var head := int(t * 14.0) % N
		for k in N:
			var a := TAU * float(k) / N - PI * 0.5
			var age := posmod(head - k, N)
			var f := 1.0 - float(age) / N
			draw_circle(c + Vector2(cos(a), sin(a)) * 28.0, 2.5 + 3.5 * f, Color(0.96, 0.75, 0.32, 0.15 + 0.85 * f))


## Stemma cliccabile di una casata: si alza al passaggio, quello scelto brilla d'oro.
class HouseShield:
	extends Control
	var house := 0
	var menu: Control
	var hover := false

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hover = true
			queue_redraw())
		mouse_exited.connect(func():
			hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			menu.select_house(house)
			accept_event()

	func _draw() -> void:
		var chosen: bool = menu.house == house
		var lift := -6.0 if chosen else (-3.0 if hover else 0.0)
		var w := size.x
		var h := size.y
		var o := Vector2(0, lift)
		var pts := PackedVector2Array([o + Vector2(0, 0), o + Vector2(w, 0), o + Vector2(w, h * 0.55), o + Vector2(w * 0.5, h), o + Vector2(0, h * 0.55)])
		var col: Color = Defs.HOUSES[house].color
		if chosen:
			for k in 3:
				var g := PackedVector2Array()
				for p in pts:
					g.append(p + (p - (o + Vector2(w * 0.5, h * 0.45))).normalized() * (3.0 + k * 3.0))
				draw_colored_polygon(g, Color(1.0, 0.8, 0.35, 0.16 - k * 0.04))
		draw_colored_polygon(pts, col.darkened(0.0 if (chosen or hover) else 0.12))
		# riflesso in alto a sinistra e ombra in basso: lo stemma ha volume
		draw_colored_polygon(PackedVector2Array([o + Vector2(3, 3), o + Vector2(w * 0.5, 3), o + Vector2(w * 0.5, h * 0.5), o + Vector2(3, h * 0.5)]), Color(1, 1, 1, 0.12))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, UiStyle.GOLD if chosen else UiStyle.OUTLINE, 4.0 if chosen else 3.0, true)
		var letter := String(Defs.HOUSES[house].name).substr(0, 1)
		var f: Font = UiStyle.display_font()
		var fs := 27
		var tw := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ink := Color(0.12, 0.08, 0.05, 0.85) if col.get_luminance() > 0.55 else Color(1, 0.95, 0.85, 0.92)
		draw_string(f, o + Vector2((w - tw) * 0.5, h * 0.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
