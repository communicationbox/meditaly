class_name Finale
extends Node3D
## Il gran finale di chi vince: notte stellata, il re portato in trionfo sullo scudo attorno
## alla tavola, banchetto con la porchetta, fuochi d'artificio e il menestrello legato all'albero
## perché non canti. Citazione affettuosa dei finali dei fumetti. Solo grafica, lato client:
## il set sta fuori dalla mappa, come quello del re sul gabinetto.

signal finished

const POS := Vector3(-300.0, 40.0, 320.0)
const R_PROC := 10.5  # raggio del giro del corteo: largo, così lo scudo passa fuori dai pali
const SPEED := 0.2  # radianti al secondo: passo da corteo
const SHOT_A := 7.0  # il corteo arriva
const SHOT_B := 13.5  # la tavola
const SHOT_C := 19.0  # il menestrello
const FADE_AT := 26.0  # la gru sale sulle stelle, poi nero
const END := 27.5
const TREE := Vector3(-16.5, 0.0, -4.0)  # fuori dal giro del corteo, chioma compresa
const FIRE := Vector3(0.0, 0.0, -6.5)
const HILL := Vector3(0.0, 0.0, -104.0)  # la collina col castello vero della casata
const HILL_H := 14.0
const HILL_TOP := 34.0
const HILL_FOOT := 74.0
const SHIELD_R := 1.6  # lo scudo del re, raggio in metri
const HOUSES_AT := [Vector3(13.5, 0, -10.0), Vector3(12.0, 0, -21.0), Vector3(23.0, 0, 13.0), Vector3(-7.0, 0, -17.0), Vector3(5.0, 0, -18.0), Vector3(-20.0, 0, 8.0)]

const DOME_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;
varying vec3 dir;
void vertex() { dir = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void fragment() {
	vec3 d = normalize(dir);
	vec3 top = vec3(0.01, 0.02, 0.07);
	vec3 hor = vec3(0.09, 0.11, 0.27);
	vec3 col = mix(hor, top, smoothstep(0.0, 0.6, d.y));
	vec3 g = floor(d * 170.0);
	float h = hash(g);
	if (h > 0.9965 && d.y > 0.04) {
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 30.0) + h * 100.0);
		col += vec3(1.0, 0.95, 0.85) * (h - 0.9965) / 0.0035 * 2.2 * tw;
	}
	vec3 m = normalize(vec3(0.45, 0.42, -0.79));
	float md = dot(d, m);
	col += vec3(0.5, 0.55, 0.75) * smoothstep(0.95, 1.0, md) * 0.25;
	if (md > 0.9985) {
		col = vec3(1.9, 1.85, 1.6);
	}
	// colline scure all'orizzonte
	float a = atan(d.z, d.x);
	float hill = 0.035 + 0.03 * sin(a * 3.0 + 1.0) + 0.018 * sin(a * 7.0 + 2.0) + 0.008 * sin(a * 17.0);
	if (d.y < hill) {
		col = vec3(0.015, 0.03, 0.03);
	}
	ALBEDO = col;
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform float boost = 2.6;
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * boost;
}
"""

## I razzi: ogni scintilla è un'istanza col suo colore, accesa abbastanza da fare bagliore.
const SPARK_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
varying vec3 c;
void vertex() { c = INSTANCE_CUSTOM.rgb; }
void fragment() { ALBEDO = c * c * 2.2; }
"""

var game: Node
var house := 0
var cam: Camera3D
var mat: StandardMaterial3D
var glow: ShaderMaterial
var shield: Node3D  # lo scudo col re sopra; le braccia sono figlie e girano dalla spalla
var arm_l: MeshInstance3D
var arm_r: MeshInstance3D
var _people: Array = []  # [MultiMesh, indice, posizione, direzione, fase]: chi festeggia a tavola
var bearers: MultiMesh
var diners: Array = []  # [MultiMesh, posizioni, ondeggia]
var bard: MultiMesh
var flames: MeshInstance3D
var fire_light: OmniLight3D
var notes: Label3D
var sparks: MultiMesh
var _bursts: Array = []  # [centro, inizio, colore, seme]
var _next_burst := 0.0
var _t := 0.0
var _saved := {}
var _ui: CanvasLayer
var _fade: ColorRect
var _cap: Label
var _card: Control
var _ended := false
## Ingombri a terra [centro, raggio] di pali, alberi, case e falò: il corteo deve passarci lontano.
var colliders: Array = []
## Dove si mette la telecamera: lì niente alberi davanti all'obiettivo.
var cam_spots: Array = []
var _castle_yaw := 0.0  # gira il castello con la porta verso la festa


func setup(g: Node, winner: int) -> void:
	game = g
	house = winner
	position = POS
	mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	glow = ShaderMaterial.new()
	glow.shader = Shader.new()
	glow.shader.code = GLOW_SHADER
	cam_spots = [_shot_a_cam(), TREE + Vector3(-2.6, 0, 4.6), TREE + Vector3(-1.6, 0, 3.2)]
	_build()
	_night(true)
	if game.hud:
		game.hud.visible = false
	if game.ctrl:
		game.ctrl.set_process(false)
		game.ctrl.set_process_unhandled_input(false)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	_build_ui()
	_tick_camera()
	if game.fx and game.fx.sfx:
		game.fx.sfx.play("horn", global_position, 6.0, 0.0)


# ---------------------------------------------------------------- il set

