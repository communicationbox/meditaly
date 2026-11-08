class_name Hud
extends CanvasLayer
## Interfaccia di gioco. Principio: in ogni momento deve essere chiaro chi sei, dove sei e cosa fare ora.

const POWER_GLYPHS := ["parmigiano", "vino", "terremoto", "scudo", "mucche"]
const CARD_W := 102.0
const CARD_H := 46.0
const HINT_LIFE := 7.0

var game: Node
var root: Control
var shield: UiStyle.Shield
var house_lbl: Label
var gold_lbl: Label
var income_lbl: Label
var faith_lbl: Label
var faith_bar: ProgressBar
var castles_lbl: Label
var troops_lbl: Label
var home_btn: Button
var rank_rows: Array = []
var castle_panel: PanelContainer
var castle_shield: UiStyle.Shield
var castle_title: Label
var castle_info: Label
var integ_row: Control
var integ_bar: ProgressBar
var integ_lbl: Label
var cap_row: Control
var cap_bar: ProgressBar
var cap_lbl: Label
var queue_row: HBoxContainer
var queue_bar: ProgressBar
var enemy_hint: Label
var recruit_btns: Array[Button] = []
var recruit_cost: Array[Label] = []
var def_btns: Dictionary = {}
var def_lbls: Dictionary = {}
var recruit_box: Control
var def_box: Control
var build_box: Control
var build_btns: Array[Button] = []
var build_menu: PanelContainer
var shops_lbl: Label
var build_hint: Label
var tab_bar: Control
var tab_btns: Array[Button] = []
var castle_tab := 0
var build_counts: Array[Label] = []
var build_costs: Array[Label] = []
var build_glyphs: Array[Glyph] = []
var power_locks: Array[Glyph] = []
## Fila "le tue botteghe" sopra i poteri: icona e quante ne hai di ciascuna.
var shop_cells: Array[Control] = []
var shop_counts: Array[Label] = []
var shop_glyphs: Array[Glyph] = []
var faith_rate_lbl: Label
## Insegne sopra gli edifici nel mondo: [anello col colore del padrone, icona].
var _badges: Array = []
var _badge_tex: Dictionary = {}
var _ring_tex: Texture2D
var army_panel: PanelContainer
var army_lbl: Label
var army_counts: Array[Label] = []
var army_cells: Array[Control] = []
var army_grid: Control
var army_btn: Button
var power_btns: Array[Button] = []
var power_glyphs: Array[Glyph] = []
var power_cost: Array[Label] = []
var power_cd: Array[Label] = []
var hint_lbl: Label
var alert_btn: Button
var alert_castle := -1
## Castelli miei che erano sotto attacco al giro prima, e quando ho suonato l'ultimo allarme per ognuno.
var _attacked_prev := {}
var _alarm_flash := 0.0
var _owner_prev := {}
var _alarm_at := {}
const ALARM_GAP_MS := 20000
var truce_lbl: Label
var taunt_btns: Array[Button] = []
var taunt_lbl: Label
var notify_box: VBoxContainer
var minimap: Minimap
var drag_rect: Control
var tip: PanelContainer
var tip_lbl: Label
var _tip_t := 0.0
var help: PanelContainer
var victory: Label
var intro: PanelContainer
var labels: Array[Label3D] = []
var rings: Array[MeshInstance3D] = []
var ring_mats: Array[StandardMaterial3D] = []
var beam: MeshInstance3D
var _beam_t := 0.0
var _portrait_vps: Array[SubViewport] = []
var _portrait_frames := 4
var hud_hidden := false
var _hint_t := 0.0
var rank_box: HBoxContainer


func setup(g: Node) -> void:
	game = g
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_top_bar()
	_rank_panel()
	_castle_panel()
	_army_panel()
	_bottom_center()
	_minimap_panel()
	_alert()
	notify_box = VBoxContainer.new()
	# centrato in alto sotto il pulsante d'allarme (con "position" finiva a sinistra, sotto il pannello del tutorial)
	notify_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notify_box.offset_left = -340
	notify_box.offset_right = 340
	notify_box.offset_top = 92
	notify_box.custom_minimum_size = Vector2(680, 0)
	notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notify_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(notify_box)
	drag_rect = DragRect.new()
	drag_rect.ctrl = game.ctrl
	drag_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(drag_rect)
	_cursor_tip()
	_help()
	victory = UiStyle.label("", 56, UiStyle.INK, true)
	victory.set_anchors_preset(Control.PRESET_CENTER)
	victory.grow_horizontal = Control.GROW_DIRECTION_BOTH
	victory.grow_vertical = Control.GROW_DIRECTION_BOTH
	victory.add_theme_constant_override("outline_size", 12)
	victory.add_theme_color_override("font_outline_color", Color.BLACK)
	victory.visible = false
	root.add_child(victory)
	_world_marks()
	_make_badge_textures()
	on_state()
	if not "--demo" in game.test_args:
		_show_intro()


