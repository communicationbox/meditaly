class_name TipLayer
extends CanvasLayer
## Tooltip del gioco: al posto del riquadro grigio di sistema, una scheda in stile
## agganciata sopra il controllo (non al cursore). Legge il tooltip_text di chi è sotto
## il mouse, quindi vale per tutta l'interfaccia senza toccare i singoli pulsanti.
## Prima riga: titolo «Nome: costo». Le righe «Serve…», «Limite…» sono avvisi in rosso;
## l'ultima riga con «·» sono le statistiche, in piccolo.

const DELAY := 0.35
const MAX_W := 300.0
const WARN := ["Serve", "Limite", "Niente", "Le partite", "Le riparazioni"]

var box: PanelContainer
var col: VBoxContainer
var target: Control
var text := ""
var hover_t := 0.0


func _ready() -> void:
	layer = 120
	box = PanelContainer.new()
	var sb := UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 0)
	sb.set_content_margin_all(0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 9
	sb.border_width_top = 2
	sb.border_color = UiStyle.GOLD_DIM
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	add_child(box)


func _process(dt: float) -> void:
	var c := get_viewport().gui_get_hovered_control()
	while c != null and c.tooltip_text == "":
		c = c.get_parent() as Control
	if c == null or not c.is_visible_in_tree():
		target = null
		hover_t = 0.0
		box.visible = false
		return
	if c != target:
		target = c
		hover_t = 0.0
		box.visible = false
	hover_t += dt
	if hover_t < DELAY:
		return
	if c.tooltip_text != text or not box.visible:
		text = c.tooltip_text
		_fill(text)
		box.visible = true
		box.reset_size()
	_place(c)


func _fill(t: String) -> void:
	for n in col.get_children():
		col.remove_child(n)
		n.queue_free()
	var lines := t.split("\n")
	for k in lines.size():
		var s := lines[k].strip_edges()
		if s == "":
			continue
		if k == 0 and lines.size() > 1:
			col.add_child(_title(s))
			var rule := ColorRect.new()
			rule.color = Color(UiStyle.GOLD_DIM, 0.5)
			rule.custom_minimum_size = Vector2(0, 1)
			col.add_child(rule)
			continue
		var warn := false
		for w: String in WARN:
			if s.begins_with(w):
				warn = true
		var stats := k == lines.size() - 1 and s.contains(" · ") and not warn and k > 1
		var l := UiStyle.label(s, 12 if stats else 14, UiStyle.DANGER_TEXT if warn else (UiStyle.MUTED if stats else UiStyle.INK))
		if warn:
			l.text = "▲ " + s
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = minf(MAX_W, l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x + 2)
		col.add_child(l)


## «Nonna: 45 fiorini» → nome in oro a sinistra, costo a destra.
func _title(s: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	var name_ := s
	var rest := ""
	var cut := s.find(": ")
	if cut > 0:
		name_ = s.substr(0, cut)
		rest = s.substr(cut + 2)
	var n := UiStyle.label(name_, 18, UiStyle.GOLD, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	if rest != "":
		var r := UiStyle.label(rest, 13, UiStyle.MUTED)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(r)
	return row


func _place(c: Control) -> void:
	var vs := get_viewport().get_visible_rect().size
	var r := c.get_global_rect()
	var s := box.get_combined_minimum_size()
	box.size = s
	var p := Vector2(r.get_center().x - s.x / 2.0, r.position.y - s.y - 8)
	if p.y < 6:
		p.y = r.end.y + 8
	p.x = clampf(p.x, 6, vs.x - s.x - 6)
	p.y = clampf(p.y, 6, vs.y - s.y - 6)
	box.position = p.round()