func _build() -> void:
	var dome := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 230.0
	sp.height = 460.0
	sp.radial_segments = 48
	sp.rings = 24
	dome.mesh = sp
	var dm := ShaderMaterial.new()
	dm.shader = Shader.new()
	dm.shader.code = DOME_SHADER
	dome.material_override = dm
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	# prato scuro fino all'orizzonte: dall'alto non si deve vedere il mare della mappa
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(470, 470)
	far.mesh = pm
	far.position.y = -0.32
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.1, 0.2, 0.09)
	fm.roughness = 1.0
	far.material_override = fm
	add_child(far)
	var set_ := MeshInstance3D.new()
	set_.mesh = _set_mesh()
	set_.material_override = mat
	add_child(set_)
	var castle := MeshInstance3D.new()
	castle.mesh = _castle_mesh()
	castle.material_override = mat
	castle.position = HILL + Vector3(0, HILL_H, 0)
	castle.rotation.y = _castle_yaw
	add_child(castle)
	_light(HILL + Vector3(0, HILL_H + 8.0, 0), Color(1.0, 0.7, 0.4), 3.0, 46.0)  # il cortile illuminato a festa
	# fiaccole davanti alle mura: il castello si vede anche di notte, caldo contro il cielo blu
	for fx: float in [-18.0, 0.0, 18.0]:
		_light(HILL + Vector3(fx, HILL_H + 5.0, 34.0), Color(1.0, 0.62, 0.3), 4.5, 34.0)
	_light(HILL + Vector3(0, HILL_H + 26.0, 30.0), Color(1.0, 0.75, 0.45), 3.0, 40.0)
	var lit := MeshInstance3D.new()
	lit.mesh = _lanterns_mesh()
	lit.material_override = glow
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lit)
	flames = MeshInstance3D.new()
	flames.mesh = _flames_mesh()
	flames.material_override = glow
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.position = FIRE
	add_child(flames)
	fire_light = _light(FIRE + Vector3(0, 1.6, 0), Color(1.0, 0.55, 0.22), 5.0, 22.0)
	_light(Vector3(0, 4.2, 0), Color(1.0, 0.78, 0.45), 2.2, 12.0)
	_light(Vector3(-7.4, 3.0, 1.0), Color(1.0, 0.62, 0.3), 1.6, 9.0)
	_light(Vector3(7.4, 3.0, 1.0), Color(1.0, 0.62, 0.3), 1.6, 9.0)
	_light(TREE + Vector3(2.5, 2.6, 3.0), Color(1.0, 0.7, 0.4), 1.4, 7.0)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.95)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-35, 150, 0)
	add_child(moon)
	# la gente della casata: in piedi dietro la tavola, a brindare
	var models := UnitModels.new()
	var meshes: Array = game.renderer.unit_meshes
	var places := {Defs.FANTE: [], Defs.BALESTRIERE: [], Defs.NONNA: [], Defs.FRATE: []}
	var order := [Defs.FANTE, Defs.BALESTRIERE, Defs.NONNA, Defs.FANTE, Defs.FRATE, Defs.FANTE, Defs.BALESTRIERE, Defs.NONNA, Defs.FANTE]
	for k in order.size():
		var x := -5.2 + float(k) * 1.3
		places[order[k]].append([Vector3(x, 0, -1.55), 0.0])
	places[Defs.FANTE].append([Vector3(-6.9, 0, 0.0), PI * 0.5])
	places[Defs.FRATE].append([Vector3(6.9, 0, 0.0), -PI * 0.5])
	places[Defs.BALESTRIERE].append([Vector3(-3.0, 0, 1.75), PI])
	places[Defs.NONNA].append([Vector3(3.4, 0, 1.75), PI])
	var drunk := 0
	for type: int in places:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[type]
		mm.instance_count = places[type].size()
		for i in mm.instance_count:
			var pl: Array = places[type][i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(pl[1])), pl[0]))
			_people.append([mm, i, pl[0], float(pl[1]), randf() * 10.0])
			var tipsy := 10.0 if (type == Defs.FANTE and drunk < 2) else 0.0  # un paio ha brindato troppo
			if tipsy > 0.0:
				drunk += 1
			mm.set_instance_custom_data(i, Color(randf() * 6.0, 0.0, 1.0, float(house) + tipsy))
		_mmi(mm)
	# il menestrello, legato all'albero perché non canti
	bard = MultiMesh.new()
	bard.transform_format = MultiMesh.TRANSFORM_3D
	bard.use_custom_data = true
	bard.mesh = meshes[Defs.MENESTRELLO]
	bard.instance_count = 1
	bard.set_instance_transform(0, Transform3D(Basis.IDENTITY, TREE + Vector3(0, 0, 0.72)))
	bard.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, float(house)))
	_mmi(bard)
	notes = Label3D.new()
	notes.text = "mmh mmh ♪"
	notes.font = UiStyle.comic_font()
	notes.font_size = 72
	notes.outline_size = 16
	notes.pixel_size = 0.0035
	notes.modulate = Color(0.95, 0.85, 0.4)
	notes.outline_modulate = Color(0.15, 0.08, 0.03)
	notes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(notes)
	# il re sullo scudo e chi lo porta
	var robe: Color = Defs.HOUSES[house].color
	shield = Node3D.new()
	add_child(shield)
	var glow_king := OmniLight3D.new()  # una fiaccola che lo accompagna: il re non resta in controluce
	glow_king.light_color = Color(1.0, 0.72, 0.42)
	glow_king.light_energy = 2.2
	glow_king.omni_range = 7.0
	glow_king.position = Vector3(0, 2.2, 2.4)
	shield.add_child(glow_king)
	var body := MeshInstance3D.new()
	body.mesh = models.re_trionfo(robe)
	body.material_override = mat
	shield.add_child(body)
	var arm_mesh := UnitModels.new().re_braccio(robe)
	for sx: float in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = mat
		arm.position = Vector3(UnitModels.RE_SPALLA.x * sx, UnitModels.RE_SPALLA.y, 0.0)
		shield.add_child(arm)
		if sx < 0.0:
			arm_l = arm
		else:
			arm_r = arm
	bearers = MultiMesh.new()
	bearers.transform_format = MultiMesh.TRANSFORM_3D
	bearers.use_custom_data = true
	bearers.mesh = UnitModels.new().portatore()
	bearers.instance_count = 4
	for i in 4:
		bearers.set_instance_custom_data(i, Color(float(i) * 1.6, 1.0, 0.0, float(house)))
	_mmi(bearers)
	# fuochi d'artificio
	sparks = MultiMesh.new()
	sparks.transform_format = MultiMesh.TRANSFORM_3D
	sparks.use_custom_data = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	sparks.mesh = bm
	sparks.instance_count = 6 * 28
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = sparks
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = SPARK_SHADER
	smi.material_override = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)
	for i in sparks.instance_count:
		sparks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))