# ---------------------------------------------------------------- chi sei
func _top_bar() -> void:
	var p := UiStyle.panel(6)
	p.position = Vector2(8, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var who := Button.new()
	who.flat = true
	who.focus_mode = Control.FOCUS_NONE
	who.tooltip_text = "Vai al tuo castello (Spazio)"
	who.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	who.pressed.connect(func(): game.ctrl.focus_home())
	who.custom_minimum_size = Vector2(118, 28)
	shield = UiStyle.Shield.new()
	shield.position = Vector2(2, 2)
	shield.size = Vector2(19, 25)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(shield)
	house_lbl = UiStyle.label("", 18, UiStyle.INK, true)
	house_lbl.position = Vector2(28, 1)
	who.add_child(house_lbl)
	home_btn = who
	h.add_child(who)
	gold_lbl = UiStyle.label("", 18, UiStyle.GOLD, true)
	gold_lbl.tooltip_text = "Fiorini: servono per i soldati e le riparazioni"
	gold_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	income_lbl = UiStyle.label("", 12, UiStyle.MUTED)
	income_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(_pair(gold_lbl, income_lbl))
	faith_lbl = UiStyle.label("", 18, UiStyle.INK, true)
	faith_lbl.tooltip_text = "Fede: serve per i poteri (tasti 1-5)"
	faith_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	faith_rate_lbl = UiStyle.label("fede", 12, UiStyle.MUTED)
	faith_rate_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(_pair(faith_lbl, faith_rate_lbl))
	castles_lbl = UiStyle.label("", 18, UiStyle.INK, true)
	h.add_child(_pair(castles_lbl, UiStyle.label("castelli", 12, UiStyle.MUTED)))
	troops_lbl = UiStyle.label("", 18, UiStyle.INK, true)
	troops_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(_pair(troops_lbl, UiStyle.label("truppe", 12, UiStyle.MUTED)))
	truce_lbl = UiStyle.label("", 15, UiStyle.GOLD, true)
	truce_lbl.tooltip_text = "Tregua: le casate non si combattono fra loro, né soldati né torri né poteri. Le IA stanno ferme, tu puoi già prendere i castelli liberi"
	truce_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(truce_lbl)
	faith_bar = _bar(UiStyle.GOLD, 150.0, 3.0)
	root.add_child(p)


## Valore grande con la sua etichetta piccola accanto, sulla stessa riga.
func _pair(value: Label, unit: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(value)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit)
	return row


func _stat(title: String, value: Label, extra: Label, w: float) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(w, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UiStyle.label(title, 13, UiStyle.MUTED))
	if extra:
		row.add_child(extra)
	v.add_child(row)
	v.add_child(value)
	return v


func _bar(col: Color, max_v := 1.0, h := 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_v
	b.step = 0.01
	b.custom_minimum_size = Vector2(0, h)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := StyleBoxFlat.new()
	f.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.03)
	b.add_theme_stylebox_override("fill", f)
	b.add_theme_stylebox_override("background", bg)
	return b


func _rank_panel() -> void:
	var r := UiStyle.panel(6)
	r.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	r.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	r.offset_right = -8
	r.offset_top = 8
	rank_box = HBoxContainer.new()
	rank_box.add_theme_constant_override("separation", 9)
	r.add_child(rank_box)
	for i in 8:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var sw := UiStyle.Shield.new()
		sw.custom_minimum_size = Vector2(15, 20)
		sw.edge = Color(0, 0, 0, 0.5)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(sw)
		var cnt := UiStyle.label("", 16, UiStyle.INK, true)
		cell.add_child(cnt)
		rank_box.add_child(cell)
		rank_rows.append({"row": cell, "shield": sw, "count": cnt})
	root.add_child(r)


# ---------------------------------------------------------------- pannello castello
func _castle_panel() -> void:
	castle_panel = UiStyle.panel(8)
	castle_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	castle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	castle_panel.offset_left = 8
	castle_panel.offset_bottom = -8
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	castle_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	castle_shield = UiStyle.Shield.new()
	castle_shield.custom_minimum_size = Vector2(16, 21)
	castle_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(castle_shield)
	castle_title = UiStyle.label("", 18, UiStyle.INK, true)
	head.add_child(castle_title)
	castle_info = UiStyle.label("", 12, UiStyle.MUTED)
	castle_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(castle_info)
	v.add_child(head)
	integ_bar = _bar(Color(0.45, 0.72, 0.35), 1.0, 5.0)
	integ_lbl = UiStyle.label("", 12, UiStyle.MUTED)
	integ_row = _labeled_bar("Mura", integ_bar, integ_lbl)
	v.add_child(integ_row)
	cap_bar = _bar(UiStyle.DANGER, 1.0, 5.0)
	cap_lbl = UiStyle.label("", 12, UiStyle.DANGER_TEXT)
	cap_row = _labeled_bar("Conquista", cap_bar, cap_lbl)
	v.add_child(cap_row)
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 6)
	q.add_child(UiStyle.label("In arrivo", 12, UiStyle.MUTED))
	queue_bar = _bar(UiStyle.GOLD, 1.0, 5.0)
	queue_bar.custom_minimum_size.x = 60
	queue_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q.add_child(queue_bar)
	queue_row = HBoxContainer.new()
	q.add_child(queue_row)
	queue_row.set_meta("wrap", q)
	v.add_child(q)
	enemy_hint = UiStyle.label("", 13, UiStyle.INK)
	enemy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_hint.custom_minimum_size = Vector2(300, 0)
	v.add_child(enemy_hint)
	# schede: Truppe | Costruzioni (stesso posto, si passa dall'una all'altra)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	for k in 2:
		var tb := Button.new()
		tb.text = ["Truppe", "Costruzioni"][k]
		tb.tooltip_text = ["Recluta soldati in questo castello", "Chiese e botteghe fuori dalle mura: ogni potere ha la sua"][k]
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tb.custom_minimum_size = Vector2(CARD_W * 1.5 + 2.0, 32)
		tb.add_theme_font_override("font", UiStyle.title_font())
		tb.add_theme_font_size_override("font_size", 16)
		var off := StyleBoxFlat.new()
		off.bg_color = Color(0, 0, 0, 0.25)
		off.border_color = Color(0.58, 0.44, 0.20, 0.5)
		off.border_width_bottom = 1
		off.set_content_margin_all(4)
		var on := StyleBoxFlat.new()
		on.bg_color = Color(0.27, 0.19, 0.11)
		on.border_color = UiStyle.GOLD
		on.border_width_bottom = 3
		on.border_width_top = 1
		on.border_width_left = 1
		on.border_width_right = 1
		on.set_corner_radius_all(2)
		on.set_content_margin_all(4)
		tb.add_theme_stylebox_override("normal", off)
		tb.add_theme_stylebox_override("hover", on)
		tb.add_theme_stylebox_override("pressed", on)
		tb.add_theme_stylebox_override("hover_pressed", on)
		tb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tb.add_theme_color_override("font_color", UiStyle.MUTED)
		tb.add_theme_color_override("font_hover_color", UiStyle.INK)
		tb.add_theme_color_override("font_pressed_color", UiStyle.GOLD)
		tb.add_theme_color_override("font_hover_pressed_color", UiStyle.GOLD)
		tb.pressed.connect(_set_tab.bind(k))
		tabs.add_child(tb)
		tab_btns.append(tb)
	tab_bar = tabs
	v.add_child(tabs)
	var rg := GridContainer.new()
	rg.columns = 3
	rg.add_theme_constant_override("h_separation", 4)
	rg.add_theme_constant_override("v_separation", 4)
	recruit_box = rg
	for t in Defs.UNIT_TYPES:
		rg.add_child(_recruit_card(t))
	v.add_child(rg)
	# costruzioni: stessa griglia delle truppe, una scheda per edificio
	var bg := GridContainer.new()
	bg.columns = 3
	bg.add_theme_constant_override("h_separation", 4)
	bg.add_theme_constant_override("v_separation", 4)
	for k in Defs.BUILDING_COUNT:
		bg.add_child(_build_card(k))
	# stessa altezza della scheda Truppe (con la riga d'aiuto): passando da una all'altra il pannello non salta
	bg.custom_minimum_size.y = CARD_H * 3 + 8 - 22
	build_box = bg
	v.add_child(bg)
	shops_lbl = UiStyle.label("Scegli una bottega, poi clicca sul terreno fuori dalle mura", 12, UiStyle.MUTED)
	build_hint = shops_lbl
	v.add_child(shops_lbl)
	build_menu = PanelContainer.new()  # il vecchio riquadro a parte non c'è più: resta chiuso
	build_menu.visible = false
	root.add_child(build_menu)
	var dg := HBoxContainer.new()
	dg.add_theme_constant_override("separation", 4)
	def_box = dg
	_def_button(dg, "garrison", "mura", "Sulle mura", "G", "I balestrieri vicini salgono sulle mura e tirano più lontano", func(): game.send_cmd("garrison", [game.ctrl.selected_castle]))
	_def_button(dg, "repair", "ripara", "Ripara", "R", "Ricostruisce ciò che è crollato: 0,5 fiorini per blocco (più lenta sotto attacco)", func(): game.send_cmd("repair", [game.ctrl.selected_castle]))
	_def_button(dg, "mangano", "mangano", "Mangano", "M", "Tira una pietra dal mastio dove clicchi", func(): game.ctrl.start_action("mangano", game.ctrl.selected_castle))
	_def_button(dg, "oil", "olio", "Olio", "O", "Olio bollente attorno alle mura: 25 fiorini", func(): game.ctrl.start_action("oil", game.ctrl.selected_castle))
	v.add_child(dg)
	root.add_child(castle_panel)


