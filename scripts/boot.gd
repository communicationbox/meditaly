extends Node
## Prima scena del gioco: se c'è un aggiornamento scaricato (vedi Updater) lo carica sopra il pacchetto
## dell'app, poi apre il gioco vero (main.tscn). Non deve nominare nessuna classe del gioco né
## caricare altri script: quello che si carica prima del pacchetto resterebbe nella versione vecchia.

const DIR := "user://aggiornamenti"


func _ready() -> void:
	if OS.has_feature("template"):
		_apply_update()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _apply_update() -> void:
	var mine := FileAccess.get_file_as_string("res://version.txt").strip_edges().to_int()
	var best := 0
	var d := DirAccess.open(DIR)
	if d == null:
		return
	var re := RegEx.create_from_string("^meditaly-b(\\d+)\\.pck$")
	for f in d.get_files():
		var m := re.search(f)
		if m and m.get_string(1).to_int() > maxi(best, mine):
			best = m.get_string(1).to_int()
	if best == 0:
		return
	var p := "%s/meditaly-b%d.pck" % [DIR, best]
	if ProjectSettings.load_resource_pack(p, true):
		print("Aggiornamento caricato: %s" % p)
	else:
		DirAccess.remove_absolute(p)  # guasto: si torna alla versione dell'app, l'Updater lo riscarica
		push_warning("Aggiornamento illeggibile, rimosso: %s" % p)

