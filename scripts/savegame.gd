class_name SaveGame
extends RefCounted
## Salvataggio delle partite contro l'IA in user://partita.sav. Il mondo non si salva voxel per voxel:
## si rigenera dallo stesso seme e si riapplicano tutte le modifiche (crolli, crateri, botteghe).

## var e non const: i test salvano altrove, senza toccare la partita del giocatore.
static var PATH := "user://partita.sav"
## La partita in rete salvata da chi ospita: a parte, per non toccare quella contro l'IA.
static var NET_PATH := "user://partita_rete.sav"
const VERSION := 4  # 4: quattordici castelli (Ferrara al posto di Bologna, Oristano; signorie minori del 1350) e bandiere di raduno; i vecchi salvataggi non combaciano


static func exists(net := false) -> bool:
	return FileAccess.file_exists(NET_PATH if net else PATH)


## Riassunto per il menu: casata e minuti di gioco (vuoto se non c'è o non si legge).
static func summary(net := false) -> Dictionary:
	var d := _read(net)
	if d.is_empty():
		return {}
	return {"house": int(d.house), "minutes": int(float(d.sim.time) / 60.0), "date": String(d.get("date", "")), "players": d.get("players", {})}


## In rete salva solo chi ospita: insieme alla partita, chi comandava quale casata (per nome),
## così chi rientra con lo stesso nome ritrova la sua.
static func save(game: Game) -> bool:
	if game.sim == null or (game.net_multiplayer and not game.is_server):
		return false
	var players := {}
	if game.net_multiplayer:
		for t in Defs.HOUSE_COUNT:
			var h: Dictionary = game.sim.houses[t]
			if not bool(h.ai) and String(h.pname) != "":
				players[String(h.pname)] = t
	var d := {
		"players": players,
		"version": VERSION, "house": game.my_house, "name": game.my_name,
		"date": Time.get_datetime_string_from_system(false, true),
		"edits": game.edit_log.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD),
		"edits_size": game.edit_log.size() * 8,
		"sim": game.sim.save_state(),
	}
	var f := FileAccess.open(NET_PATH if game.net_multiplayer else PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	return true


static func load_data(net := false) -> Dictionary:
	return _read(net)


static func _read(net := false) -> Dictionary:
	if not exists(net):
		return {}
	var f := FileAccess.open(NET_PATH if net else PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	if typeof(d) != TYPE_DICTIONARY or int((d as Dictionary).get("version", 0)) != VERSION:
		return {}
	return d
