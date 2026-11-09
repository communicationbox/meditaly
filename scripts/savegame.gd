class_name SaveGame
extends RefCounted
## Salvataggio delle partite contro l'IA in user://partita.sav. Il mondo non si salva voxel per voxel:
## si rigenera dallo stesso seme e si riapplicano tutte le modifiche (crolli, crateri, botteghe).

## var e non const: i test salvano altrove, senza toccare la partita del giocatore.
static var PATH := "user://partita.sav"
const VERSION := 2  # 2: nona casata e tredicesimo castello, i vecchi salvataggi non combaciano


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## Riassunto per il menu: casata e minuti di gioco (vuoto se non c'è o non si legge).
static func summary() -> Dictionary:
	var d := _read()
	if d.is_empty():
		return {}
	return {"house": int(d.house), "minutes": int(float(d.sim.time) / 60.0), "date": String(d.get("date", ""))}


static func save(game: Game) -> bool:
	if game.sim == null or game.net_multiplayer:
		return false
	var d := {
		"version": VERSION, "house": game.my_house, "name": game.my_name,
		"date": Time.get_datetime_string_from_system(false, true),
		"edits": game.edit_log.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD),
		"edits_size": game.edit_log.size() * 8,
		"sim": game.sim.save_state(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	return true


static func load_data() -> Dictionary:
	return _read()


static func _read() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	if typeof(d) != TYPE_DICTIONARY or int((d as Dictionary).get("version", 0)) != VERSION:
		return {}
	return d