func _mmi(mm: MultiMesh) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = game.renderer.unit_material
	add_child(mi)
	return mi


func _light(p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	add_child(l)
	return l


## Prato, sentiero del corteo, tavola imbandita, panche, falò, pali delle lanterne, albero e corde.
func _set_mesh() -> ArrayMesh:
	var m := UnitModels.new()
	m._begin(1.0)
	var grass := Color(0.27, 0.46, 0.2)
	var dirt := Color(0.5, 0.38, 0.24)
	for gz in range(-30, 30, 2):
		for gx in range(-30, 30, 2):
			var c := Vector2(gx + 1, gz + 1)
			var r := c.length()
			var n := 0.9 + 0.2 * fposmod(sin(gx * 12.9 + gz * 78.2) * 437.5, 1.0)
			var col := grass * n
			if absf(r - R_PROC) < 1.2:
				col = dirt * n
			m._b(Vector3(gx, -0.3, gz), Vector3(gx + 2, 0.0, gz + 2), col)
	# tavola: gambe, piano di legno, tovaglia bianca a righe rosse
	var wood := UnitModels.WOODC
	for x: float in [-5.6, 5.4]:
		for z: float in [-0.6, 0.5]:
			m._b(Vector3(x, 0.0, z), Vector3(x + 0.2, 0.92, z + 0.2), wood)
	m._b(Vector3(-6.0, 0.92, -0.8), Vector3(6.0, 1.04, 0.8), wood)
	m._b(Vector3(-5.9, 1.04, -0.84), Vector3(5.9, 1.07, 0.84), Color(0.95, 0.93, 0.86))
	for k in 12:
		var x := -5.6 + float(k) * 1.0
		m._b(Vector3(x, 1.04, -0.86), Vector3(x + 0.3, 1.075, 0.86), Color(0.78, 0.14, 0.12))
	# panche
	for z: float in [-1.3, 1.25]:
		m._b(Vector3(-5.6, 0.0, z), Vector3(5.6, 0.5, z + 0.12), wood * 0.8)
	# porchette sui taglieri, con la mela in bocca
	# porchette sul tagliere: crosta dorata a strati, muso rosa, orecchie, zampette, codino e mela in bocca
	var crust := Color(0.82, 0.5, 0.2)
	var pink := Color(0.93, 0.62, 0.52)
	for px: float in [-0.2, -3.8, 3.4]:
		m._b(Vector3(px - 1.15, 1.07, -0.5), Vector3(px + 1.25, 1.13, 0.5), wood * 1.2)
		m._b(Vector3(px - 0.85, 1.13, -0.3), Vector3(px + 0.55, 1.45, 0.3), crust * 0.9)
		m._b(Vector3(px - 0.75, 1.45, -0.24), Vector3(px + 0.45, 1.6, 0.24), crust)
		m._b(Vector3(px - 0.6, 1.6, -0.14), Vector3(px + 0.3, 1.66, 0.14), crust * 1.1)
		for kx in 4:  # tagli della crosta
			m._b(Vector3(px - 0.55 + kx * 0.28, 1.6, -0.25), Vector3(px - 0.5 + kx * 0.28, 1.62, 0.25), crust * 0.6)
		m._b(Vector3(px + 0.55, 1.18, -0.22), Vector3(px + 0.9, 1.52, 0.22), pink)
		m._b(Vector3(px + 0.9, 1.22, -0.12), Vector3(px + 1.02, 1.4, 0.12), pink * 0.92)
		m._b(Vector3(px + 0.6, 1.52, -0.24), Vector3(px + 0.74, 1.64, -0.1), pink * 0.9)
		m._b(Vector3(px + 0.6, 1.52, 0.1), Vector3(px + 0.74, 1.64, 0.24), pink * 0.9)
		m._b(Vector3(px + 0.8, 1.42, -0.16), Vector3(px + 0.86, 1.47, -0.1), Color(0.1, 0.06, 0.05))
		m._b(Vector3(px + 0.8, 1.42, 0.1), Vector3(px + 0.86, 1.47, 0.16), Color(0.1, 0.06, 0.05))
		m._b(Vector3(px + 1.02, 1.24, -0.11), Vector3(px + 1.2, 1.4, 0.11), Color(0.85, 0.1, 0.08))
		m._b(Vector3(px + 1.08, 1.4, -0.02), Vector3(px + 1.12, 1.48, 0.02), Color(0.3, 0.5, 0.15))
		m._b(Vector3(px - 1.0, 1.42, -0.03), Vector3(px - 0.85, 1.48, 0.03), pink)
		m._b(Vector3(px - 1.06, 1.46, -0.03), Vector3(px - 0.98, 1.56, 0.03), pink)
		for zz: float in [-0.3, 0.22]:
			m._b(Vector3(px + 0.3, 1.13, zz), Vector3(px + 0.5, 1.22, zz + 0.08), pink)
			m._b(Vector3(px - 0.7, 1.13, zz), Vector3(px - 0.5, 1.22, zz + 0.08), pink)
		# fette già tagliate sul tagliere
		m._b(Vector3(px - 1.1, 1.13, 0.32), Vector3(px - 0.8, 1.2, 0.46), Color(0.95, 0.85, 0.75))
	# forma di parmigiano, pane, fiaschi e boccali
	m._b(Vector3(1.4, 1.07, -0.35), Vector3(2.1, 1.4, 0.35), Color(0.95, 0.82, 0.45))
	m._b(Vector3(1.45, 1.4, -0.3), Vector3(2.05, 1.44, 0.3), Color(0.8, 0.6, 0.25))
	for k in 9:
		var x := -5.4 + float(k) * 1.3
		var z := -0.55 if k % 2 == 0 else 0.4
		m._b(Vector3(x + 0.5, 1.07, z), Vector3(x + 0.72, 1.33, z + 0.22), Color(0.78, 0.8, 0.82))  # boccale
		m._b(Vector3(x + 0.52, 1.3, z + 0.02), Vector3(x + 0.7, 1.35, z + 0.2), Color(0.95, 0.92, 0.85))  # schiuma
		if k % 3 == 1:  # fiasco impagliato
			m._b(Vector3(x + 0.1, 1.07, -z * 0.4), Vector3(x + 0.38, 1.36, -z * 0.4 + 0.28), Color(0.78, 0.62, 0.3))
			m._b(Vector3(x + 0.16, 1.36, -z * 0.4 + 0.06), Vector3(x + 0.32, 1.62, -z * 0.4 + 0.22), Color(0.2, 0.42, 0.18))
		if k % 3 == 2:  # pagnotta
			m._b(Vector3(x, 1.07, -0.1), Vector3(x + 0.42, 1.25, 0.2), Color(0.8, 0.55, 0.28))
	# falò: tronchi incrociati e pietre attorno
	for k in 8:
		var a := float(k) / 8.0 * TAU
		var q := FIRE + Vector3(cos(a), 0, sin(a)) * 1.3
		m._b(q - Vector3(0.25, 0, 0.25), q + Vector3(0.25, 0.3, 0.25), Color(0.4, 0.4, 0.42))
	m._b(FIRE + Vector3(-0.9, 0.0, -0.15), FIRE + Vector3(0.9, 0.3, 0.15), Color(0.3, 0.18, 0.1))
	m._b(FIRE + Vector3(-0.15, 0.1, -0.9), FIRE + Vector3(0.15, 0.4, 0.9), Color(0.34, 0.2, 0.1))
	# pali delle lanterne e torce ai capi della tavola
	for x: float in [-7.4, 7.4]:
		m._b(Vector3(x - 0.1, 0.0, -0.1), Vector3(x + 0.1, 4.6, 0.1), wood)
		m._b(Vector3(x - 0.08, 0.0, 0.92), Vector3(x + 0.08, 2.6, 1.08), wood)
	# l'albero del menestrello, con le corde attorno al tronco e il bavaglio
	var bark := Color(0.38, 0.25, 0.14)
	m._b(TREE + Vector3(-0.45, 0.0, -0.45), TREE + Vector3(0.45, 5.0, 0.45), bark)
	m._b(TREE + Vector3(-1.2, 3.2, -0.2), TREE + Vector3(-0.45, 3.5, 0.2), bark)
	m._b(TREE + Vector3(0.45, 3.6, -0.2), TREE + Vector3(1.3, 3.9, 0.2), bark)
	var leaf := Color(0.16, 0.34, 0.14)
	for b: Array in [[Vector3(-2.4, 4.4, -2.0), Vector3(2.4, 6.4, 2.0)], [Vector3(-1.8, 6.4, -1.6), Vector3(1.8, 7.6, 1.6)], [Vector3(-2.8, 4.8, -1.2), Vector3(-1.6, 5.9, 1.4)], [Vector3(1.6, 4.6, -1.4), Vector3(2.9, 5.8, 1.0)], [Vector3(-1.0, 7.6, -0.8), Vector3(1.0, 8.2, 0.8)]]:
		m._b(TREE + b[0], TREE + b[1], leaf * (0.85 + 0.1 * float(b[0].y)))
	var rope := Color(0.72, 0.58, 0.34)
	# tre giri di corda sottile attorno al tronco e al menestrello
	for y: float in [0.5, 0.95, 1.3]:
		m._b(TREE + Vector3(-0.47, y, 0.99), TREE + Vector3(0.47, y + 0.05, 1.04), rope)
		m._b(TREE + Vector3(-0.47, y, -0.47), TREE + Vector3(0.47, y + 0.05, -0.42), rope)
		m._b(TREE + Vector3(-0.5, y, -0.47), TREE + Vector3(-0.45, y + 0.05, 1.04), rope)
		m._b(TREE + Vector3(0.45, y, -0.47), TREE + Vector3(0.5, y + 0.05, 1.04), rope)
	# il bavaglio sulla bocca (il viso del menestrello va da 1,47 a 1,80) e sopra gli occhi aperti,
	# così si capisce che è la bocca a essere chiusa, non gli occhi
	var face := TREE + Vector3(0, 0, 0.72)
	var cloth := Color(0.96, 0.94, 0.88)
	m._b(face + Vector3(-0.19, 1.5, -0.19), face + Vector3(0.19, 1.62, 0.21), cloth)
	m._b(face + Vector3(-0.05, 1.46, -0.24), face + Vector3(0.05, 1.6, -0.18), cloth)  # il nodo dietro
	for ex: float in [-0.1, 0.04]:
		m._b(face + Vector3(ex, 1.69, 0.17), face + Vector3(ex + 0.06, 1.76, 0.2), Color(0.08, 0.06, 0.06))
	# attorno: il bosco, il borgo e il castello sulla collina
	_surroundings(m)
	return m.st.commit()


## Bosco tutt'attorno, un borgo di case con le finestre e, sulla collina dietro il falò,
## il castello di casa di chi ha vinto, copiato voxel per voxel dalla mappa.
func _surroundings(m: UnitModels) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var leaf := Color(0.14, 0.3, 0.13)
	var bark := Color(0.36, 0.24, 0.14)
	for x: float in [-7.4, 7.4]:
		colliders.append([Vector3(x, 0, 0), 0.2])
		colliders.append([Vector3(x, 0, 1.0), 0.2])
	colliders.append([TREE, 2.9])
	colliders.append([FIRE, 1.6])
	# il borgo: case bianche col tetto di coppi a gradini, porta e comignolo
	for k in HOUSES_AT.size():
		var o: Vector3 = HOUSES_AT[k]
		var w := 1.8 + 0.4 * float(k % 2)
		var face := -o.normalized()  # la porta guarda la festa
		var along_x := absf(face.x) > absf(face.z)
		var hx := 1.6 if along_x else w
		var hz := w if along_x else 1.6
		m._b(o + Vector3(-hx, 0, -hz), o + Vector3(hx, 2.6, hz), Color(0.88, 0.84, 0.74))
		m._b(o + Vector3(-hx - 0.2, 2.6, -hz - 0.2), o + Vector3(hx + 0.2, 2.9, hz + 0.2), Color(0.66, 0.26, 0.16))
		m._b(o + Vector3(-hx * 0.7, 2.9, -hz * 0.7), o + Vector3(hx * 0.7, 3.3, hz * 0.7), Color(0.6, 0.23, 0.14))
		m._b(o + Vector3(-hx * 0.35, 3.3, -hz * 0.35), o + Vector3(hx * 0.35, 3.6, hz * 0.35), Color(0.56, 0.21, 0.13))
		m._b(o + Vector3(hx * 0.4, 3.0, hz * 0.3), o + Vector3(hx * 0.4 + 0.4, 4.0, hz * 0.3 + 0.4), Color(0.5, 0.46, 0.42))
		var door := o + Vector3(face.x * (hx + 0.03), 0, face.z * (hz + 0.03))
		var side := Vector3(-face.z, 0, face.x).normalized() * 0.35
		m._b(door - side.abs() - Vector3(0.03, 0, 0.03), door + side.abs() + Vector3(0.03, 1.5, 0.03), UnitModels.WOODC)
		colliders.append([o, Vector2(hx, hz).length()])
	# il bosco, fuori dal giro del corteo e lontano dalle telecamere
	var placed := 0
	var tries := 0
	while placed < 52 and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(16.5, 40.0)
		var q := Vector3(cos(a) * r, 0, sin(a) * r)
		if q.z > 8.0 and absf(q.x) < 16.0:
			continue  # davanti resta aperto: di lì guarda la telecamera
		if q.z < -32.0:
			continue  # lì comincia la collina
		var w := rng.randf_range(1.4, 2.4)
		var clash := false
		for c: Array in colliders:
			if q.distance_to(c[0]) < float(c[1]) + w + 0.8:
				clash = true
		for cs: Vector3 in cam_spots:
			if Vector2(q.x - cs.x, q.z - cs.z).length() < w + 3.0:
				clash = true
		if clash:
			continue
		var h := rng.randf_range(3.0, 5.0)
		m._b(q + Vector3(-0.35, 0, -0.35), q + Vector3(0.35, h, 0.35), bark)
		m._b(q + Vector3(-w, h - 0.6, -w), q + Vector3(w, h + 1.6, w), leaf * rng.randf_range(0.8, 1.15))
		m._b(q + Vector3(-w * 0.6, h + 1.6, -w * 0.6), q + Vector3(w * 0.6, h + 2.5, w * 0.6), leaf * rng.randf_range(0.85, 1.2))
		colliders.append([q, w])
		placed += 1
	# la collina a gradoni bassi, come i rilievi della mappa, con la cima piatta per il castello,
	# una strada di terra che sale dritta alla porta e qualche albero sui fianchi
	for gz in range(-78, 78, 2):
		for gx in range(-78, 78, 2):
			var lx := float(gx) + 1.0
			var lz := float(gz) + 1.0
			var d := Vector2(lx, lz).length()
			if d > HILL_FOOT:
				continue
			var p := HILL + Vector3(lx, 0, lz)
			var h := HILL_H * (1.0 - smoothstep(HILL_TOP, HILL_FOOT, d))
			h += (sin(lx * 0.31 + lz * 0.17) + sin(lx * 0.11 - lz * 0.23)) * 0.7 * smoothstep(HILL_TOP, HILL_TOP + 8.0, d)
			h = maxf(roundf(h), 0.0)
			if h < 0.5:
				continue
			var n := 0.88 + 0.16 * fposmod(sin(lx * 12.9 + lz * 78.2) * 437.5, 1.0)
			var col := Color(0.24, 0.42, 0.2) * n
			var road := absf(lx) < 2.6 + 0.08 * (lz - HILL_TOP) and lz > HILL_TOP - 6.0
			if road:
				col = Color(0.52, 0.4, 0.26) * n
			elif d > HILL_TOP + 3.0 and fposmod(sin(lx * 3.1 + lz * 5.7) * 91.7, 1.0) > 0.93:
				col = Color(0.5, 0.48, 0.44) * n  # qualche roccia
			m._b(p - Vector3(1, 0.3, 1), p + Vector3(1, h, 1), col)
			if not road and d > HILL_TOP + 4.0 and fposmod(sin(lx * 7.3 - lz * 2.9) * 53.1, 1.0) > 0.965:
				var w := 1.6
				m._b(p + Vector3(-0.3, h, -0.3), p + Vector3(0.3, h + 3.2, 0.3), bark)
				m._b(p + Vector3(-w, h + 2.6, -w), p + Vector3(w, h + 4.6, w), leaf * n)
	# la strada continua nel prato fino al borgo
	for z in range(int(HILL.z + HILL_FOOT) - 2, -16, 2):
		m._b(Vector3(-2.2, -0.29, z), Vector3(2.2, 0.02, z + 2), Color(0.5, 0.38, 0.24) * (0.9 + 0.1 * sin(z * 1.3)))


## Il castello di casa della casata, preso dalla mappa: mura, torri, mastio e bandiere come in partita.
func _castle_mesh() -> ArrayMesh:
	var world: VoxelWorld = game.world
	var c: Dictionary = game.castles[0]
	for cc: Dictionary in game.castles:
		if int(cc.get("start_house", -1)) == house:
			c = cc
	var ctr: Vector3 = c.center
	var b: int = int(c.base)
	var gd: Vector3 = c.dir
	_castle_yaw = -atan2(gd.x, gd.z)
	var cut := WorldGen.R + 7
	VoxelWorld._setup_tables()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pal := Defs.PALETTE
	var dirs := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var cx := int(ctr.x)
	var cz := int(ctr.z)
	var y0 := b - 3
	for z in range(cz - cut, cz + cut + 1):
		for x in range(cx - cut, cx + cut + 1):
			if Vector2(x - cx, z - cz).length() > cut:
				continue
			for y in range(y0, mini(b + WorldGen.KEEP_H + 12, Defs.WY)):
				var mt := world.get_v(x, y, z)
				if mt == 0:
					continue
				var c0: Color = Defs.HOUSES[mt - Defs.TEAM0].color if mt >= Defs.TEAM0 else pal[mt]
				var hv: int = (x * 73856093 ^ y * 19349663 ^ z * 83492791) & 255
				c0 *= 0.93 + float(hv) / 255.0 * 0.14
				c0.a = 1.0
				for d in 6:
					var n: Vector3i = dirs[d]
					var nx := x + n.x
					var ny := y + n.y
					var nz := z + n.z
					if ny < y0:
						continue  # sotto: resta dentro la collina
					var outside := Vector2(nx - cx, nz - cz).length() > cut
					if not outside and world.get_v(nx, ny, nz) != 0:
						continue
					if outside and y < b - 1:
						continue
					var cs: Array = VoxelWorld._f_c[d]
					var nrm: Vector3 = VoxelWorld._f_n[d]
					var o := Vector3(x - cx, y - b, z - cz)
					for t in [0, 1, 2, 0, 2, 3]:
						st.set_color(c0)
						st.set_normal(nrm)
						st.add_vertex(o + (cs[t] as Vector3))
	return st.commit()


## Le parti che fanno luce: lanterne appese sopra la tavola e fiamme delle torce.
func _lanterns_mesh() -> ArrayMesh:
	var m := UnitModels.new()
	m._begin(1.0)
	for k in 13:
		var x := -7.2 + float(k) * 1.2
		var sag := 4.4 - 0.9 * (1.0 - pow(x / 7.4, 2.0))
		var col := [Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.25), Color(0.95, 0.9, 0.5)][k % 3] as Color
		m._b(Vector3(x - 0.04, sag, -0.04), Vector3(x + 0.04, sag + 0.08, 0.04), Color(0.3, 0.25, 0.2))
		m._b(Vector3(x - 0.16, sag - 0.34, -0.16), Vector3(x + 0.16, sag, 0.16), col)
	for x: float in [-7.4, 7.4]:
		m._b(Vector3(x - 0.14, 2.6, 0.86), Vector3(x + 0.14, 3.0, 1.14), Color(1.0, 0.6, 0.15))
	# una finestra accesa per casa, di fianco alla porta
	for o: Vector3 in HOUSES_AT:
		var face := -o.normalized()
		var along_x := absf(face.x) > absf(face.z)
		var hx := 1.66 if along_x else 2.06
		var hz := 2.06 if along_x else 1.66
		var p := o + Vector3(face.x * hx, 1.3, face.z * hz) + Vector3(-face.z, 0, face.x).normalized() * 1.0
		m._b(p - Vector3(0.28, 0, 0.28), p + Vector3(0.28, 0.5, 0.28), Color(1.0, 0.72, 0.3))
	return m.st.commit()


