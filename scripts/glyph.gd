class_name Glyph
extends Control
## Icone vettoriali di poteri e difese, disegnate senza file esterni.

const ORANGE := Color(1.0, 0.56, 0.12)
const YELLOW := Color(1.0, 0.84, 0.32)
const STONE := Color(0.72, 0.69, 0.63)
const WHITE := Color(0.97, 0.95, 0.9)
const DARK := Color(0.1, 0.08, 0.07)

var kind := ""
var dim := false


func _init(k := "") -> void:
	kind = k
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _c(col: Color) -> Color:
	return col.lerp(Color(0.32, 0.29, 0.26), 0.8) if dim else col


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	draw_set_transform(o, 0.0, Vector2(s / 100.0, s / 100.0))
	match kind:
		"meteore": _meteor()
		"parmigiano": _cheese()
		"vino": _wine()
		"terremoto": _quake()
		"scudo": _dome()
		"mucche": _cow()
		"mura": _walls()
		"ripara": _hammer()
		"mangano": _stone()
		"olio": _oil()
		"castello": _castle()
		"chiesa": _church()
		"stella": _star()
		"lucchetto": _lock()


func _meteor() -> void:
	for t: Array in [[20, 12, 58, 50, 7], [46, 6, 66, 40, 5], [8, 36, 44, 62, 5]]:
		draw_line(Vector2(t[0], t[1]), Vector2(t[2], t[3]), _c(ORANGE), t[4], true)
	draw_circle(Vector2(66, 66), 25, _c(ORANGE))
	draw_circle(Vector2(70, 70), 15, _c(YELLOW))


func _cheese() -> void:
	draw_circle(Vector2(50, 50), 42, _c(Color(0.80, 0.56, 0.16)))
	draw_circle(Vector2(50, 50), 33, _c(YELLOW))
	draw_colored_polygon(PackedVector2Array([Vector2(50, 50), Vector2(92, 28), Vector2(96, 62)]), _c(DARK))
	for h: Vector2 in [Vector2(36, 36), Vector2(30, 60), Vector2(54, 70)]:
		draw_circle(h, 5, _c(Color(0.86, 0.66, 0.24)))


func _wine() -> void:
	var red := Color(0.72, 0.1, 0.24)
	draw_colored_polygon(PackedVector2Array([Vector2(26, 10), Vector2(74, 10), Vector2(68, 44), Vector2(50, 54), Vector2(32, 44)]), _c(STONE))
	draw_colored_polygon(PackedVector2Array([Vector2(29, 22), Vector2(71, 22), Vector2(66, 42), Vector2(50, 50), Vector2(34, 42)]), _c(red))
	draw_rect(Rect2(46, 52, 8, 30), _c(STONE))
	draw_rect(Rect2(30, 82, 40, 8), _c(STONE))


func _quake() -> void:
	draw_rect(Rect2(8, 60, 84, 30), _c(Color(0.47, 0.33, 0.2)))
	draw_rect(Rect2(8, 54, 84, 8), _c(Color(0.42, 0.62, 0.26)))
	draw_polyline(PackedVector2Array([Vector2(50, 6), Vector2(38, 30), Vector2(56, 42), Vector2(42, 62), Vector2(58, 74), Vector2(46, 92)]), _c(YELLOW), 7.0, true)


func _dome() -> void:
	draw_arc(Vector2(50, 72), 42, PI, TAU, 28, _c(YELLOW), 8.0, true)
	draw_arc(Vector2(50, 72), 28, PI, TAU, 24, _c(Color(1.0, 0.84, 0.32, 0.5)), 5.0, true)
	draw_line(Vector2(4, 74), Vector2(96, 74), _c(STONE), 6.0)
	draw_rect(Rect2(44, 52, 12, 22), _c(STONE))


