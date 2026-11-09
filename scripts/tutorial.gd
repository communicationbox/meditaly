class_name Tutorial
extends CanvasLayer
## Partita guidata: un passo alla volta, si avanza solo quando il giocatore ha fatto l'azione.
## Le altre casate restano ferme finché il tutorial non finisce.

const REINFORCE_EVERY := 10.0

var game: Node
var sim: Sim
var hud: Hud
var ctrl: Controller
var house := 0
var home: Dictionary
var target: Dictionary
var steps: Array[Dictionary] = []
var index := -1
var finished := false
var panel: PanelContainer
var _in_cine := false
var _cine_was: Array = [true, true]
var title_lbl: Label
var text_lbl: Label
var next_btn: Button
var skip_btn: Button
var overlay: Overlay
var beam: MeshInstance3D
var start_units := 0
var start_focus := Vector3.ZERO
var start_zoom := 0.0
var step_time := 0.0
var reinforce_t := 0.0


func setup(g: Node) -> void:
	game = g
	sim = g.sim
	hud = g.hud
	ctrl = g.ctrl
	house = g.my_house
	layer = 5
	sim.ai_enabled = false
	sim.houses[house].gold = maxf(float(sim.houses[house].gold), 300.0)
	home = g.castles[ctrl.selected_castle]
	target = _nearest_neutral()
	_build_ui()
	_build_beam()
	steps = [
		{"title": "Benvenuto, Signore!", "text": "Il tuo castello è %s: è quello con l'anello dorato e la scritta IL TUO CASTELLO.\n\nIl tuo scopo è conquistare tutti i 12 castelli d'Italia. Ti guido io, un passo alla volta: durante il tutorial nessuno ti attacca." % home.name, "manual": true},
		{"title": "Guardati intorno", "text": "Muovi la vista con i tasti W A S D, oppure avvicinati e allontanati con la rotella del mouse.\n\nProva adesso.", "enter": _enter_view, "done": _done_view},
		{"title": "Crea i soldati", "text": "Il pannello in basso a sinistra è il tuo castello, %s.\n\nClicca 3 volte il riquadro \"Fante\" che lampeggia. Ogni soldato costa fiorini: li guadagni da solo col tempo." % home.name, "enter": _enter_recruit, "done": _done_recruit, "mark": _mark_recruit},
		{"title": "Scegli i soldati", "text": "Ti ho mandato dei rinforzi!\n\nPer dare ordini devi prima selezionare i soldati: premi il tasto T.\nAttorno a loro compaiono anelli verdi.", "enter": _enter_select, "done": _done_select},
		{"title": "Muovili", "text": "Ora fai CLIC DESTRO su un punto del prato.\nI soldati selezionati ci vanno da soli.\n\nSe hai perso la selezione, premi di nuovo T.", "done": _done_move},
		{"title": "All'attacco!", "text": "%s è un castello senza padrone: è il bersaglio più facile.\n\nFai CLIC DESTRO sul cerchio che lampeggia sulla mappa in basso a destra.\nSe hai perso la selezione, premi prima T." % target.name, "done": _done_attack, "mark_map": true},
		{"title": "In marcia", "text": "I tuoi soldati stanno andando a %s. La vista li segue da sola.\n\nAspetta che arrivino." % target.name, "done": _done_march, "tick": _tick_march},
		{"title": "Un potere speciale", "text": "Ora il divertimento. Accanto al tuo castello è appena nato un caseificio: ogni potere ha bisogno della sua bottega (le costruisci fuori dalle mura dal pannello del castello).\n\nClicca il riquadro che lampeggia (o premi il tasto 1), poi fai CLIC SINISTRO sul castello. Arriva una forma di Parmigiano gigante!", "enter": _enter_power, "done": _done_power, "mark": _mark_power},
		{"title": "Conquista il castello", "text": "", "text_fn": _capture_text, "done": _done_capture, "tick": _tick_capture},
		{"title": "Difendi i tuoi castelli", "text": "Quando ti attaccano, seleziona il castello e usa i pulsanti che lampeggiano:\n\nSulle mura: i balestrieri salgono sulle mura\nRipara: ricostruisce ciò che è crollato\nMangano: tira una pietra dove clicchi\nOlio: brucia chi è vicino alle mura", "enter": _enter_defense, "mark": _mark_defense, "manual": true},
		{"title": "Ora tocca a te!", "text": "Da adesso le altre casate si muovono. Per 2 minuti c'è la tregua: nessuna ti attacca, approfittane per creare soldati.\n\nRicorda: crea soldati, premi T, clic destro sul nemico.\nPremi F1 quando vuoi rivedere i comandi.\n\nBuona conquista!", "manual": true, "last": true},
	]
	_go(0)


func _nearest_neutral() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e12
	for c: Dictionary in game.castles:
		if c.owner == Defs.NEUTRAL:
			var d: float = (c.center as Vector3).distance_squared_to(home.center)
			if d < bd:
				bd = d
				best = c
	return best


