class_name UpdateNotice
extends PanelContainer
## Cartiglio in basso a destra nel menu: «nuova versione pronta, riavvia» oppure «serve la versione
## completa». Compare solo a menu svelato (non sopra la pergamena di caricamento).

## «Dopo»: non riproporlo fino al prossimo avvio
signal dismissed

var menu: Control
var updater: Updater
var build := 0
var note := ""
var page := ""  # se c'è, serve la versione completa: il pulsante apre la pagina del Release


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 14))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -24
	offset_bottom = -24
	custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.label("Nuova versione (n. %d)" % build, 18, UiStyle.GOLD, true))
	var txt := note if page == "" else "Questa volta va scaricato di nuovo tutto il gioco."
	if txt != "":
		var l := UiStyle.label(txt, 15, UiStyle.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(312, 0)
		v.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	if page == "":
		h.add_child(UiStyle.button("Riavvia ora", "Chiude il gioco e lo riapre aggiornato", func(): updater.restart(), 150))
	else:
		h.add_child(UiStyle.button("Scarica", "Apre la pagina della nuova versione", func(): OS.shell_open(page), 150))
	h.add_child(UiStyle.button("Dopo", "Si aggiorna da solo al prossimo avvio" if page == "" else "Te lo ricordo al prossimo avvio", func():
		dismissed.emit()
		queue_free(), 110))
	visible = false


func _process(_dt: float) -> void:
	visible = menu == null or bool(menu.get("revealed"))