func _labeled_bar(title: String, bar: ProgressBar, value: Label) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var t := UiStyle.label(title, 12, UiStyle.MUTED)
	t.custom_minimum_size = Vector2(54, 0)
	h.add_child(t)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	value.custom_minimum_size = Vector2(34, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	return h


func _recruit_card(t: int) -> Button:
	var d: Dictionary = Defs.UNITS[t]
	var b := UiStyle.button("", "%s: %d fiorini\n%s\nVita %d · Velocità %d" % [d.name, d.cost, d.desc, d.hp, int(d.speed)], _recruit.bind(t), CARD_W, CARD_H)
	var pic := _portrait(t, 40)
	pic.position = Vector2(2, 3)
	b.add_child(pic)
	var n := UiStyle.label(d.name, 11, UiStyle.INK)
	n.position = Vector2(42, 4)
	b.add_child(n)
	var c := UiStyle.label(str(d.cost), 16, UiStyle.GOLD, true)
	c.position = Vector2(42, 21)
	b.add_child(c)
	recruit_btns.append(b)
	recruit_cost.append(c)
	return b


func _portrait(t: int, px: int) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(px * 2, px * 2)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.82, 0.8)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var mesh: ArrayMesh = game.renderer.unit_meshes[t]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	var team: int = game.my_house if game.my_house >= 0 else Defs.NEUTRAL
	mm.set_instance_custom_data(0, Color(0, 0, 0, float(team)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = game.renderer.unit_material
	vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var box := mesh.get_aabb()
	cam.size = maxf(box.size.y, maxf(box.size.x, box.size.z)) * 1.08
	var c := box.get_center()
	vp.add_child(cam)
	add_child(vp)
	cam.look_at_from_position(c + Vector3(0.75, 0.45, 1.0).normalized() * 12.0, c, Vector3.UP)
	_portrait_vps.append(vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _def_button(parent: Control, key: String, glyph: String, text: String, hotkey: String, tip_text: String, cb: Callable) -> void:
	var b := UiStyle.button("", "%s [%s]\n%s" % [text, hotkey, tip_text], cb, 75.0, 30.0)
	var g := Glyph.new(glyph)
	g.position = Vector2(4, 5)
	g.size = Vector2(20, 20)
	b.add_child(g)
	var k := UiStyle.label(hotkey, 13, UiStyle.MUTED, true)
	k.position = Vector2(30, 5)
	b.add_child(k)
	def_btns[key] = b
	def_lbls[key] = k
	parent.add_child(b)


# ---------------------------------------------------------------- pannello armata
func _army_panel() -> void:
	army_panel = UiStyle.panel(6)
	army_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	army_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	army_panel.offset_left = 8
	army_panel.offset_bottom = -8
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	army_panel.add_child(h)
	army_lbl = UiStyle.label("", 15, UiStyle.INK, true)
	army_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	army_lbl.custom_minimum_size = Vector2(34, 0)
	army_lbl.tooltip_text = "Soldati selezionati"
	h.add_child(army_lbl)
	army_grid = h
	for t in Defs.UNIT_TYPES:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(46, 42)
		cell.tooltip_text = Defs.UNITS[t].name
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var pic := _portrait(t, 40)
		pic.position = Vector2(4, 0)
		cell.add_child(pic)
		var n := UiStyle.label("", 15, UiStyle.GOLD, true)
		n.position = Vector2(1, 22)
		n.add_theme_constant_override("outline_size", 6)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		cell.add_child(n)
		h.add_child(cell)
		army_cells.append(cell)
		army_counts.append(n)
	army_btn = UiStyle.button("T", "Seleziona tutta l'armata (T)", func(): game.ctrl.select_army(), 30.0, 30.0)
	army_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(army_btn)
	root.add_child(army_panel)


# ---------------------------------------------------------------- poteri e riga guida
func _bottom_center() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	hint_lbl = UiStyle.label("", 16, UiStyle.INK)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_constant_override("outline_size", 8)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	box.add_child(hint_lbl)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 3)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in Defs.BUILDING_COUNT:
		sh.add_child(_shop_cell(k))
	box.add_child(sh)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in Defs.POWER_COUNT:
		h.add_child(_power_card(k))
	box.add_child(h)
	root.add_child(box)


## Una casella della fila delle botteghe: icona, numero, e nel tooltip cosa fa.
func _shop_cell(k: int) -> Control:
	var d: Dictionary = Defs.BUILDINGS[k]
	var pw := ""
	for p in Defs.POWER_COUNT:
		if Defs.POWER_BUILDING[p] == k:
			pw = Defs.POWERS[p].name
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", UiStyle.panel_box(Color(0.125, 0.085, 0.06, 0.82), UiStyle.GOLD_DIM, 2))
	cell.custom_minimum_size = Vector2(50, 26)
	cell.tooltip_text = "%s → %s\n%s" % [d.name, pw, d.desc]
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Glyph.new(Defs.BUILDING_GLYPHS[k])
	g.custom_minimum_size = Vector2(20, 20)
	hb.add_child(g)
	var n := UiStyle.label("0", 13, UiStyle.INK, true)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(n)
	cell.add_child(hb)
	shop_cells.append(cell)
	shop_counts.append(n)
	shop_glyphs.append(g)
	return cell


func _power_card(k: int) -> Button:
	var d: Dictionary = Defs.POWERS[k]
	var b := UiStyle.button("", "[%s] %s: %d fede\n%s" % [d.key, d.name, d.cost, d.desc], func(): game.ctrl.start_action("power", k), 50.0, 50.0)
	b.add_theme_stylebox_override("normal", UiStyle.panel_box(Color(0.125, 0.085, 0.06, 0.88), UiStyle.GOLD_DIM, 2))
	var g := Glyph.new(POWER_GLYPHS[k])
	g.position = Vector2(8, 6)
	g.size = Vector2(34, 34)
	b.add_child(g)
	var key := UiStyle.label(d.key, 11, UiStyle.GOLD, true)
	key.position = Vector2(4, 1)
	b.add_child(key)
	var cost := UiStyle.label(str(d.cost), 10, UiStyle.MUTED)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost.position = Vector2(0, 35)
	cost.size = Vector2(46, 14)
	b.add_child(cost)
	var cd := UiStyle.label("", 19, UiStyle.INK, true)
	cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.position = Vector2(0, 11)
	cd.size = Vector2(50, 26)
	cd.add_theme_constant_override("outline_size", 6)
	cd.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_child(cd)
	var lock := Glyph.new("lucchetto")
	lock.position = Vector2(32, 2)
	lock.size = Vector2(16, 16)
	lock.visible = false
	b.add_child(lock)
	power_locks.append(lock)
	power_btns.append(b)
	power_glyphs.append(g)
	power_cost.append(cost)
	power_cd.append(cd)
	return b


func _minimap_panel() -> void:
	minimap = Minimap.new()
	minimap.setup(game)
	var mp := UiStyle.panel(4)
	mp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mp.offset_right = -8
	mp.offset_bottom = -8
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	# sfottò per gli amici: tasti 6-0, li leggono tutti
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 3)
	var tl := UiStyle.label("Sfottò", 13, UiStyle.GOLD, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(tl)
	taunt_lbl = tl
	for k in Defs.TAUNTS.size():
		var key := str((k + 6) % 10)
		var b := UiStyle.button(key, "Sfottò [%s]: «%s»\nLo leggono tutti. Uno ogni %d secondi" % [key, Defs.TAUNTS[k], int(Sim.TAUNT_CD)], func(): game.send_cmd("taunt", [k]), 24.0, 22.0)
		b.add_theme_font_size_override("font_size", 12)
		tr.add_child(b)
		taunt_btns.append(b)
	col.add_child(tr)
	col.add_child(minimap)
	mp.add_child(col)
	root.add_child(mp)


func _alert() -> void:
	alert_btn = UiStyle.button("", "Vai al castello", _on_alert, 300.0, 32.0)
	UiStyle.style_button(alert_btn, UiStyle.DANGER, Color(1, 0.6, 0.5), UiStyle.DANGER.lightened(0.12))
	alert_btn.add_theme_font_size_override("font_size", 15)
	alert_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	alert_btn.offset_top = 52
	alert_btn.visible = false
	root.add_child(alert_btn)


## Un mio castello è appena finito sotto attacco: messaggio, corno e pulsante che lampeggia.
## Al massimo un allarme ogni 20 s per castello, così una scaramuccia non suona di continuo.
func _raise_alarm(cid: int) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_alarm_at.get(cid, -ALARM_GAP_MS)) < ALARM_GAP_MS:
		return
	_alarm_at[cid] = now
	notify("All'armi! %s è sotto attacco" % game.castles[cid].name, UiStyle.DANGER_TEXT, 6.0)
	if game.fx and game.fx.sfx and game.ctrl and game.ctrl.cam:
		game.fx.sfx.play("horn", game.ctrl.cam.global_position, 2.0, 0.0)
	_alarm_flash = 3.0


func _on_alert() -> void:
	if alert_castle >= 0:
		game.ctrl.focus = game.castles[alert_castle].center
		game.ctrl.selected_castle = alert_castle
		game.ctrl.target_dist = 75.0


func _cursor_tip() -> void:
	tip = PanelContainer.new()
	tip.add_theme_stylebox_override("panel", UiStyle.panel_box(Color(0.06, 0.04, 0.03, 0.92), UiStyle.GOLD_DIM, 6))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_lbl = UiStyle.label("", 14)
	tip.add_child(tip_lbl)
	tip.visible = false
	root.add_child(tip)


func _help() -> void:
	help = UiStyle.panel(22)
	help.set_anchors_preset(Control.PRESET_CENTER)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.grow_vertical = Control.GROW_DIRECTION_BOTH
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	help.add_child(hv)
	hv.add_child(UiStyle.label("Come si gioca", 26, UiStyle.GOLD, true))
	hv.add_child(UiStyle.label("""Crea i soldati dal tuo castello, poi premi T per selezionarli.
Clic destro su un castello nemico: ci vanno e lo attaccano.
Per prendere un castello entra nel cortile e uccidi il re: è nel mastio, seduto sul gabinetto.
Vince chi prende tutti i 12 castelli d'Italia.""", 16))
	hv.add_child(UiStyle.label("Comandi", 20, UiStyle.GOLD, true))
	hv.add_child(UiStyle.label("""W A S D o frecce: muovi la vista          Rotella: avvicina e allontana
Q / E o tasto centrale: ruota la vista    Spazio: torna al tuo castello
Clic sinistro: seleziona, anche trascinando un riquadro
Clic destro: manda i selezionati. Su un muro nemico, catapulte e bombarde lo colpiscono
1-5: poteri          6-0: sfottò agli avversari          T: tutta l'armata          H: nascondi l'interfaccia
Con un tuo castello selezionato: G mura, R ripara, M mangano, O olio""", 15, UiStyle.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiStyle.button("Esci al menu", "Abbandona la partita", func(): game.get_parent().call_deferred("back_to_menu"), 180.0))
	row.add_child(UiStyle.button("Torna a giocare  [F1]", "", func(): toggle_help(), 200.0))
	hv.add_child(row)
	help.visible = false
	root.add_child(help)


## Menu di pausa (Esc): contro l'IA ferma anche la partita.
var pause_panel: Control
var _settings_panel: Control


func toggle_pause() -> void:
	if pause_panel == null:
		_build_pause()
	pause_panel.visible = not pause_panel.visible
	if pause_panel.visible:
		pause_panel.modulate.a = 0.0
		create_tween().tween_property(pause_panel, "modulate:a", 1.0, 0.12)
	if game.sim and not game.net_multiplayer:
		game.sim.paused = pause_panel.visible
	if not pause_panel.visible and is_instance_valid(_settings_panel):
		_settings_panel.queue_free()


## Pausa: velo scuro su tutta la partita, scheda al centro con «Riprendi» in evidenza,
## le altre voci sotto e l'uscita separata in fondo.
func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.015, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := UiStyle.panel_box(Color(0.10, 0.07, 0.045, 1.0), UiStyle.GOLD_DIM, 0)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 28
	sb.content_margin_bottom = 26
	sb.border_width_top = 3
	sb.shadow_size = 24
	sb.shadow_color = Color(0, 0, 0, 0.6)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(400, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var kick := UiStyle.label("PARTITA IN PAUSA" if not game.net_multiplayer else "MENU", 13, UiStyle.GOLD_DIM, true)
	var fv := FontVariation.new()
	fv.base_font = UiStyle.title_font()
	fv.spacing_glyph = 4
	kick.add_theme_font_override("font", fv)
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kick)
	var hn := UiStyle.label(String(Defs.HOUSES[game.my_house].name) if game.my_house >= 0 else "Pausa", 34, UiStyle.GOLD, true)
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hn)
	if game.my_house >= 0:
		var mt := UiStyle.label(String(Defs.HOUSES[game.my_house].motto), 14, UiStyle.MUTED)
		mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mt)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)
	var resume := UiStyle.button("Riprendi", "Esc", func(): toggle_pause(), 0.0, 52.0)
	UiStyle.style_button(resume, Color(0.86, 0.64, 0.26), Color(1.0, 0.85, 0.5), Color(0.95, 0.73, 0.32))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		resume.add_theme_color_override(k, Color(0.17, 0.09, 0.03))
	resume.add_theme_font_override("font", UiStyle.title_font())
	resume.add_theme_font_size_override("font_size", 21)
	v.add_child(resume)
	var save_b := _pause_btn("Salva partita", "Salva questa partita contro l'IA (sovrascrive quella salvata prima)", _save_game)
	save_b.disabled = game.net_multiplayer
	if game.net_multiplayer:
		save_b.tooltip_text = "Le partite in rete non si salvano"
	v.add_child(save_b)
	v.add_child(_pause_btn("Impostazioni", "Audio, schermo e difficoltà", _open_settings))
	v.add_child(_pause_btn("Guida e comandi", "F1", func():
		toggle_pause()
		toggle_help()))
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.GOLD_DIM, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	var rb := VBoxContainer.new()
	var g1 := Control.new()
	g1.custom_minimum_size = Vector2(0, 6)
	rb.add_child(g1)
	rb.add_child(rule)
	v.add_child(rb)
	var quit_b := Button.new()
	quit_b.text = "Esci al menu"
	quit_b.tooltip_text = "La partita non salvata si perde"
	quit_b.flat = true
	quit_b.focus_mode = Control.FOCUS_NONE
	quit_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	quit_b.add_theme_font_override("font", UiStyle.body_font())
	quit_b.add_theme_font_size_override("font_size", 15)
	quit_b.add_theme_color_override("font_color", UiStyle.MUTED)
	quit_b.add_theme_color_override("font_hover_color", UiStyle.DANGER_TEXT)
	quit_b.add_theme_color_override("font_pressed_color", UiStyle.DANGER_TEXT)
	quit_b.pressed.connect(func(): game.get_parent().call_deferred("back_to_menu"))
	v.add_child(quit_b)
	root.add_child(pause_panel)
	pause_panel.visible = false