func _build_ui() -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.84, 0.68, 0.98)
	sb.border_color = Color(0.55, 0.11, 0.08)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(10, 92)
	panel.custom_minimum_size = Vector2(430, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.55, 0.11, 0.08))
	v.add_child(title_lbl)
	text_lbl = Label.new()
	text_lbl.add_theme_font_size_override("font_size", 16)
	text_lbl.add_theme_color_override("font_color", Color(0.18, 0.1, 0.05))
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.custom_minimum_size = Vector2(400, 0)
	v.add_child(text_lbl)
	var row := HBoxContainer.new()
	next_btn = Button.new()
	next_btn.text = "Avanti"
	next_btn.custom_minimum_size = Vector2(120, 36)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(_on_next)
	UiStyle.style_button(next_btn, Color(0.55, 0.11, 0.08), Color(0.55, 0.11, 0.08), Color(0.68, 0.16, 0.11))
	next_btn.add_theme_font_size_override("font_size", 16)
	row.add_child(next_btn)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	skip_btn = Button.new()
	skip_btn.text = "Salta il tutorial"
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.pressed.connect(_finish)
	UiStyle.style_button(skip_btn, Color(0.91, 0.84, 0.68, 0.0), Color(0.45, 0.32, 0.18), Color(0.82, 0.74, 0.56))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		skip_btn.add_theme_color_override(key, Color(0.25, 0.15, 0.08))
	row.add_child(skip_btn)
	v.add_child(row)
	overlay = Overlay.new()
	overlay.tut = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	add_child(panel)


## Colonna di luce sul castello da attaccare.
	# il tutorial non passa da UiStyle.label: i font vanno messi qui
	title_lbl.add_theme_font_override("font", UiStyle.title_font())
	text_lbl.add_theme_font_override("font", UiStyle.body_font())
	text_lbl.add_theme_font_size_override("font_size", 18)
	for b: Button in [next_btn, skip_btn]:
		b.add_theme_font_override("font", UiStyle.title_font())
		b.add_theme_font_size_override("font_size", 17)


func _build_beam() -> void:
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.0
	cyl.bottom_radius = 2.0
	cyl.height = 90.0
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.3)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	game.add_child(beam)
	beam.global_position = (target.center as Vector3) + Vector3(0, 45, 0)


func _go(i: int) -> void:
	index = i
	step_time = 0.0
	var s: Dictionary = steps[i]
	title_lbl.text = "%d/%d  %s" % [i + 1, steps.size(), s.title]
	text_lbl.text = s.text
	next_btn.visible = s.get("manual", false)
	next_btn.text = "Inizia a giocare" if s.get("last", false) else "Avanti"
	skip_btn.visible = not s.get("last", false)
	beam.visible = i >= 5 and i <= 8
	if s.has("enter"):
		(s.enter as Callable).call()
	panel.reset_size()


func _on_next() -> void:
	if steps[index].get("last", false):
		_finish()
	elif index + 1 < steps.size():
		_go(index + 1)


func _finish() -> void:
	if finished:
		return
	finished = true
	sim.ai_enabled = true
	sim.truce_until = sim.time + Sim.TRUCE_TIME
	beam.queue_free()
	queue_free()


func _process(dt: float) -> void:
	if finished or index < 0:
		return
	# durante la scena del re il tutorial aspetta nascosto
	var in_cine := not ctrl.cine.is_empty()
	if in_cine != _in_cine:
		_in_cine = in_cine
		if in_cine:
			_cine_was = [panel.visible, overlay.visible]
			panel.visible = false
			overlay.visible = false
		else:
			panel.visible = _cine_was[0]
			overlay.visible = _cine_was[1]
	if in_cine:
		return
	step_time += dt
	overlay.queue_redraw()
	var s: Dictionary = steps[index]
	if s.has("tick"):
		(s.tick as Callable).call(dt)
	if s.has("text_fn"):
		var t: String = (s.text_fn as Callable).call()
		if t != text_lbl.text:
			text_lbl.text = t
	if s.has("done") and (s.done as Callable).call():
		_go(index + 1)


# ---------------------------------------------------------------- passi
func _enter_view() -> void:
	start_focus = ctrl.focus
	start_zoom = ctrl.target_dist


func _done_view() -> bool:
	return ctrl.focus.distance_to(start_focus) > 8.0 or absf(ctrl.target_dist - start_zoom) > 5.0


func _enter_recruit() -> void:
	start_units = sim.house_unit_count(house)
	ctrl.focus = home.center
	ctrl.target_dist = 75.0


func _done_recruit() -> bool:
	if ctrl.selected_castle != home.id:
		ctrl.selected_castle = home.id
	var made: int = sim.house_unit_count(house) - start_units + (home.queue as Array).size()
	return made >= 3


func _mark_recruit() -> Variant:
	return hud.recruit_btns[Defs.FANTE].get_global_rect()