func _cow() -> void:
	draw_rect(Rect2(14, 34, 62, 36), _c(WHITE))
	draw_rect(Rect2(62, 22, 28, 28), _c(WHITE))
	draw_rect(Rect2(70, 42, 20, 10), _c(Color(0.95, 0.66, 0.66)))
	draw_rect(Rect2(26, 36, 20, 18), _c(DARK))
	draw_rect(Rect2(52, 52, 16, 14), _c(DARK))
	draw_circle(Vector2(78, 32), 3, _c(DARK))
	for x: int in [18, 34, 54, 68]:
		draw_rect(Rect2(x, 70, 7, 18), _c(WHITE))
	draw_line(Vector2(66, 22), Vector2(62, 12), _c(STONE), 4.0)
	draw_line(Vector2(86, 22), Vector2(90, 12), _c(STONE), 4.0)


func _walls() -> void:
	draw_rect(Rect2(10, 34, 80, 56), _c(STONE))
	for x: int in [10, 32, 54, 76]:
		draw_rect(Rect2(x, 18, 14, 18), _c(STONE))
	draw_rect(Rect2(40, 62, 20, 28), _c(DARK))


func _hammer() -> void:
	draw_line(Vector2(30, 90), Vector2(62, 36), _c(Color(0.62, 0.42, 0.22)), 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(34, 22), Vector2(66, 8), Vector2(90, 44), Vector2(60, 58)]), _c(STONE))


func _stone() -> void:
	draw_arc(Vector2(50, 90), 66, PI * 1.15, PI * 1.72, 16, _c(YELLOW), 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(68, 30), Vector2(86, 24), Vector2(98, 40), Vector2(90, 56), Vector2(70, 54), Vector2(62, 42)]), _c(STONE))
	draw_rect(Rect2(4, 76, 26, 16), _c(Color(0.62, 0.42, 0.22)))


func _oil() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(18, 10), Vector2(72, 10), Vector2(64, 40), Vector2(26, 40)]), _c(STONE))
	for x: int in [34, 50, 64]:
		draw_line(Vector2(x, 40), Vector2(x - 6, 76), _c(ORANGE), 7.0)
		draw_circle(Vector2(x - 6, 82), 7, _c(YELLOW))


func _castle() -> void:
	draw_rect(Rect2(16, 44, 68, 46), _c(STONE))
	for x: int in [12, 40, 68]:
		draw_rect(Rect2(x, 22, 20, 30), _c(STONE))
	draw_rect(Rect2(42, 66, 16, 24), _c(DARK))


func _church() -> void:
	draw_rect(Rect2(18, 46, 50, 44), _c(WHITE))
	draw_colored_polygon(PackedVector2Array([Vector2(12, 48), Vector2(43, 24), Vector2(74, 48)]), _c(Color(0.78, 0.33, 0.17)))
	draw_rect(Rect2(66, 20, 18, 70), _c(Color(0.7, 0.34, 0.22)))
	draw_rect(Rect2(72, 4, 6, 18), _c(YELLOW))
	draw_rect(Rect2(66, 9, 18, 5), _c(YELLOW))
	draw_rect(Rect2(36, 66, 14, 24), _c(DARK))


func _star() -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var r := 40.0 if k % 2 == 0 else 17.0
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(Vector2(50, 46) + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, _c(YELLOW))
	draw_line(Vector2(14, 92), Vector2(44, 70), _c(Color(0.2, 0.32, 0.7)), 10.0)


## Lucchetto: potere bloccato perché manca la bottega (diverso da "Fede insufficiente").
func _lock() -> void:
	draw_arc(Vector2(50, 44), 22, PI, TAU, 18, Color(0.95, 0.93, 0.88), 9.0, true)
	draw_line(Vector2(28, 44), Vector2(28, 54), Color(0.95, 0.93, 0.88), 9.0)
	draw_line(Vector2(72, 44), Vector2(72, 54), Color(0.95, 0.93, 0.88), 9.0)
	draw_rect(Rect2(16, 52, 68, 44), Color(0.93, 0.72, 0.30))
	draw_rect(Rect2(16, 52, 68, 44), Color(0.3, 0.2, 0.08), false, 3.0)
	draw_circle(Vector2(50, 70), 7, Color(0.2, 0.13, 0.06))
	draw_rect(Rect2(46, 72, 8, 14), Color(0.2, 0.13, 0.06))