func _pause_btn(t: String, tip: String, cb: Callable) -> Button:
	var b := UiStyle.button(t, tip, cb, 0.0, 44.0)
	b.add_theme_font_override("font", UiStyle.title_font())
	b.add_theme_font_size_override("font_size", 18)
	return b


func _save_game() -> void:
	if SaveGame.save(game):
		notify("Partita salvata", UiStyle.GOLD)
	else:
		notify("Non è stato possibile salvare la partita", UiStyle.DANGER_TEXT)


func _open_settings() -> void:
	if is_instance_valid(_settings_panel):
		return
	var p := Settings.SettingsPanel.new()
	root.add_child(p)
	p.closed.connect(p.queue_free)
	_settings_panel = p


func toggle_help() -> void:
	help.visible = not help.visible


## Tasto H: nasconde tutta l'interfaccia tranne gli avvisi importanti.
func toggle_ui() -> void:
	hud_hidden = not hud_hidden
	for n: Node in root.get_children():
		if n is Control and n != alert_btn and n != notify_box and n != help and n != victory and n != drag_rect and n != tip:
			(n as Control).visible = not hud_hidden
	notify("Interfaccia nascosta: premi H per mostrarla" if hud_hidden else "", UiStyle.GOLD, 2.0)


# ---------------------------------------------------------------- segni nel mondo
func _world_marks() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.965
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 4
	for c: Dictionary in game.castles:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0009
		l.font_size = 22
		l.outline_size = 16
		l.no_depth_test = true
		# sopra mare, rombi delle truppe ed effetti, che sono trasparenti e altrimenti la coprono
		l.render_priority = 20
		l.outline_render_priority = 19
		l.font = UiStyle.world_font()
		l.text = c.name
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(l)
		l.global_position = (c.center as Vector3) + Vector3(0, WorldGen.KEEP_H + 14, 0)
		labels.append(l)
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = (c.center as Vector3) + Vector3(0, 0.25, 0)
		ring.scale = Vector3(WorldGen.R + 8.0, 0.6, WorldGen.R + 8.0)
		ring.visible = false
		rings.append(ring)
		ring_mats.append(mat)
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 150.0
	cyl.radial_segments = 16
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.82, 0.3, 0.2)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	add_child(beam)


## Colonna di luce sul tuo castello: all'avvio e quando chiedi di tornarci.
func flash_home(cid: int) -> void:
	if beam == null:
		return
	beam.global_position = (game.castles[cid].center as Vector3) + Vector3(0, 75, 0)
	beam.visible = true
	_beam_t = 5.0


func _show_intro() -> void:
	if game.my_house < 0:
		return
	game.ctrl.start_intro()
	var cid: int = game.ctrl.home_castle
	if cid < 0:
		return
	_beam_t = 9.0
	flash_home(cid)
	_beam_t = 9.0
	var h: Dictionary = Defs.HOUSES[game.my_house]
	intro = PanelContainer.new()
	intro.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD, 12))
	intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro.set_anchors_preset(Control.PRESET_CENTER)
	intro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	intro.grow_vertical = Control.GROW_DIRECTION_BOTH
	intro.offset_top = -230
	intro.offset_bottom = -230
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var sh := UiStyle.Shield.new()
	sh.color = h.color
	sh.custom_minimum_size = Vector2(34, 44)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sh)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UiStyle.label("Sei la casata %s" % h.name, 24, UiStyle.INK, true))
	v.add_child(UiStyle.label("Il tuo castello è %s: ha l'anello dorato" % game.castles[cid].name, 15, UiStyle.GOLD))
	row.add_child(v)
	intro.add_child(row)
	root.add_child(intro)
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(intro, "modulate:a", 0.0, 0.6)
	tw.tween_callback(intro.queue_free)


func _recruit(t: int) -> void:
	game.send_cmd("recruit", [game.ctrl.selected_castle, t])


## Bande nere da cinema durante l'inquadratura del re.
var _bars: Array[ColorRect] = []
var _bar_lbl: Label
var _cine_hidden: Array = []


func letterbox(on: bool, caption := "") -> void:
	# durante la scena spariscono nomi dei castelli e interfaccia (resta solo la didascalia)
	for l in labels:
		l.visible = not on
	if on:
		_cine_hidden.clear()
		_cine_hidden.append(self)  # segna che la scena è in corso (vedi _refresh_panels)
		for ch in root.get_children():
			if ch is CanvasItem and (ch as CanvasItem).visible and not (ch is ColorRect and _bars.has(ch)) and ch != castle_panel and ch != army_panel:
				_cine_hidden.append(ch)
				(ch as CanvasItem).visible = false
	else:
		for ch in _cine_hidden:
			if is_instance_valid(ch) and ch != self:
				(ch as CanvasItem).visible = true
		_cine_hidden.clear()
	if _bars.is_empty():
		for k in 2:
			var r := ColorRect.new()
			r.color = Color.BLACK
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
			r.custom_minimum_size = Vector2(0, 0)
			root.add_child(r)
			root.move_child(r, 0)  # sotto il resto dell'interfaccia: le notizie restano leggibili
			_bars.append(r)
		_bar_lbl = UiStyle.label("", 24, UiStyle.GOLD, true)
		_bar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_bar_lbl.offset_bottom = -10
		_bars[0].add_child(_bar_lbl)  # in alto: in basso ci sono poteri e armata
	_bar_lbl.text = caption
	var h := get_viewport().get_visible_rect().size.y * 0.13
	for k in 2:
		var r := _bars[k]
		r.visible = true
		if k == 0:
			r.offset_top = 0
		else:
			r.offset_bottom = 0
			r.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var tw := create_tween()
		tw.tween_property(r, "custom_minimum_size:y", h if on else 0.0, 0.35)
		if not on:
			tw.tween_callback(func() -> void: r.visible = false)


