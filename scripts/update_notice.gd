class_name UpdateNotice
extends PanelContainer
## Riquadro in basso a destra nel menu: il numero di versione e il pulsante per aggiornare.
## «Cerca aggiornamenti» controlla il Release, scarica il pacchetto nuovo e riavvia da solo il gioco.
## Se il controllo d'avvio ha già trovato e scaricato una versione, propone «Aggiorna ora».
## Compare solo a menu svelato (non sopra la pergamena di caricamento). Lo stato sta nell'Updater:
## tornando al menu da una partita il riquadro nuovo lo ritrova.

var menu: Control
var updater: Updater

var title: Label
var info: Label
var btn: Button
var _shown := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 12))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_bottom = -20
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	title = UiStyle.label("", 16, UiStyle.INK, true)
	v.add_child(title)
	info = UiStyle.label("", 15, UiStyle.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(250, 0)
	v.add_child(info)
	btn = UiStyle.button("", "", _press, 250, 36)
	btn.name = "Aggiorna"
	v.add_child(btn)
	visible = false
	_refresh()


func _press() -> void:
	match updater.status:
		"ready":
			updater.restart()
		"full":
			OS.shell_open(str(updater.info.page))
		_:
			updater.check(true)


func _process(_dt: float) -> void:
	visible = menu == null or bool(menu.get("revealed"))
	_refresh()


func _refresh() -> void:
	var st := updater.status
	var key := "%s %d" % [st, int(updater.progress() * 100)]
	if key == _shown:
		return
	_shown = key
	var nb := int(updater.info.get("build", 0))
	title.text = "Versione %d" % Version.build()
	title.add_theme_color_override("font_color", UiStyle.GOLD if st in ["ready", "full"] else UiStyle.INK)
	btn.disabled = st in ["checking", "downloading", "restarting"]
	btn.text = "Cerca aggiornamenti"
	btn.tooltip_text = "Controlla se c'è una versione nuova: la scarica e riavvia il gioco"
	info.text = ""
	match st:
		"checking":
			info.text = "Cerco una versione nuova…"
		"uptodate":
			info.text = "Hai l'ultima versione."
		"failed":
			info.text = "Non riesco a collegarmi: riprova più tardi."
		"downloading":
			info.text = "Scarico la versione %d… %d%%" % [nb, int(updater.progress() * 100)]
		"restarting":
			info.text = "Riavvio il gioco…"
		"ready":
			title.text = "Versione %d pronta" % nb
			info.text = str(updater.info.get("note", ""))
			btn.text = "Aggiorna ora"
			btn.tooltip_text = "Chiude il gioco e lo riapre aggiornato"
		"full":
			title.text = "Versione %d disponibile" % nb
			info.text = "Questa volta va scaricato di nuovo tutto il gioco."
			btn.text = "Scarica"
			btn.tooltip_text = "Apre la pagina della nuova versione"
	info.visible = info.text != ""