func _flames_mesh() -> ArrayMesh:
	var m := UnitModels.new()
	m._begin(1.0)
	m._b(Vector3(-0.6, 0.2, -0.6), Vector3(0.6, 1.2, 0.6), Color(1.0, 0.45, 0.1))
	m._b(Vector3(-0.4, 1.2, -0.4), Vector3(0.4, 2.0, 0.4), Color(1.0, 0.68, 0.2))
	m._b(Vector3(-0.2, 2.0, -0.2), Vector3(0.2, 2.6, 0.2), Color(1.0, 0.88, 0.45))
	return m.st.commit()


# ---------------------------------------------------------------- notte e interfaccia

## Di notte: niente sole né nebbia, luce ambiente bassa e bluastra. Poi tutto torna com'era.
func _night(on: bool) -> void:
	if on:
		# tutte le luci e gli ambienti della scena, anche quelli del menu sullo sfondo
		_saved.suns = []
		_saved.envs = []
		for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			if not is_ancestor_of(n) and (n as DirectionalLight3D).visible:
				_saved.suns.append(n)
				(n as DirectionalLight3D).visible = false
		for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			var e: Environment = (n as WorldEnvironment).environment
			if e == null:
				continue
			_saved.envs.append([e, e.ambient_light_color, e.ambient_light_energy, e.fog_enabled, e.ambient_light_source, e.reflected_light_source])
			e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			e.ambient_light_color = Color(0.22, 0.27, 0.5)
			e.ambient_light_energy = 0.32
			e.fog_enabled = false
	else:
		for n: Node in _saved.get("suns", []):
			if is_instance_valid(n):
				(n as DirectionalLight3D).visible = true
		for row: Array in _saved.get("envs", []):
			var e: Environment = row[0]
			e.ambient_light_color = row[1]
			e.ambient_light_energy = row[2]
			e.fog_enabled = row[3]
			e.ambient_light_source = row[4]
			e.reflected_light_source = row[5]


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, get_viewport().get_visible_rect().size.y * 0.12)
		if k == 1:
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_ui.add_child(bar)
	_cap = UiStyle.label("", 28, UiStyle.GOLD, true)
	_cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cap.offset_bottom = -get_viewport().get_visible_rect().size.y * 0.035
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.add_theme_constant_override("outline_size", 8)
	_ui.add_child(_cap)
	var skip := UiStyle.label("Clic o un tasto per saltare", 14, UiStyle.OFF)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -18
	skip.offset_top = 12
	_ui.add_child(skip)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)