## Evento a sorpresa: titolo grande che entra con un rimbalzo, sottotitolo, squillo di corno.
var _banner_box: Control
func banner(title: String, sub: String, p: Vector3) -> void:
	if _banner_box != null and is_instance_valid(_banner_box):
		_banner_box.queue_free()
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.03, 0.72)
	sb.border_color = UiStyle.GOLD_DIM
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.content_margin_top = 6
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(inner)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -400
	box.offset_right = 400
	box.offset_top = 214  # sotto le tre righe di notizie, che iniziano a 92
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inner.add_theme_constant_override("separation", 0)
	var t := UiStyle.label(title, 46, UiStyle.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 16)
	t.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.02))
	inner.add_child(t)
	var st := UiStyle.label(sub, 19, UiStyle.INK)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_constant_override("outline_size", 9)
	st.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	inner.add_child(st)
	root.add_child(box)
	_banner_box = box
	box.pivot_offset = Vector2(400, 45)
	box.scale = Vector2(0.3, 0.3)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.7)
	tw.tween_callback(box.queue_free)
	if game.fx and game.fx.sfx and game.ctrl and game.ctrl.cam:
		var solemn: bool = title.begins_with("Processione") or title.begins_with("Scomunica")
		game.fx.sfx.play("bell" if solemn else "horn", game.ctrl.cam.global_position, 2.0, 0.0)


func notify(text: String, col: Color, life := 4.0) -> void:
	if notify_box == null:
		return
	if text.is_empty():
		return
	for ch in notify_box.get_children():  # la stessa notizia ripetuta non occupa altre righe
		if ch.has_meta("text") and String(ch.get_meta("text")) == text and not ch.is_queued_for_deletion():
			return
	var l := UiStyle.label(text, 16, col.lerp(Color.WHITE, 0.6), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	# fondo scuro: senza, il testo si confondeva con le scritte 3D dei castelli
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiStyle.panel_box(Color(UiStyle.WALNUT, 0.88), col.darkened(0.2), 6)
	box.add_theme_stylebox_override("panel", sb)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	box.set_meta("text", text)
	notify_box.add_child(box)
	var tw := box.create_tween()  # legato alla riga: se viene tolta prima, si ferma con lei
	tw.tween_interval(life)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)
	while notify_box.get_child_count() > 3:
		var o := notify_box.get_child(0)
		notify_box.remove_child(o)
		o.queue_free()


func _display_name(t: int) -> String:
	var hs: Array = game.state[1]
	return String(hs[t][4]) if t < hs.size() and hs[t][4] != "" else String(Defs.HOUSES[t].name)


# ---------------------------------------------------------------- aggiornamento stato
func on_state() -> void:
	if game.state.is_empty() or not top_ready():
		return
	var cs: Array = game.state[0]
	var hs: Array = game.state[1]
	var mine := 0
	var counts := {}
	alert_castle = -1
	var attacked := 0
	for i in cs.size():
		var o: int = cs[i][0]
		counts[o] = int(counts.get(o, 0)) + 1
		var hit: bool = o == game.my_house and cs[i][7]
		if o == game.my_house and _owner_prev.get(i, o) != o:
			_alarm_at[i] = Time.get_ticks_msec()
		_owner_prev[i] = o
		if o == game.my_house:
			mine += 1
			if hit:
				attacked += 1
				if alert_castle < 0:
					alert_castle = i
		if hit and not _attacked_prev.get(i, false):
			_raise_alarm(i)
		_attacked_prev[i] = hit
	alert_btn.visible = alert_castle >= 0 and _cine_hidden.is_empty()  # niente allarme sopra la didascalia del re
	if alert_castle >= 0:
		var cname: String = game.castles[alert_castle].name
		if attacked > 1:
			alert_btn.text = "%s e altri %d castelli sotto attacco: clicca per andarci" % [cname, attacked - 1]
		else:
			alert_btn.text = "%s è sotto attacco: clicca per andarci" % cname
	var units := 0
	for u: Game.VU in game.vunits.values():
		if u.team == game.my_house:
			units += 1
	if game.my_house >= 0:
		var h: Dictionary = Defs.HOUSES[game.my_house]
		shield.color = h.color
		shield.queue_redraw()
		house_lbl.text = String(h.name)
		gold_lbl.text = str(game.gold())
		var spend: float = game.repair_spend()
		if spend > 0.0:
			income_lbl.text = "fiorini +%d/s  −%d riparazioni" % [int(Defs.income(mine)), ceili(spend)]
			income_lbl.add_theme_color_override("font_color", UiStyle.DANGER_TEXT)
			income_lbl.tooltip_text = "Le riparazioni in corso consumano i fiorini: premi R sul castello per fermarle"
		else:
			income_lbl.text = "fiorini +%d/s" % int(Defs.income(mine))
			income_lbl.add_theme_color_override("font_color", UiStyle.MUTED)
			income_lbl.tooltip_text = ""
		faith_lbl.text = str(game.faith())
		var fr: float = game.faith_rate()
		faith_rate_lbl.text = ("fede +%.1f/s" % fr).replace(".", ",") if fr > 0.0 else "fede · senza chiesa"
		faith_rate_lbl.add_theme_color_override("font_color", UiStyle.MUTED if fr > 0.0 else UiStyle.DANGER_TEXT)
		var me_row: Array = game.state[1][game.my_house]
		var excom: int = int(me_row[10]) if me_row.size() > 10 else 0
		if excom > 0:
			faith_rate_lbl.text = "fede · scomunicati %ds" % excom
		faith_lbl.tooltip_text = ("Fede +%.1f/s da chiese e frati che pregano. Serve per i poteri (tasti 1-5)" % fr) if fr > 0.0 else "Niente Fede: costruisci una chiesa e recluta frati che le preghino accanto"
		castles_lbl.text = "%d/%d" % [mine, cs.size()]
		troops_lbl.text = "%d/%d" % [units, Defs.HOUSE_UNIT_CAP]
		troops_lbl.add_theme_color_override("font_color", UiStyle.DANGER_TEXT if units >= Defs.HOUSE_UNIT_CAP else UiStyle.INK)
		troops_lbl.tooltip_text = "Truppe: al massimo %d. Al limite non si recluta più" % Defs.HOUSE_UNIT_CAP
	else:
		house_lbl.text = "Spettatore"
	var my_row: Array = game.state[1][game.my_house] if game.my_house >= 0 else []
	var tcd: int = int(my_row[9]) if my_row.size() > 9 else 0
	for b: Button in taunt_btns:
		b.disabled = tcd > 0
	taunt_lbl.text = ("Sfottò %ds" % tcd) if tcd > 0 else "Sfottò"
	taunt_lbl.add_theme_color_override("font_color", UiStyle.OFF if tcd > 0 else UiStyle.GOLD)
	var truce: int = game.state[3]
	truce_lbl.visible = truce > 0 and game.my_house >= 0
	if truce_lbl.visible:
		truce_lbl.text = "Tregua %d:%02d" % [truce / 60, truce % 60]
	_update_rank(counts, hs)
	if game.state[2] >= 0 and not victory.visible:
		victory.visible = true
		var w: int = game.state[2]
		victory.text = "%s, signore d'Italia!" % _display_name(w)
		victory.add_theme_color_override("font_color", Defs.HOUSES[w].color.lerp(Color.WHITE, 0.3))
	_update_labels(cs)
	_refresh_panels()


func top_ready() -> bool:
	return gold_lbl != null and rank_rows.size() == 8 and castle_panel != null and army_panel != null and alert_btn != null and truce_lbl != null and not power_btns.is_empty()


