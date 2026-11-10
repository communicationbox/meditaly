class_name KingStage
extends Node3D
## Set della cinematica del re: la stanza del mastio ricostruita fuori dalla mappa, più larga
## e ben illuminata. Il mastio vero è largo sette voxel: lì dentro la telecamera non ci sta.

const POS := Vector3(-260.0, 40.0, -260.0)

var room: MeshInstance3D
var room_mat: StandardMaterial3D
var king_mm: MultiMesh
var torch: OmniLight3D
var prop: MeshInstance3D
var king_mi: MultiMeshInstance3D
var hic: Label3D
const ARMOUR := 7  # l'armatura starnutisce qui, nella sala
const SNEEZE_AT := 1.75
const CROWN := 8  # la corona di cartone si affloscia sul cuscino, davanti a tutti
const TEAR_AT := 1.5
const CROWN_POS := Vector3(0.0, 1.46, 0.86)
var fig: MeshInstance3D  # l'armatura col re dentro, in mezzo alla fila
var pile: MeshInstance3D
var boxer: MeshInstance3D
var _sneezed := false
var _variant := 0
var _t := 0.0


func setup(unit_material: Material) -> void:
	position = POS
	room_mat = StandardMaterial3D.new()
	room_mat.vertex_color_use_as_albedo = true
	room_mat.vertex_color_is_srgb = true
	room_mat.roughness = 0.95
	room = MeshInstance3D.new()
	room.material_override = room_mat
	add_child(room)
	king_mm = MultiMesh.new()
	king_mm.transform_format = MultiMesh.TRANSFORM_3D
	king_mm.use_custom_data = true
	king_mm.mesh = UnitModels.new().re()
	king_mm.instance_count = 1
	var kmi := MultiMeshInstance3D.new()
	kmi.multimesh = king_mm
	kmi.material_override = unit_material
	add_child(kmi)
	king_mi = kmi
	prop = MeshInstance3D.new()
	prop.material_override = room_mat
	add_child(prop)
	var models := UnitModels.new()
	for part: Array in [["fig", models.re_armatura()], ["pile", UnitModels.new().re_crollo()], ["boxer", UnitModels.new().re_boxer()]]:
		var n := MeshInstance3D.new()
		n.mesh = part[1]
		n.material_override = room_mat
		n.scale = Vector3.ONE * 0.62
		n.visible = false
		add_child(n)
		set(String(part[0]), n)
	hic = Label3D.new()
	hic.text = "Hic!"
	hic.font = UiStyle.comic_font()
	hic.font_size = 96
	hic.outline_size = 22
	hic.pixel_size = 0.006
	hic.modulate = Color(0.72, 0.16, 0.5)
	hic.outline_modulate = Color(1, 0.97, 0.88)
	hic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hic.visible = false
	add_child(hic)
	king_mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.72, 0.4)
	torch.light_energy = 2.2
	torch.omni_range = 9.0
	torch.position = Vector3(-3.6, 3.0, -1.0)
	add_child(torch)
	visible = false


## Mostra il set con lo stendardo e la veste del re del colore della casata che lo perde.
func show_for(house: int, variant := 0) -> void:
	var col: Color = Defs.HOUSES[clampi(house, 0, Defs.HOUSES.size() - 1)].color
	room.mesh = _build_room(col, variant == 0)
	_variant = variant
	prop.rotation = Vector3.ZERO
	hic.visible = variant == 1
	hic.text = "Hic!"
	hic.outline_modulate.a = 1.0
	_t = 0.0
	_sneezed = false
	fig.visible = variant == ARMOUR or variant == CROWN
	boxer.rotation = Vector3.ZERO
	if variant == CROWN:
		fig.mesh = UnitModels.new().re_corona_meta(true, true)
		boxer.mesh = UnitModels.new().re_corona_meta(true, false)
		boxer.visible = true
		for half: MeshInstance3D in [fig, boxer]:
			half.position = CROWN_POS
			half.rotation = Vector3.ZERO
			half.scale = Vector3.ONE * 0.95
	else:
		fig.mesh = UnitModels.new().re_armatura()
		boxer.mesh = UnitModels.new().re_boxer()
		for part: MeshInstance3D in [fig, boxer]:
			part.position = Vector3.ZERO
			part.scale = Vector3.ONE * 0.62
	boxer.visible = variant == CROWN
	pile.visible = false
	if variant == ARMOUR:
		fig.rotation = Vector3.ZERO
	king_mi.visible = variant == 0
	prop.visible = variant != 0
	if variant != 0:
		prop.mesh = UnitModels.new().re_scena(col, variant, variant != ARMOUR)  # con la corona: cuscino e braccia tese
		prop.scale = Vector3.ONE * (1.0 if variant == 2 else (0.72 if variant == 1 else (0.62 if variant == 7 else 0.8)))  # le figure alte devono stare in quadro
	king_mm.set_instance_custom_data(0, Color(0.0, 0.0, 1.0, float(house)))
	visible = true


## Il re nella botte ondeggia e singhiozza.
func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if _variant == ARMOUR:
		_armour_tick()
		return
	if _variant == CROWN:
		_crown_tick()
		return
	if _variant != 1:
		return
	prop.rotation.z = sin(_t * 2.4) * 0.07
	prop.rotation.x = sin(_t * 1.5) * 0.035
	hic.modulate = Color(0.72, 0.16, 0.5)
	var phase := fposmod(_t, 1.3) / 1.3
	hic.position = Vector3(-0.95, 2.0 + phase * 0.6, 0.5)
	hic.modulate.a = 1.0 - phase * phase