func caption_at(t: float) -> String:
	if t < SHOT_A:
		return "E così %s tornò a casa, portato in trionfo sullo scudo" % _who()
	if t < SHOT_B:
		return "Come in tutte le belle storie, la guerra finì a tavola"
	if t < SHOT_C:
		return "Cantarono tutti. Tranne uno"
	return "Sotto le stelle d'Italia, fino all'alba"


func _who() -> String:
	return game.hud._display_name(house) if game.hud else String(Defs.HOUSES[house].name)


## Il cartello finale: FINE, chi ha vinto e in quanto tempo; si torna al menu o si resta a guardare.
func _show_card() -> void:
	if _card != null:
		return
	_cap.text = ""
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	_card = dim
	var box := UiStyle.panel(28)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	var fine := UiStyle.label("Fine", 84, UiStyle.GOLD, true)
	fine.add_theme_font_override("font", UiStyle.display_font())
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fine)
	var who := UiStyle.label("%s, signore d'Italia" % _who(), 30, Defs.HOUSES[house].color.lerp(Color.WHITE, 0.45), true)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var mins := int(game.sim.time / 60.0) if game.sim else 0
	var stats := UiStyle.label("Tutti i %d castelli in %d minuti" % [game.castles.size(), mins], 19, UiStyle.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var menu := UiStyle.button("Torna al menu", "Chiudi la partita e torna al menu principale", func(): game.get_parent().call_deferred("back_to_menu"), 190.0, 46.0)
	menu.name = "Menu"
	row.add_child(menu)
	var stay := UiStyle.button("Resta a guardare", "Torna sulla mappa: la tua Italia, tutta tua", close, 190.0, 46.0)
	stay.name = "Resta"
	row.add_child(stay)
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.5)