func _update_rank(counts: Dictionary, hs: Array) -> void:
	var order: Array = range(8)
	order.sort_custom(func(a: int, b: int): return int(counts.get(a, 0)) > int(counts.get(b, 0)) or (int(counts.get(a, 0)) == int(counts.get(b, 0)) and a < b))
	for i in 8:
		var t: int = order[i]
		var r: Dictionary = rank_rows[i]
		var n: int = counts.get(t, 0)
		(r.shield as UiStyle.Shield).color = Defs.HOUSES[t].color if n > 0 else Color(0.3, 0.28, 0.26)
		(r.shield as UiStyle.Shield).edge = UiStyle.GOLD if t == game.my_house else Color(0, 0, 0, 0.5)
		(r.shield as Control).queue_redraw()
		var nm: String = _display_name(t)
		if t == game.my_house:
			nm += " (tu)"
		elif not hs[t][3]:
			nm += " (giocatore)"
		(r.row as Control).tooltip_text = "%s: %s" % [nm, ("%d castell%s" % [n, "o" if n == 1 else "i"]) if n > 0 else "caduta"]
		(r.count as Label).text = str(n) if n > 0 else "-"
		(r.count as Label).add_theme_color_override("font_color", UiStyle.GOLD if t == game.my_house else (UiStyle.INK if n > 0 else UiStyle.OFF))


func _update_labels(cs: Array) -> void:
	var sel: int = game.ctrl.selected_castle
	for i in cs.size():
		var o: int = cs[i][0]
		var cap: float = cs[i][1]
		var is_mine: bool = o == game.my_house
		var l := labels[i]
		var extra := ""
		if cap > 0.0:
			extra = "\n%s ferito %d%%" % ["podestà" if o == Defs.NEUTRAL else "re", int(cap * 100.0)]
		if is_mine and cs[i][7]:
			l.text = "SOTTO ATTACCO!\n%s%s" % [game.castles[i].name, extra]
			l.modulate = UiStyle.DANGER_TEXT
			l.font_size = 30
		elif is_mine:
			l.text = "IL TUO CASTELLO\n%s%s" % [game.castles[i].name, extra]
			l.modulate = Color(1.0, 0.85, 0.4)
			l.font_size = 30
		else:
			l.text = "%s%s" % [game.castles[i].name, extra]
			l.modulate = Defs.HOUSES[o].color.lerp(Color.WHITE, 0.3)
			l.font_size = 22
		l.outline_modulate = Color(0, 0, 0)
		var ring := rings[i]
		ring.visible = is_mine or i == sel
		ring_mats[i].albedo_color = UiStyle.GOLD if is_mine else Color.WHITE


## Le icone degli edifici diventano texture una volta sola (SubViewport), per le insegne nel mondo.
func _make_badge_textures() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(31.5 - d, 0.0, 1.0)))
	_ring_tex = ImageTexture.create_from_image(img)
	var vps: Array = []
	for k in Defs.BUILDING_COUNT:
		var vp := SubViewport.new()
		vp.size = Vector2i(96, 96)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var bg := BadgeBack.new()
		bg.size = Vector2(96, 96)
		vp.add_child(bg)
		var g := Glyph.new(Defs.BUILDING_GLYPHS[k])
		g.position = Vector2(18, 16)
		g.size = Vector2(60, 60)
		vp.add_child(g)
		add_child(vp)
		vps.append(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for k in vps.size():
		_badge_tex[k] = ImageTexture.create_from_image((vps[k] as SubViewport).get_texture().get_image())
		(vps[k] as SubViewport).queue_free()


class BadgeBack:
	extends Control
	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.46, Color(0.13, 0.09, 0.06, 0.95))
		draw_arc(size * 0.5, size.x * 0.44, 0.0, TAU, 40, UiStyle.GOLD, 3.0, true)


## Insegna sopra ogni edificio: icona della bottega, anello del colore di chi la possiede.
## Cantiere: semitrasparente. Crollata: anello rosso.
func _update_badges() -> void:
	if _badge_tex.size() < Defs.BUILDING_COUNT:
		return
	var list: Array = game.buildings()
	while _badges.size() < list.size():
		var ring := Sprite3D.new()
		ring.texture = _ring_tex
		var icon := Sprite3D.new()
		for sp: Sprite3D in [ring, icon]:
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.fixed_size = true
			sp.no_depth_test = true
			sp.shaded = false
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			add_child(sp)
		ring.pixel_size = 0.00062
		icon.pixel_size = 0.00038
		ring.render_priority = 14
		icon.render_priority = 15
		_badges.append([ring, icon])
	for i in _badges.size():
		var pair: Array = _badges[i]
		var ring: Sprite3D = pair[0]
		var icon: Sprite3D = pair[1]
		var on := i < list.size() and _cine_hidden.is_empty()
		ring.visible = on
		icon.visible = on
		if not on:
			continue
		var b: Array = list[i]
		var p := Vector3(float(b[3]) + 0.5, float(b[5]) + (Buildings.H + 2) * WorldGen.CS, float(b[4]) + 0.5)
		ring.global_position = p
		icon.global_position = p
		icon.texture = _badge_tex[int(b[1])]
		var building := float(b[8]) < 1.0
		var col: Color = Defs.HOUSES[int(b[2])].color
		if not bool(b[9]) and not building:
			col = UiStyle.DANGER
		ring.modulate = Color(col, 0.55 if building else 1.0)
		icon.modulate = Color(1, 1, 1, 0.55 if building else 1.0)


func _process(dt: float) -> void:
	_update_badges()
	if _portrait_frames > 0:
		_portrait_frames -= 1
		if _portrait_frames == 0:
			for vp in _portrait_vps:
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hint_t -= dt
	_refresh_panels()
	_update_tip(dt)
	drag_rect.queue_redraw()
	minimap.queue_redraw()
	if _beam_t > 0.0:
		_beam_t -= dt
		beam.visible = _beam_t > 0.0
	if _alarm_flash > 0.0:
		_alarm_flash -= dt
		alert_btn.modulate = Color.WHITE.lerp(Color(1.6, 1.3, 1.3), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	else:
		alert_btn.modulate = Color.WHITE
	# l'anello del proprio castello respira, così si trova a colpo d'occhio; rosso se è sotto attacco
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 400.0)
	var fast := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	if not game.state.is_empty():
		var cs: Array = game.state[0]
		for i in cs.size():
			if int(cs[i][0]) == game.my_house and cs[i][7]:
				ring_mats[i].albedo_color = UiStyle.DANGER.lerp(Color(1.0, 0.85, 0.8), fast * 0.6)
				rings[i].visible = true
			elif int(cs[i][0]) == game.my_house:
				ring_mats[i].albedo_color = UiStyle.GOLD.lerp(Color(1.0, 0.95, 0.7), pulse * 0.5)
				rings[i].visible = true
			elif i == game.ctrl.selected_castle:
				ring_mats[i].albedo_color = Color.WHITE
				rings[i].visible = true
			elif int(cs[i][0]) != game.my_house:
				rings[i].visible = false


func _update_tip(dt: float) -> void:
	_tip_t -= dt
	if not _cine_hidden.is_empty():
		tip.visible = false
		return
	var ctrl: Controller = game.ctrl
	var mp := root.get_viewport().get_mouse_position()
	var pos_ok := root.get_viewport().gui_get_hovered_control() == null
	if not pending_text().is_empty() and pos_ok:
		tip_lbl.text = pending_text()
		tip.visible = true
	elif _tip_t <= 0.0:
		_tip_t = 0.1
		tip.visible = false
		if pos_ok and not ctrl.dragging:
			var hit := ctrl._ray()
			if hit.get("hit", false):
				var cid: int = game.castle_at(hit.point)
				var bb: Array = game.building_at(hit.point)
				if not bb.is_empty():
					tip_lbl.text = _building_tip(bb)
					tip.visible = true
				elif cid >= 0:
					tip_lbl.text = _castle_tip(cid)
					tip.visible = true
	if tip.visible:
		tip.reset_size()
		var vs := root.get_viewport_rect().size
		tip.position = Vector2(minf(mp.x + 18.0, vs.x - tip.size.x - 6.0), minf(mp.y + 20.0, vs.y - tip.size.y - 6.0))


func pending_text() -> String:
	var pend: Dictionary = game.ctrl.pending
	if pend.is_empty():
		return ""
	match String(pend.kind):
		"power": return "Clic sinistro: %s  ·  Clic destro: annulla" % Defs.POWERS[int(pend.id)].name
		"mangano": return "Clic sinistro: tira la pietra  ·  Clic destro: annulla"
		"oil": return "Clic sinistro: versa l'olio  ·  Clic destro: annulla"
		"build":
			var why: String = String(pend.get("why", ""))
			var nm: String = Defs.BUILDINGS[int(pend.id)].name
			return ("Clic sinistro: costruisci %s qui  ·  Clic destro: annulla" % nm) if why == "" else ("%s: %s  ·  Clic destro: annulla" % [nm, why])
	return ""


func _building_tip(b: Array) -> String:
	var d: Dictionary = Defs.BUILDINGS[int(b[1])]
	var o: int = b[2]
	var state_txt := ""
	if float(b[8]) < 1.0:
		state_txt = " (cantiere %d%%)" % int(float(b[8]) * 100.0)
	elif not bool(b[9]):
		state_txt = " (crollata)"
	if o == game.my_house:
		return "%s, tua%s\n%s" % [d.name, state_txt, d.desc]
	var has_sel: bool = not game.renderer.selected.is_empty()
	return "%s di %s%s\n%s" % [d.name, _display_name(o), state_txt, "Clic destro: i soldati la abbattono" if has_sel else "Premi T, poi clic destro per abbatterla"]


