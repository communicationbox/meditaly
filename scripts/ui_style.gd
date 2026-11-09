class_name UiStyle
extends RefCounted
## Identità dell'interfaccia: cartoon medievale. Cartelli di legno, contorni spessi, oro e colori pieni delle casate.

const WALNUT := Color(0.29, 0.165, 0.08, 0.985)
const WALNUT_LIGHT := Color(0.47, 0.27, 0.12)
const WALNUT_HOVER := Color(0.60, 0.36, 0.16)
const WALNUT_OFF := Color(0.24, 0.19, 0.15)
## Sotto questa misura il carattere medievale non si legge più.
const MIN_TEXT := 16
const OUTLINE := Color(0.17, 0.09, 0.04)
const GOLD := Color(1.0, 0.83, 0.33)
const GOLD_DIM := Color(0.85, 0.62, 0.22)
const INK := Color(1.0, 0.97, 0.88)
const MUTED := Color(0.98, 0.88, 0.70)
const OFF := Color(0.78, 0.71, 0.60)
const DANGER := Color(0.76, 0.16, 0.11)
const DANGER_TEXT := Color(1.0, 0.72, 0.62)

static var _title_font: Font
static var _body_font: Font
static var _world_font: Font
static var _comic_font: Font
static var _display_font: Font
static var _wood: ImageTexture


const FONT_DISPLAY := "res://assets/fonts/NewRocker-Regular.ttf"
const FONT_UI := "res://assets/fonts/Almendra-Bold.ttf"
const FONT_DIGITS := "res://assets/fonts/Cifre-NewRocker.ttf"
const FONT_BUBBLE := "res://assets/fonts/Almendra-Bold.ttf"


## Solo per i titoli grandi: gotico vero, che da piccolo non si leggerebbe.
static func display_font() -> Font:
	if _display_font == null:
		_display_font = load(FONT_DISPLAY)
	return _display_font


## Titoli di pannello, pulsanti e numeri: lo stesso carattere dei testi, ingrassato.
static func title_font() -> Font:
	if _title_font == null:
		var fv := FontVariation.new()
		fv.base_font = _with_digits()
		fv.variation_embolden = 0.2
		_title_font = fv
	return _title_font


## Testi: calligrafia medievale ma grassa, si legge anche piccola.
static func body_font() -> Font:
	if _body_font == null:
		var fv := FontVariation.new()
		fv.base_font = _with_digits()
		_body_font = fv
	return _body_font


## Le cifre vengono da un font a parte: quelle dell'Almendra fanno sembrare l'1 una I.
static func _with_digits() -> Font:
	var d: FontFile = load(FONT_DIGITS)
	if d.fallbacks.is_empty():
		d.fallbacks = [load(FONT_UI)]
	return d


## Fumetti dei soldati: calligrafia medievale grassa, si legge a colpo d'occhio.
static func comic_font() -> Font:
	if _comic_font == null:
		_comic_font = load(FONT_BUBBLE)
	return _comic_font


## Nomi sopra i castelli e insegne nel mondo: campo di distanza, restano nitidi a ogni zoom.
static func world_font() -> Font:
	if _world_font == null:
		var f := FontFile.new()
		f.data = (load(FONT_UI) as FontFile).data
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 14
		_world_font = f
	return _world_font


static func panel_box(bg: Color = WALNUT, border: Color = GOLD_DIM, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = OUTLINE if border == GOLD_DIM else border
	sb.set_border_width_all(3)
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Cartello di assi disegnato al volo: contorno spesso, venature e chiodi agli angoli.
static func wood_texture() -> ImageTexture:
	if _wood != null:
		return _wood
	const N := 96
	const R := 14.0
	const EDGE := 4.0
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var planks := [Color(0.30, 0.17, 0.083), Color(0.29, 0.163, 0.08), Color(0.305, 0.174, 0.086), Color(0.295, 0.167, 0.082)]
	for y in N:
		for x in N:
			var q := Vector2(absf(x + 0.5 - N * 0.5) - (N * 0.5 - R), absf(y + 0.5 - N * 0.5) - (N * 0.5 - R))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - R
			if d > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var c: Color = planks[(y / 24) % planks.size()]
			c = c.lightened(0.018 * sin(x * 0.21 + y * 1.3 + sin(y * 0.7) * 2.0))  # venature appena accennate: sopra ci si legge
			if y % 24 == 0:  # fra un'asse e l'altra solo un filo: una riga scura taglierebbe le scritte
				c = c.darkened(0.14)
			if d > -EDGE:
				c = OUTLINE
			img.set_pixel(x, y, c)
	for p: Vector2i in [Vector2i(12, 12), Vector2i(N - 13, 12), Vector2i(12, N - 13), Vector2i(N - 13, N - 13)]:
		for y in range(-3, 4):
			for x in range(-3, 4):
				if x * x + y * y <= 10:
					img.set_pixel(p.x + x, p.y + y, Color(0.72, 0.72, 0.74) if x + y < 0 else Color(0.36, 0.34, 0.36))
	_wood = ImageTexture.create_from_image(img)
	return _wood


static func wood_box(margin := 10) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = wood_texture()
	sb.set_texture_margin_all(24)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.set_content_margin_all(margin + 8)
	return sb


static func panel(margin := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", wood_box(margin))
	return p


static func label(text := "", size := 15, col: Color = INK, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(size, MIN_TEXT))
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_constant_override("outline_size", 0 if size < 22 else 4)  # sul legno scuro basta il contrasto: il contorno mangerebbe le lettere
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Pulsante «a tasto»: contorno spesso e un bordo basso che si schiaccia quando lo premi.
static func style_button(b: Button, base: Color = WALNUT_LIGHT, border: Color = GOLD_DIM, hover: Color = WALNUT_HOVER) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = base
	n.border_color = OUTLINE if border == GOLD_DIM else border
	n.set_border_width_all(2)
	n.border_width_bottom = 5
	n.set_corner_radius_all(9)
	n.set_content_margin_all(4)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = hover
	var pr := n.duplicate() as StyleBoxFlat
	pr.bg_color = base.darkened(0.12)
	pr.border_width_bottom = 2
	pr.content_margin_top = 7.0
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = WALNUT_OFF
	d.border_color = Color(OUTLINE, 0.6)
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
	b.add_theme_font_size_override("font_size", MIN_TEXT)
	b.add_theme_font_override("font", title_font())
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
	var edge := OUTLINE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.58), Vector2(w * 0.5, h), Vector2(0, h * 0.58)])
		draw_colored_polygon(pts, color)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, edge, 2.5, true)