func close() -> void:
	if _ended:
		return
	_ended = true
	_night(false)
	if game.hud:
		game.hud.visible = true
	if game.ctrl:
		game.ctrl.set_process(true)
		game.ctrl.set_process_unhandled_input(true)
		if game.ctrl.cam:
			game.ctrl.cam.current = true
	finished.emit()
	queue_free()


# ---------------------------------------------------------------- animazione

func skip() -> void:
	if _t < FADE_AT:
		_t = FADE_AT
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.45, 0.6)
	_show_card()


func _unhandled_input(event: InputEvent) -> void:
	if _card == null and Controller.skips_cinematic(event):
		skip()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _ended:
		return
	_t += minf(dt, 0.1)  # un intoppo di caricamento non deve saltare un'inquadratura
	_tick_procession()
	_tick_people()
	_tick_fire()
	_tick_fireworks(dt)
	if _card == null:
		_tick_camera()
		_cap.text = caption_at(_t)
		if _t >= FADE_AT and _fade.color.a < 0.01:
			create_tween().tween_property(_fade, "color:a", 0.45, 1.2)
		if _t >= END:
			_show_card()
	else:
		_cam_at(_crane_end(), Vector3(0, 12, -40))


## La prima telecamera aspetta il corteo appena fuori dal sentiero, dove passerà verso fine ripresa.
func _shot_a_cam() -> Vector3:
	var a := proc_angle(SHOT_A * 0.72)
	return Vector3(cos(a), 0, sin(a)) * (R_PROC + 4.0)


