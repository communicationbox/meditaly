class_name Settings
extends RefCounted
## Impostazioni del giocatore (audio, schermo, difficoltà), salvate in user://impostazioni.cfg.

const PATH := "user://impostazioni.cfg"
## Difficoltà: quanto attacca l'IA, quanta rendita prende rispetto a un umano, quanto esercito può avere.
const DIFFS := [
	{"name": "Facile", "aggr": 0.6, "income": 0.6, "cap": 0.7, "desc": "L'IA attacca poco e raccoglie meno fiorini"},
	{"name": "Normale", "aggr": 1.0, "income": 0.8, "cap": 1.0, "desc": "Partita equilibrata"},
	{"name": "Difficile", "aggr": 1.5, "income": 1.0, "cap": 1.35, "desc": "L'IA è aggressiva, ricca e numerosa"},
]

static var volume := 0.8
static var muted := false
static var fullscreen := false
static var difficulty := 1
static var equal_houses := false
static var player_name := ""
static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		volume = clampf(float(cf.get_value("audio", "volume", volume)), 0.0, 1.0)
		muted = bool(cf.get_value("audio", "muto", muted))
		fullscreen = bool(cf.get_value("schermo", "intero", fullscreen))
		difficulty = clampi(int(cf.get_value("partita", "difficolta", difficulty)), 0, DIFFS.size() - 1)
		equal_houses = bool(cf.get_value("partita", "casate_uguali", equal_houses))
		player_name = String(cf.get_value("partita", "nome", player_name))
	apply()


static func save_all() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", volume)
	cf.set_value("audio", "muto", muted)
	cf.set_value("schermo", "intero", fullscreen)
	cf.set_value("partita", "difficolta", difficulty)
	cf.set_value("partita", "casate_uguali", equal_houses)
	cf.set_value("partita", "nome", player_name)
	cf.save(PATH)


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, muted or volume <= 0.001)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)


static func diff() -> Dictionary:
	return DIFFS[difficulty]


