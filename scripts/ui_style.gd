class_name UiStyle
extends RefCounted
## Identità dell'interfaccia: pannelli in noce, oro come unico accento, il colore della casata come firma.

const WALNUT := Color(0.125, 0.085, 0.06, 0.95)
const WALNUT_LIGHT := Color(0.215, 0.15, 0.10)
const WALNUT_HOVER := Color(0.33, 0.23, 0.14)
const WALNUT_OFF := Color(0.14, 0.11, 0.09)
const GOLD := Color(0.93, 0.72, 0.30)
const GOLD_DIM := Color(0.58, 0.44, 0.20)
const INK := Color(0.97, 0.92, 0.80)
const MUTED := Color(0.76, 0.69, 0.57)
const OFF := Color(0.55, 0.50, 0.43)
const DANGER := Color(0.76, 0.16, 0.11)
const DANGER_TEXT := Color(1.0, 0.56, 0.47)

static var _title_font: Font
static var _body_font: Font
static var _world_font: Font


## Titoli e pulsanti: Hoefler Text, un romano classico da libro antico (font di sistema, niente file).
static func title_font() -> Font:
	if _title_font == null:
		# numeri allineati (lnum): quelli "da libro" dell'Hoefler fanno sembrare l'1 una I romana
		var fv := FontVariation.new()
		fv.base_font = _sys(["Hoefler Text", "Palatino", "Palatino Linotype", "Georgia", "serif"], 400)
		fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
		_title_font = fv
	return _title_font


## Testi e numeri: Charter, disegnato per restare leggibile anche piccolo.
## Peso 400: con 500 il sistema sceglieva le varianti seminere e tutto sembrava in grassetto.
static func body_font() -> Font:
	if _body_font == null:
		_body_font = _sys(["Charter", "Iowan Old Style", "Georgia", "Cambria", "serif"], 400)
	return _body_font


## Nomi sopra i castelli e insegne nel mondo: campo di distanza, restano nitidi a ogni zoom.
static func world_font() -> Font:
	if _world_font == null:
		var f := _sys(["Hoefler Text", "Palatino", "Palatino Linotype", "Georgia", "serif"], 700)
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 14
		_world_font = f
	return _world_font


static func _sys(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f


static func panel_box(bg: Color = WALNUT, border: Color = GOLD_DIM, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func panel(margin := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(WALNUT, GOLD_DIM, margin))
	return p


static func label(text := "", size := 15, col: Color = INK, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func style_button(b: Button, base: Color = WALNUT_LIGHT, border: Color = GOLD_DIM, hover: Color = WALNUT_HOVER) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = base
	n.border_color = border
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.set_content_margin_all(4)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = hover
	h.border_color = GOLD
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = base.darkened(0.25)
	pr.border_color = GOLD
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = WALNUT_OFF
	d.border_color = Color(0.3, 0.25, 0.2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", OFF)


static func button(text: String, tip: String, cb: Callable, minw := 96.0, minh := 40.0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(minw, minh)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", body_font())
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	style_button(b)
	return b


## Stemma disegnato: il segno ricorrente della casata in tutta l'interfaccia.
class Shield:
	extends Control
	var color := Color.WHITE
	var edge := GOLD

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.58), Vector2(w * 0.5, h), Vector2(0, h * 0.58)])
		draw_colored_polygon(pts, color)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, edge, 2.0, true)
