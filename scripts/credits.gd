class_name Credits
extends Control
## Schermata «Crediti» del menu: chi ha fatto la musica e i suoni. Per i brani CC-BY citare l'autore
## è obbligatorio (licenza), per i CC0 è solo cortesia. Elenco completo in assets/*/CREDITS.md.

const LINES := [
	["Musica", ""],
	["«Minstrel Guild», «Thatched Villagers», «Der Kleber Sting»", "Kevin MacLeod (incompetech.com) · Licensed under Creative Commons: By Attribution 4.0 · creativecommons.org/licenses/by/4.0"],
	["«The Medieval Banquet»", "Shane Ivers · silvermansound.com · Creative Commons Attribution 4.0 · creativecommons.org/licenses/by/4.0"],
	["«Enchanted Festival»", "Matthew Pablo · matthewpablo.com · Creative Commons Attribution 3.0 · creativecommons.org/licenses/by/3.0"],
	["«The Old Tower Inn», «Rejoicing», «Victory Theme»", "RandomMind · opengameart.org · CC0"],
	["Tuba triste", "Trex0n · opengameart.org · CC0"],
	["Suoni", ""],
	["Esplosioni, crolli, colpi, muggiti, voci, campane", "Kenney (kenney.nl) e autori di OpenGameArt · CC0 · elenco in assets/sfx/CREDITS.md"],
]

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.015, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := PanelContainer.new()
	var sb := UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 0)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(760, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UiStyle.label("Crediti", 30, UiStyle.GOLD, true))
	for row: Array in LINES:
		if String(row[1]) == "":
			v.add_child(UiStyle.label(String(row[0]), 20, UiStyle.GOLD_DIM, true))
			continue
		v.add_child(UiStyle.label(String(row[0]), 16, UiStyle.INK, true))
		var who := UiStyle.label(String(row[1]), 14, UiStyle.MUTED)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(who)
	var back := UiStyle.button("Chiudi", "Esc", func() -> void: closed.emit(), 160.0, 44.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(back)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and k.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		closed.emit()