func proc_angle(t: float) -> float:
	return -1.1 + t * SPEED


func _tick_procession() -> void:
	var a := proc_angle(_t)
	var c := Vector3(cos(a), 0, sin(a)) * R_PROC
	var fwd := Vector3(-sin(a), 0, cos(a))
	var yaw := atan2(fwd.x, fwd.z)
	var side := Vector3(fwd.z, 0, -fwd.x)
	var k := 0
	for f: float in [-0.75, 0.75]:
		for s: float in [-0.7, 0.7]:
			var bob := absf(sin(_t * 11.0 + float(k) * 1.6)) * 0.06
			bearers.set_instance_transform(k, Transform3D(Basis(Vector3.UP, yaw), c + fwd * f + side * s + Vector3(0, bob, 0)))
			k += 1
	# lo scudo segue il passo dei portatori: su e giù, e un po' di rollio
	shield.position = c + Vector3(0, 2.42 + absf(sin(_t * 5.5)) * 0.07, 0)
	shield.rotation = Vector3(sin(_t * 2.7) * 0.04, yaw + sin(_t * 0.8) * 0.35, sin(_t * 5.5) * 0.04)
	# il sinistro alto col pugno al cielo, il destro saluta la folla avanti e indietro
	arm_l.rotation = Vector3(0.0, 0.0, -(2.75 + sin(_t * 2.3) * 0.18))
	arm_r.rotation = Vector3(sin(_t * 7.0) * 0.12, 0.0, 2.2 + sin(_t * 7.0) * 0.42)