## Pannello delle impostazioni, uguale nel menu principale e nella pausa: velo scuro su tutto lo
## schermo, scheda al centro divisa in sezioni (Audio, Schermo, Difficoltà). Esc o clic fuori chiude.
class SettingsPanel:
	extends Control
	signal closed

	const W := 680.0
	var _diff_cards: Array[Button] = []

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.02, 0.015, 0.72)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
				closed.emit())
		add_child(dim)
		var card := PanelContainer.new()
		var sb := UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 0)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 26
		sb.content_margin_bottom = 26
		sb.border_width_top = 3
		sb.border_color = UiStyle.GOLD_DIM
		sb.shadow_size = 24
		sb.shadow_color = Color(0, 0, 0, 0.6)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(W, 0)
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		card.grow_horizontal = Control.GROW_DIRECTION_BOTH
		card.grow_vertical = Control.GROW_DIRECTION_BOTH
		add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		card.add_child(v)
		# intestazione
		var head := HBoxContainer.new()
		var title := UiStyle.label("Impostazioni", 32, UiStyle.GOLD, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var x := _flat_btn("✕", "Chiudi (Esc)")
		x.add_theme_font_size_override("font_size", 20)
		x.pressed.connect(func(): closed.emit())
		head.add_child(x)
		v.add_child(head)
		v.add_child(_rule())
		# audio
		v.add_child(_section("AUDIO"))
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 16)
		var vl := UiStyle.label("Volume", 20, UiStyle.INK)
		vl.custom_minimum_size.x = 150
		vrow.add_child(vl)
		var vol := _slider()
		vol.value = Settings.volume
		vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vrow.add_child(vol)
		var pct := UiStyle.label("%d%%" % int(Settings.volume * 100), 16, UiStyle.GOLD, true)
		pct.custom_minimum_size.x = 48
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vrow.add_child(pct)
		vol.value_changed.connect(func(val: float):
			Settings.volume = val
			pct.text = "%d%%" % int(round(val * 100))
			Settings.apply()
			Settings.save_all())
		v.add_child(vrow)
		v.add_child(_gap(10))
		v.add_child(_switch_row("Muto", "Spegne tutti i suoni", Settings.muted, func(on: bool):
			Settings.muted = on
			Settings.apply()
			Settings.save_all()))
		# schermo
		v.add_child(_section("SCHERMO"))
		v.add_child(_switch_row("Schermo intero", "Occupa tutto lo schermo", Settings.fullscreen, func(on: bool):
			Settings.fullscreen = on
			Settings.apply()
			Settings.save_all()))
		# difficoltà
		v.add_child(_section("DIFFICOLTÀ"))
		var dh := HBoxContainer.new()
		dh.add_theme_constant_override("separation", 10)
		for k in Settings.DIFFS.size():
			var c := _diff_card(k)
			dh.add_child(c)
			_diff_cards.append(c)
		v.add_child(dh)
		v.add_child(_gap(8))
		v.add_child(UiStyle.label("Vale dalla prossima partita.", 17, UiStyle.MUTED))
		v.add_child(_gap(22))
		# piede
		var foot := HBoxContainer.new()
		var hint := UiStyle.label("Le scelte si salvano da sole", 17, UiStyle.MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(hint)
		var done := UiStyle.button("Fatto", "Chiudi (Esc)", func(): closed.emit(), 150.0, 44.0)
		UiStyle.style_button(done, Color(1.0, 0.76, 0.22), UiStyle.OUTLINE, Color(1.0, 0.86, 0.38))
		for kk: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			done.add_theme_color_override(kk, Color(0.17, 0.09, 0.03))
		done.add_theme_font_override("font", UiStyle.title_font())
		done.add_theme_font_size_override("font_size", 23)
		foot.add_child(done)
		v.add_child(foot)
		_refresh_diff()
		# entra con una piccola dissolvenza
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.15)

	func _unhandled_key_input(e: InputEvent) -> void:
		if e.is_pressed() and (e as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			closed.emit()

	func _gap(h: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, h)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c

	func _rule() -> Control:
		var box := VBoxContainer.new()
		box.add_child(_gap(12))
		var r := ColorRect.new()
		r.color = Color(UiStyle.GOLD_DIM, 0.45)
		r.custom_minimum_size = Vector2(0, 1)
		box.add_child(r)
		return box

	## Titoletto di sezione in maiuscolette spaziate, come nel menu.
	func _section(t: String) -> Control:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.add_child(_gap(22))
		var l := UiStyle.label(t.capitalize(), 22, UiStyle.GOLD, true)
		box.add_child(l)
		box.add_child(_gap(10))
		return box

	func _flat_btn(t: String, tip: String) -> Button:
		var b := Button.new()
		b.text = t
		b.tooltip_text = tip
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_color_override("font_color", UiStyle.MUTED)
		b.add_theme_color_override("font_hover_color", UiStyle.GOLD)
		b.add_theme_color_override("font_pressed_color", UiStyle.GOLD)
		return b

	func _slider() -> HSlider:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(0, 28)
		s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.06, 0.04, 0.03)
		track.border_color = Color(UiStyle.GOLD_DIM, 0.6)
		track.set_border_width_all(1)
		track.set_corner_radius_all(4)
		track.content_margin_top = 4
		track.content_margin_bottom = 4
		var fill := StyleBoxFlat.new()
		fill.bg_color = UiStyle.GOLD_DIM
		fill.set_corner_radius_all(4)
		fill.content_margin_top = 4
		fill.content_margin_bottom = 4
		var fill_h := fill.duplicate() as StyleBoxFlat
		fill_h.bg_color = UiStyle.GOLD
		s.add_theme_stylebox_override("slider", track)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill_h)
		s.add_theme_icon_override("grabber", _knob(UiStyle.GOLD))
		s.add_theme_icon_override("grabber_highlight", _knob(Color(1.0, 0.86, 0.5)))
		return s

	## Pomello rotondo dorato con bordo scuro, disegnato al volo.
	static func _knob(c: Color) -> ImageTexture:
		var n := 20
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length()
				var a := clampf(n / 2.0 - d, 0.0, 1.0)
				var col := c if d < n / 2.0 - 2.0 else Color(0.18, 0.1, 0.04)
				img.set_pixel(x, y, Color(col, a))
		return ImageTexture.create_from_image(img)

	func _switch_row(t: String, sub: String, on: bool, cb: Callable) -> Control:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiStyle.label(t, 20, UiStyle.INK))
		col.add_child(UiStyle.label(sub, 17, UiStyle.MUTED))
		row.add_child(col)
		var sw := Switch.new()
		sw.button_pressed = on
		sw.toggled.connect(cb)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		return row

	## Tre schede affiancate: nome e due righe di spiegazione; quella scelta è dorata.
	func _diff_card(k: int) -> Button:
		var d: Dictionary = Settings.DIFFS[k]
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(0, 142)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 12
		inner.offset_right = -12
		inner.offset_top = 10
		inner.offset_bottom = -10
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 4)
		var n := UiStyle.label(d.name, 22, UiStyle.INK, true)
		inner.add_child(n)
		var ds := UiStyle.label(d.desc, 17, UiStyle.MUTED)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(ds)
		b.add_child(inner)
		b.set_meta("name_lbl", n)
		b.pressed.connect(func():
			Settings.difficulty = k
			Settings.save_all()
			_refresh_diff())
		return b

	func _refresh_diff() -> void:
		for k in _diff_cards.size():
			var b := _diff_cards[k]
			var sel := k == Settings.difficulty
			b.set_pressed_no_signal(sel)
			var bg := Color(0.52, 0.31, 0.11) if sel else Color(0.17, 0.095, 0.045)
			var bd := UiStyle.GOLD if sel else UiStyle.OUTLINE
			for st: String in ["normal", "pressed", "hover", "hover_pressed"]:
				var sbx := StyleBoxFlat.new()
				sbx.bg_color = bg if st != "hover" or sel else Color(0.26, 0.15, 0.07)
				sbx.border_color = bd if st != "hover" or sel else UiStyle.GOLD_DIM
				sbx.set_border_width_all(3)
				sbx.set_corner_radius_all(9)
				b.add_theme_stylebox_override(st, sbx)
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			(b.get_meta("name_lbl") as Label).add_theme_color_override("font_color", UiStyle.GOLD if sel else UiStyle.INK)


## Interruttore a pillola: grigio scuro spento, oro acceso, con il pomello che scorre.
class Switch:
	extends Button
	var _t := 0.0

	func _init() -> void:
		toggle_mode = true
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(52, 28)
		toggled.connect(func(_on: bool): set_process(true))

	func _ready() -> void:
		_t = 1.0 if button_pressed else 0.0

	func _process(dt: float) -> void:
		var want := 1.0 if button_pressed else 0.0
		_t = move_toward(_t, want, dt * 8.0)
		queue_redraw()
		if is_equal_approx(_t, want):
			set_process(false)

	func _draw() -> void:
		var r := Rect2(Vector2(0, (size.y - 26) / 2.0), Vector2(52, 26))
		var off := Color(0.46, 0.38, 0.30)
		var bg := off.lerp(Color(0.78, 0.58, 0.24), _t)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = UiStyle.OUTLINE if not is_hovered() else UiStyle.GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		draw_style_box(sb, r)
		var cx := lerpf(r.position.x + 13, r.end.x - 13, _t)
		draw_circle(Vector2(cx, r.get_center().y), 9.5, Color(0.15, 0.09, 0.04).lerp(Color(1, 0.95, 0.85), 0.25 + _t * 0.75))