func _castle_tip(cid: int) -> String:
	var o: int = game.castle_owner(cid)
	var nm: String = game.castles[cid].name
	var has_sel: bool = not game.renderer.selected.is_empty()
	if o == game.my_house:
		return "%s, il tuo castello%s" % [nm, "\nClic destro: i soldati ci vanno" if has_sel else "\nClic sinistro: crea soldati"]
	var who: String = "senza padrone" if o == Defs.NEUTRAL else "di " + _display_name(o)
	return "%s, %s%s" % [nm, who, "\nClic destro: attacca" if has_sel else "\nPremi T, poi clic destro per attaccarlo"]


func _refresh_panels() -> void:
	var sel: Dictionary = game.renderer.selected
	var cid: int = game.ctrl.selected_castle
	var has_units := false
	for id: int in sel:
		if game.vunits.has(id):
			has_units = true
			break
	var shown := not hud_hidden and _cine_hidden.is_empty()  # durante la scena del re niente pannelli
	castle_panel.visible = shown and cid >= 0 and not has_units
	army_panel.visible = shown and has_units
	if castle_panel.visible and not game.state.is_empty():
		_refresh_castle(cid)
	elif army_panel.visible:
		_refresh_army(sel, has_units)
	_refresh_hint(cid, has_units)
	_refresh_powers()


func _refresh_castle(cid: int) -> void:
	var c: Array = game.state[0][cid]
	var o: int = c[0]
	var mine: bool = o == game.my_house
	castle_title.text = game.castles[cid].name
	castle_shield.color = Defs.HOUSES[o].color
	castle_shield.queue_redraw()
	if mine:
		castle_info.text = "Il tuo castello"
		castle_info.add_theme_color_override("font_color", UiStyle.GOLD)
	elif o == Defs.NEUTRAL:
		castle_info.text = "Senza padrone: è il bersaglio più facile"
		castle_info.add_theme_color_override("font_color", UiStyle.MUTED)
	else:
		castle_info.text = "Castello nemico: %s" % _display_name(o)
		castle_info.add_theme_color_override("font_color", UiStyle.DANGER_TEXT)
	integ_bar.value = c[3]
	integ_lbl.text = "%d%%" % int(float(c[3]) * 100.0)
	cap_row.visible = float(c[1]) > 0.0
	cap_bar.value = c[1]
	cap_lbl.text = "%d%%" % int(float(c[1]) * 100.0)
	var q: Array = c[8]
	var qw: Control = queue_row.get_meta("wrap")
	qw.visible = mine and not q.is_empty()
	if qw.visible:
		queue_bar.value = c[9]
		var names: Dictionary = {}
		var order: Array = []
		for t: int in q:
			if not names.has(t):
				order.append(t)
			names[t] = int(names.get(t, 0)) + 1
		var text := ""
		for t: int in order:
			text += "%d %s  " % [names[t], Defs.UNITS[t].name]
		_set_queue_text(text.strip_edges())
	tab_bar.visible = mine
	recruit_box.visible = mine and castle_tab == 0
	build_box.visible = mine and castle_tab == 1
	build_hint.visible = mine and castle_tab == 1
	def_box.visible = mine
	for k in tab_btns.size():
		tab_btns[k].set_pressed_no_signal(k == castle_tab)
	enemy_hint.visible = not mine
	if not mine:
		enemy_hint.text = "Premi T per selezionare i soldati, poi fai clic destro su questo castello."
		return
	var g: int = game.gold()
	var church: bool = game.has_shop(Defs.B_CHIESA)
	var at_cap := _my_troops_and_queue() >= Defs.HOUSE_UNIT_CAP
	for t in recruit_btns.size():
		var cost: int = Defs.UNITS[t].cost
		var can := g >= cost and (t != Defs.FRATE or church) and not at_cap
		recruit_btns[t].disabled = not can
		var d: Dictionary = Defs.UNITS[t]
		var tip := "%s: %d fiorini\n%s\nVita %d · Velocità %d" % [d.name, d.cost, d.desc, d.hp, int(d.speed)]
		if at_cap:
			tip += "\nLimite di %d truppe raggiunto" % Defs.HOUSE_UNIT_CAP
		elif t == Defs.FRATE and not church:
			tip += "\nServe una chiesa: costruiscila dalla scheda Costruzioni"
		if recruit_btns[t].tooltip_text != tip:
			recruit_btns[t].tooltip_text = tip
		recruit_cost[t].add_theme_color_override("font_color", UiStyle.GOLD if can else UiStyle.DANGER_TEXT)
	var mg: float = c[5]
	var ol: float = c[6]
	(def_btns["mangano"] as Button).disabled = mg > 0.0
	(def_lbls["mangano"] as Label).text = "%ds" % ceili(mg) if mg > 0.0 else "M"
	(def_btns["oil"] as Button).disabled = ol > 0.0 or g < 25
	(def_lbls["oil"] as Label).text = "%ds" % ceili(ol) if ol > 0.0 else "O"
	(def_lbls["repair"] as Label).text = "in corso" if c[4] else "R"
	# schede delle botteghe: quante ne hai, se te le puoi permettere
	var have: Array[int] = []
	have.resize(Defs.BUILDING_COUNT)
	have.fill(0)
	for bd: Array in game.buildings():
		if int(bd[2]) == game.my_house:
			have[int(bd[1])] += 1
	for k in Defs.BUILDING_COUNT:
		var bc: int = Defs.BUILDINGS[k].cost
		var ok := g >= bc
		build_btns[k].disabled = not ok
		build_costs[k].add_theme_color_override("font_color", UiStyle.GOLD if ok else UiStyle.DANGER_TEXT)
		build_counts[k].text = "×%d" % have[k] if have[k] > 0 else ""
		if build_glyphs[k].dim == ok:
			build_glyphs[k].dim = not ok
			build_glyphs[k].queue_redraw()


func _my_troops_and_queue() -> int:
	var n := 0
	for u: Game.VU in game.vunits.values():
		if u.team == game.my_house:
			n += 1
	if not game.state.is_empty():
		for i in game.castles.size():
			var row: Array = game.state[0][i]
			if int(row[0]) == game.my_house:
				n += (row[8] as Array).size()
	return n


func _set_queue_text(text: String) -> void:
	var l: Label
	if queue_row.get_child_count() == 0:
		l = UiStyle.label("", 13, UiStyle.INK)
		queue_row.add_child(l)
	else:
		l = queue_row.get_child(0)
	l.text = text


func _set_tab(k: int) -> void:
	castle_tab = k
	for i in tab_btns.size():
		tab_btns[i].set_pressed_no_signal(i == k)


## Il vecchio «+ Costruisci»: ora porta alla scheda Costruzioni del castello.
func _open_build() -> void:
	_set_tab(1)


func _build_card(k: int) -> Button:
	var d: Dictionary = Defs.BUILDINGS[k]
	var pw := ""
	for p in Defs.POWER_COUNT:
		if Defs.POWER_BUILDING[p] == k:
			pw = Defs.POWERS[p].name
	var b := UiStyle.button("", "%s → %s\n%s\nCon %s · %d fiorini" % [d.name, pw, d.desc, d.worker, d.cost], func(): game.ctrl.start_action("build", k), CARD_W, CARD_H)
	var g := Glyph.new(Defs.BUILDING_GLYPHS[k])
	g.position = Vector2(4, 6)
	g.size = Vector2(34, 34)
	b.add_child(g)
	var n := UiStyle.label(d.short, 11, UiStyle.INK)
	n.position = Vector2(42, 4)
	b.add_child(n)
	var c := UiStyle.label(str(d.cost), 16, UiStyle.GOLD, true)
	c.position = Vector2(42, 21)
	b.add_child(c)
	var cnt := UiStyle.label("", 13, UiStyle.INK)
	cnt.position = Vector2(CARD_W - 28, 24)
	cnt.size = Vector2(24, 18)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(cnt)
	build_btns.append(b)
	build_costs.append(c)
	build_counts.append(cnt)
	build_glyphs.append(g)
	return b


func _refresh_army(sel: Dictionary, _has_units: bool) -> void:
	var counts: Array[int] = []
	counts.resize(Defs.UNIT_TYPES)
	counts.fill(0)
	var total := 0
	for id: int in sel:
		var u: Game.VU = game.vunits.get(id)
		if u:
			counts[u.type] += 1
			total += 1
	army_lbl.text = str(total)
	for t in counts.size():
		army_cells[t].visible = counts[t] > 0
		army_counts[t].text = str(counts[t])