func _enter_select() -> void:
	var out: Vector3 = home.gate_out
	var dir: Vector3 = home.dir
	var side := Vector3(-dir.z, 0, dir.x)
	for k in 12:
		sim.spawn_unit(Defs.FANTE if k % 3 != 2 else Defs.BALESTRIERE, house, out + dir * (3 + k / 4 * 2.2) + side * (k % 4 - 1.5) * 2.2)
	sim.spawn_unit(Defs.CAVALIERE, house, out + dir * 10 + side * 5)
	sim.spawn_unit(Defs.CAVALIERE, house, out + dir * 10 - side * 5)
	game.renderer.selected.clear()
	ctrl.selected_castle = -1
	ctrl.focus = out + dir * 8
	ctrl.target_dist = 60.0


func _done_select() -> bool:
	return game.renderer.selected.size() >= 8


func _done_move() -> bool:
	for u: Sim.U in sim.ulist:
		if u.team == house and u.has_order:
			return true
	return false


func _done_attack() -> bool:
	var n := 0
	for u: Sim.U in sim.ulist:
		if u.team == house and u.goal == target.id:
			n += 1
	return n >= 5


func _army_center() -> Vector3:
	var s := Vector3.ZERO
	var n := 0
	for u: Sim.U in sim.ulist:
		if u.team == house and u.goal == target.id:
			s += u.pos
			n += 1
	return s / n if n > 0 else (target.center as Vector3)


func _tick_march(_dt: float) -> void:
	ctrl.focus = ctrl.focus.lerp(_army_center(), 0.08)


func _done_march() -> bool:
	return step_time > 45.0 or _army_center().distance_to(target.center) < 45.0


func _enter_power() -> void:
	var h: Dictionary = sim.houses[house]
	h.faith = 150.0
	h.cd[Defs.P_PARMIGIANO] = 0.0
	# il caseificio te lo regaliamo: ogni potere ha bisogno della sua bottega
	if not sim.has_building(house, Defs.B_CASEIFICIO):
		var spot := sim.find_spot(house, home)
		if spot.y > -0.5:
			sim.build_now(house, Defs.B_CASEIFICIO, spot)
	ctrl.focus = target.center
	ctrl.target_dist = 95.0
	ctrl.selected_castle = -1


func _done_power() -> bool:
	return float(sim.houses[house].cd[Defs.P_PARMIGIANO]) > 0.0


func _mark_power() -> Variant:
	return hud.power_btns[Defs.P_PARMIGIANO].get_global_rect()


func _capture_text() -> String:
	var pct := int(float(target.capture) * 100.0)
	var txt := "Il castello cade solo se muore il suo signore. Lo trovi nel mastio, la torre centrale, seduto sul gabinetto con la porta aperta.\n\nI soldati entrano nel cortile, battono i difensori e poi vanno dritti da lui: non devi fare nulla.\n\nSignore ferito: %d%%" % pct
	return txt


## Se l'esercito viene decimato arrivano rinforzi: il tutorial deve poter finire.
func _tick_capture(dt: float) -> void:
	reinforce_t += dt
	if reinforce_t < REINFORCE_EVERY:
		return
	reinforce_t = 0.0
	var near := 0
	var ce: Vector3 = target.center
	for u: Sim.U in sim.ulist:
		if u.team == house and u.pos.distance_to(ce) < 45.0:
			near += 1
	if near >= 8:
		return
	var ids := PackedInt32Array()
	var from := ce + (target.dir as Vector3) * 34.0
	for k in 8:
		var u := sim.spawn_unit(Defs.FANTE, house, from + Vector3(k % 4 * 2.2, 0, k / 4 * 2.2))
		ids.append(u.id)
	sim.cmd_order(house, ids, target.rally, false)


func _done_capture() -> bool:
	return target.owner == house


func _enter_defense() -> void:
	ctrl.selected_castle = target.id
	ctrl.focus = target.center
	ctrl.target_dist = 70.0
	game.renderer.selected.clear()


func _mark_defense() -> Variant:
	if ctrl.selected_castle < 0:
		ctrl.selected_castle = target.id
	return hud.def_box.get_global_rect()


func marked_rect() -> Variant:
	var s: Dictionary = steps[index]
	return (s.mark as Callable).call() if s.has("mark") else null


func map_point() -> Variant:
	if not steps[index].get("mark_map", false):
		return null
	var r: Rect2 = hud.minimap.get_global_rect()
	var ce: Vector3 = target.center
	return r.position + Vector2(ce.x / Defs.WX * r.size.x, ce.z / Defs.WZ * r.size.y)


class Overlay:
	extends Control
	var tut: Tutorial

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		var col := Color(1.0, 0.1 + 0.6 * pulse, 0.05)
		var r: Variant = tut.marked_rect()
		if r != null:
			var grown: Rect2 = (r as Rect2).grow(3.0 + pulse * 4.0)
			draw_rect(grown, col, false, 4.0)
		var p: Variant = tut.map_point()
		if p != null:
			draw_arc(p, 10.0 + pulse * 7.0, 0.0, TAU, 28, col, 3.0)