## A tavola: brindano a ondate (il braccio alzato), saltellano dal ridere e si girano verso i vicini.
func _tick_people() -> void:
	for p: Array in _people:
		var mm: MultiMesh = p[0]
		var i: int = p[1]
		var t2 := _t + float(p[4])
		var cheer := 1.0 if fposmod(t2, 4.2) < 1.7 else 0.0
		var hop := cheer * absf(sin(t2 * 7.5)) * 0.14
		var turn := sin(t2 * 0.7) * 0.35
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(p[3]) + turn) * Basis(Vector3.RIGHT, -0.08 * cheer), (p[2] as Vector3) + Vector3(0, hop, 0)))
		var cd := mm.get_instance_custom_data(i)
		cd.b = cheer
		mm.set_instance_custom_data(i, cd)


func _tick_fire() -> void:
	flames.scale = Vector3(1.0 + sin(_t * 13.0) * 0.06, 1.0 + sin(_t * 9.0) * 0.12 + sin(_t * 23.0) * 0.05, 1.0 + cos(_t * 11.0) * 0.06)
	fire_light.light_energy = 4.6 + sin(_t * 17.0) * 0.5 + sin(_t * 7.0) * 0.4
	var ph := fposmod(_t, 1.8) / 1.8
	notes.position = TREE + Vector3(0.75 + ph * 0.4, 2.05 + ph * 0.6, 1.0)
	notes.modulate.a = 1.0 - ph * ph
	notes.outline_modulate.a = notes.modulate.a


## Razzi dal cielo sopra la festa: dalla seconda inquadratura in poi, uno ogni tanto, sempre più fitti.
func _tick_fireworks(_dt: float) -> void:
	if _t > SHOT_A and _t >= _next_burst and _bursts.size() < 6:
		var cols := [Color(1.0, 0.82, 0.3), Defs.HOUSES[house].color.lerp(Color.WHITE, 0.2), Color(0.95, 0.35, 0.3), Color(0.5, 0.9, 1.0), Color(0.9, 0.5, 1.0)]
		var c := HILL + Vector3(randf_range(-34, 34), randf_range(38, 58), randf_range(-10, 30))
		_bursts.append([c, _t, cols[randi() % cols.size()], randi()])
		_next_burst = _t + (1.1 if _t > SHOT_C else 1.8) * randf_range(0.7, 1.2)
		if game.fx and game.fx.sfx:
			game.fx.sfx.play("boom", global_position + c, -14.0, 0.3)
	_bursts = _bursts.filter(func(b: Array) -> bool: return _t - float(b[1]) < 2.2)
	for slot in 6:
		for i in 28:
			var idx := slot * 28 + i
			if slot >= _bursts.size():
				sparks.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
				continue
			var b: Array = _bursts[slot]
			var age := _t - float(b[1])
			var seed_: int = b[3]
			var u := fposmod(sin(float(i) * 12.989 + float(seed_)) * 4375.85, 1.0)
			var w := fposmod(sin(float(i) * 78.233 + float(seed_) * 0.37) * 4375.85, 1.0)
			var th := u * TAU
			var ph := acos(1.0 - 2.0 * w)
			var d := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var r := 14.0 * (1.0 - exp(-age * 2.4))
			var p: Vector3 = b[0] + d * r + Vector3(0, -age * age * 1.2, 0)
			var sz := clampf(1.0 - age / 2.2, 0.0, 1.0)
			sparks.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ONE * sz), p))
			sparks.set_instance_custom_data(idx, b[2])


func _crane_end() -> Vector3:
	return Vector3(2.0, 20.0, 40.0)


func _tick_camera() -> void:
	var t := _t
	var pos: Vector3
	var look: Vector3
	if t < SHOT_A:
		# il corteo arriva verso di noi sul sentiero, il re saluta
		var k := t / SHOT_A
		pos = _shot_a_cam() + Vector3(0, lerpf(2.4, 3.2, k), 0)
		var sa := proc_angle(t)
		look = Vector3(cos(sa), 0, sin(sa)) * R_PROC + Vector3(0, 2.8, 0)
	elif t < SHOT_B:
		# carrellata lungo la tavola, il falò dietro
		var k := smoothstep(0.0, 1.0, (t - SHOT_A) / (SHOT_B - SHOT_A))
		pos = Vector3(lerpf(-6.0, 5.0, k), 3.0, 6.2)
		look = Vector3(lerpf(-4.0, 3.0, k), 1.5, -0.5)
	elif t < SHOT_C:
		# il menestrello legato all'albero, che prova lo stesso a cantare
		var k := smoothstep(0.0, 1.0, (t - SHOT_B) / (SHOT_C - SHOT_B))
		# da sinistra: dietro di lui si vede la festa a cui non è invitato a cantare
		pos = TREE + Vector3(lerpf(-2.6, -1.6, k), lerpf(2.1, 1.9, k), lerpf(4.6, 3.2, k))
		look = TREE + Vector3(0.3, 1.6, 0.7)
	else:
		# la gru sale: la festa, il cielo stellato, i fuochi
		var k := smoothstep(0.0, 1.0, (t - SHOT_C) / (FADE_AT - SHOT_C))
		pos = Vector3(0.0, 3.0, 13.0).lerp(_crane_end(), k)
		look = Vector3(0, 1.2, 0).lerp(Vector3(0, 12, -40), k)
	_cam_at(pos, look)


func _cam_at(pos: Vector3, look: Vector3) -> void:
	cam.look_at_from_position(to_global(pos), to_global(look), Vector3.UP)