## La riga guida compare quando la situazione cambia e poi si fa da parte.
func _refresh_hint(cid: int, has_units: bool) -> void:
	var text := ""
	if not game.ctrl.pending.is_empty():
		text = "Scegli il bersaglio con il clic sinistro, clic destro per annullare"
	elif game.state.is_empty() or game.my_house < 0:
		text = ""
	elif has_units:
		text = "Clic destro dove vuoi mandarli: su un castello nemico lo attaccano"
	elif cid >= 0 and game.castle_owner(cid) == game.my_house:
		text = "Crea soldati qui sotto, poi premi T per selezionarli"
	elif cid >= 0:
		text = "Premi T, poi clic destro su questo castello per attaccarlo"
	else:
		text = "Clicca il tuo castello per creare soldati, o premi T"
	if hint_lbl.text != text:
		hint_lbl.text = text
		_hint_t = HINT_LIFE
	var a := clampf(_hint_t, 0.0, 1.0) if game.ctrl.pending.is_empty() else 1.0
	hint_lbl.modulate.a = 0.0 if hud_hidden else a


func _refresh_powers() -> void:
	if game.state.is_empty() or game.my_house < 0:
		return
	var hcd: Array = game.state[1][game.my_house][2]
	var fa: int = game.faith()
	for k in power_btns.size():
		var d: Dictionary = Defs.POWERS[k]
		var cd: float = hcd[k]
		var poor: bool = fa < int(d.cost)
		var locked: bool = not game.has_shop(Defs.POWER_BUILDING[k])
		power_btns[k].disabled = cd > 0.0 or poor or locked
		var tip := "[%s] %s: %d fede\n%s" % [d.key, d.name, d.cost, d.desc]
		if locked:
			tip += "\nServe: %s in un tuo castello" % Defs.BUILDINGS[Defs.POWER_BUILDING[k]].name
		if power_btns[k].tooltip_text != tip:
			power_btns[k].tooltip_text = tip
		power_btns[k].modulate = Color.WHITE
		power_locks[k].visible = locked
		var dim: bool = cd > 0.0 or poor or locked
		if power_glyphs[k].dim != dim:
			power_glyphs[k].dim = dim
			power_glyphs[k].queue_redraw()
		power_cd[k].text = str(ceili(cd)) if cd > 0.0 and not locked else ""
		# bloccato: al posto del costo, la bottega che serve; senza Fede: costo in rosso
		if locked:
			power_cost[k].text = Defs.BUILDINGS[Defs.POWER_BUILDING[k]].short
			power_cost[k].add_theme_font_size_override("font_size", 9)
			power_cost[k].add_theme_color_override("font_color", UiStyle.GOLD)
			power_cost[k].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			power_cost[k].position = Vector2(0, 36)
			power_cost[k].size = Vector2(50, 14)
		else:
			power_cost[k].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			power_cost[k].position = Vector2(0, 35)
			power_cost[k].size = Vector2(46, 14)
			power_cost[k].text = str(d.cost)
			power_cost[k].add_theme_font_size_override("font_size", 10)
			power_cost[k].add_theme_color_override("font_color", UiStyle.DANGER_TEXT if poor else UiStyle.MUTED)
	var have: Array[int] = []
	have.resize(Defs.BUILDING_COUNT)
	have.fill(0)
	for bd: Array in game.buildings():
		if int(bd[2]) == game.my_house and bool(bd[9]):
			have[int(bd[1])] += 1
	for k in Defs.BUILDING_COUNT:
		shop_counts[k].text = str(have[k])
		var none := have[k] == 0
		if shop_glyphs[k].dim != none:
			shop_glyphs[k].dim = none
			shop_glyphs[k].queue_redraw()
		shop_counts[k].add_theme_color_override("font_color", UiStyle.OFF if none else UiStyle.GOLD)


class DragRect:
	extends Control
	var ctrl: Controller
	func _draw() -> void:
		if ctrl and ctrl.dragging and ctrl.drag_now.distance_to(ctrl.drag_start) > 8.0:
			var r := Rect2(ctrl.drag_start, Vector2.ZERO).expand(ctrl.drag_now)
			draw_rect(r, Color(1.0, 0.82, 0.35, 0.12))
			draw_rect(r, Color(1.0, 0.82, 0.35, 0.95), false, 1.5)


class Minimap:
	extends TextureRect
	var game: Node
	const MW := 156.0
	const MH := 183.0

	func setup(g: Node) -> void:
		game = g
		var w: VoxelWorld = game.world
		const STEP := int(2 * Defs.MAP_SCALE)  # un pixel ogni STEP voxel: la minimappa resta leggera
		var img := Image.create(Defs.WX / STEP, Defs.WZ / STEP, false, Image.FORMAT_RGB8)
		for z in Defs.WZ / STEP:
			for x in Defs.WX / STEP:
				var tx := x * STEP
				var tz := z * STEP
				var top := w.top_y(tx, tz)
				var col := Color(0.07, 0.2, 0.34)
				if top > Defs.SEA:
					var m := w.get_v(tx, top - 1, tz)
					col = Defs.mat_color(m) if m < Defs.TEAM0 else Color.WHITE
					col = col.darkened(0.18)
				img.set_pixel(x, z, col)
		texture = ImageTexture.create_from_image(img)
		custom_minimum_size = Vector2(MW, MH)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_SCALE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Clic sinistro: sposta la vista\nClic destro: manda i soldati selezionati"

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed or (e is InputEventMouseMotion and (e as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
			var p: Vector2 = e.position
			var world_p := Vector3(p.x / size.x * Defs.WX, 0, p.y / size.y * Defs.WZ)
			if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				var sel: Dictionary = game.renderer.selected
				if not sel.is_empty():
					var ids := PackedInt32Array()
					for id: int in sel:
						ids.append(id)
					world_p.y = game.world.top_y(int(world_p.x), int(world_p.z))
					game.send_cmd("order", [ids, world_p, false])
			else:
				game.ctrl.focus.x = world_p.x
				game.ctrl.focus.z = world_p.z

	func _draw() -> void:
		var sx := size.x / Defs.WX
		var sz := size.y / Defs.WZ
		var f: Vector3 = game.ctrl.focus
		var half: float = game.ctrl.dist * 0.45
		draw_rect(Rect2((f.x - half) * sx, (f.z - half) * sz, half * 2 * sx, half * 2 * sz), Color(1, 1, 1, 0.8), false, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
		for c: Dictionary in game.castles:
			var ce: Vector3 = c.center
			var o: int = game.castle_owner(c.id)
			var pt := Vector2(ce.x * sx, ce.z * sz)
			if o == game.my_house:
				# il proprio castello è l'unico a rombo, con alone dorato (rosso e largo se lo attaccano)
				if not game.state.is_empty() and game.state[0][c.id][7]:
					var fp := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
					draw_arc(pt, 10.0 + fp * 8.0, 0.0, TAU, 24, UiStyle.DANGER_TEXT, 3.0, true)
				draw_arc(pt, 8.0 + pulse * 4.0, 0.0, TAU, 20, UiStyle.GOLD, 2.0, true)
				var d := PackedVector2Array([pt + Vector2(0, -7), pt + Vector2(7, 0), pt + Vector2(0, 7), pt + Vector2(-7, 0)])
				draw_colored_polygon(d, Defs.HOUSES[o].color)
				var dc := d.duplicate()
				dc.append(d[0])
				draw_polyline(dc, UiStyle.GOLD, 2.0, true)
			else:
				var r := Rect2(pt - Vector2(4, 4), Vector2(8, 8))
				draw_rect(r, Defs.HOUSES[o].color)
				draw_rect(r, Color.BLACK, false, 1.0)
		# truppe in campo (quelle nei castelli le rappresenta già il castello): puntini con bordo scuro, i propri sopra gli altri e con bordo chiaro: si vedono su ogni terreno
		var mine: Array[Vector2] = []
		for u: Game.VU in game.vunits.values():
			if _in_castle(u.cur):
				continue
			var q := Vector2(u.cur.x * sx, u.cur.z * sz)
			if u.team == game.my_house:
				mine.append(q)
				continue
			draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(q - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Defs.HOUSES[u.team].color)
		if not mine.is_empty():
			var mc: Color = Defs.HOUSES[game.my_house].color
			for q in mine:
				draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.95, 0.75))
			for q in mine:
				draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), mc)


	func _in_castle(p: Vector3) -> bool:
		for c: Dictionary in game.castles:
			var ce: Vector3 = c.center
			if absf(p.x - ce.x) < Sim.R + 2.0 and absf(p.z - ce.z) < Sim.R + 2.0:
				return true
		return false