## La corona d'oro si strappa in due: era cartone, e le due metà cadono ai lati del cuscino.
func _crown_tick() -> void:
	if _t < TEAR_AT:
		return
	if not _sneezed:
		_sneezed = true
		fig.mesh = UnitModels.new().re_corona_meta(false, true)
		boxer.mesh = UnitModels.new().re_corona_meta(false, false)
		hic.text = "Strap!"
		hic.visible = true
		hic.position = Vector3(0.0, 2.5, 0.8)
		hic.modulate = Color(0.78, 0.1, 0.08)
		var g: Node = get_parent()
		if g.fx and g.fx.sfx:
			g.fx.sfx.play("crash", global_position, -4.0, 0.2)
	var k := clampf((_t - TEAR_AT) / 0.75, 0.0, 1.0)
	var spread := smoothstep(0.0, 0.5, k) * 0.34
	var drop := k * k * (CROWN_POS.y - 0.42)  # si ferma a terra, sul fianco, senza sprofondare
	fig.position = CROWN_POS + Vector3(-spread - k * 0.5, -drop, 0)
	boxer.position = CROWN_POS + Vector3(spread + k * 0.5, -drop, 0)
	fig.rotation.z = k * 1.5
	boxer.rotation.z = -k * 1.5
	var fade := clampf(1.0 - (_t - TEAR_AT - 0.9) / 0.4, 0.0, 1.0)
	hic.modulate.a = fade
	hic.outline_modulate.a = fade


## Trema, starnutisce, l'armatura crolla e dentro c'era il re in boxer.
func _armour_tick() -> void:
	if _t < SNEEZE_AT:
		var shake := smoothstep(0.7, SNEEZE_AT, _t)
		fig.rotation.z = sin(_t * 46.0) * 0.07 * shake
		return
	if not _sneezed:
		_sneezed = true
		fig.visible = false
		pile.visible = true
		boxer.visible = true
		hic.text = "Etciù!"
		hic.visible = true
		hic.position = Vector3(-0.2, 2.25, 0.5)
		hic.modulate = Color(0.16, 0.42, 0.7)
		var g: Node = get_parent()
		if g.fx and g.fx.sfx:
			g.fx.sfx.play("crash", global_position, 2.0, 0.2)
	var fade := clampf(1.0 - (_t - SNEEZE_AT - 0.8) / 0.5, 0.0, 1.0)  # ben leggibile, poi svanisce
	hic.modulate.a = fade
	hic.outline_modulate.a = fade
	boxer.rotation.z = sin(_t * 30.0) * 0.03


func hide_stage() -> void:
	visible = false


## Stanza voxel aperta sul davanti: pavimento a scacchi, muri di pietra, finestra, stendardo,
## torcia e tappeto. Il re siede al centro, rivolto verso +Z.
func _build_room(banner: Color, gazzette: bool) -> ArrayMesh:
	var m := UnitModels.new()
	m._begin(1.0)
	var s1 := Color(0.56, 0.54, 0.5)
	var s2 := Color(0.47, 0.45, 0.42)
	for z in range(-4, 4):
		for x in range(-5, 5):
			m._b(Vector3(x, -0.3, z), Vector3(x + 1, 0.0, z + 1), s1 if (x + z) % 2 == 0 else s2)
	# muro di fondo con finestra ad arco e muri laterali, a blocchi alternati
	for y in range(0, 5):
		for x in range(-5, 5):
			var win := y >= 2 and y <= 3 and (x == -1 or x == 0)
			if not win:
				m._b(Vector3(x, y, -4.0), Vector3(x + 1, y + 1, -3.4), s1 if (x + y) % 2 == 0 else s2)
		for z in range(-4, 2):
			for sx: int in [-5, 4]:
				m._b(Vector3(sx, y, z), Vector3(sx + 1, y + 1, z + 1), s2 if (z + y) % 2 == 0 else s1)
	# stendardo della casata sul fondo, a sinistra della finestra
	m._b(Vector3(-3.3, 1.2, -3.42), Vector3(-1.9, 3.8, -3.32), banner)
	m._b(Vector3(-3.4, 3.8, -3.44), Vector3(-1.8, 3.95, -3.3), Color(0.47, 0.31, 0.16))
	m._b(Vector3(-2.8, 2.2, -3.33), Vector3(-2.4, 2.8, -3.3), Color(0.95, 0.76, 0.22))
	# torcia sul muro di sinistra
	m._b(Vector3(-4.0, 2.2, -1.1), Vector3(-3.8, 2.9, -0.9), Color(0.47, 0.31, 0.16))
	m._b(Vector3(-4.05, 2.9, -1.15), Vector3(-3.75, 3.2, -0.85), Color(1.0, 0.6, 0.15))
	# tappeto rosso col bordo dorato davanti al trono
	m._b(Vector3(-1.2, 0.0, 0.6), Vector3(1.2, 0.04, 2.6), Color(0.95, 0.76, 0.22))
	m._b(Vector3(-1.05, 0.0, 0.75), Vector3(1.05, 0.06, 2.45), Color(0.62, 0.08, 0.1))
	# pila di Gazzette accanto al gabinetto
	if gazzette:
		for k in 4:
			m._b(Vector3(-1.3, k * 0.09, -0.2), Vector3(-0.85, k * 0.09 + 0.08, 0.3), Color(0.93, 0.9, 0.8) * (0.9 + 0.03 * k))
	return m.st.commit()
