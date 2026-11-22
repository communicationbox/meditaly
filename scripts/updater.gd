class_name Updater
extends Node
## Aggiornamenti senza rifare la build: il gioco scarica dall'ultimo Release su GitHub solo il pacchetto
## dei contenuti (.pck: script, scene, suoni) e lo mette in user://aggiornamenti; al riavvio la scena
## di avvio (boot.gd) lo carica sopra quello dell'app prima di aprire il gioco. Il motore resta quello
## installato: se un Release vuole un Godot diverso, il gioco invita a scaricare la versione completa
## invece di caricare un pacchetto incompatibile.
##
## Perché riavviare e non caricarlo a gioco aperto: gli script già caricati resterebbero quelli vecchi.
## Cambi a project.godot o a export_presets.cfg invece non passano col pacchetto: lì serve --completa.
##
## Il Release lo prepara tools/pubblica_aggiornamento.sh; il suo `aggiornamento.json` è:
##   {"build": 4, "engine": "4.7.1", "note": "…",
##    "pck": {"macOS": {"url": "…", "sha256": "…"}, "Windows": {"url": "…", "sha256": "…"}}}

const DIR := "user://aggiornamenti"
const MANIFEST := "aggiornamento.json"

## pronto un pacchetto nuovo: basta riavviare
signal update_ready(build: int, note: String)
## il Release nuovo chiede un motore diverso: serve la versione completa
signal full_needed(build: int, page: String)

var manifest_url := "https://github.com/%s/releases/latest/download/%s" % [Version.REPO, MANIFEST]
var _http: HTTPRequest


## Solo nelle versioni esportate (non dall'editor né nei test).
static func enabled() -> bool:
	return OS.has_feature("template")


static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]


static func pck_path(build: int) -> String:
	return "%s/meditaly-b%d.pck" % [DIR, build]


## Il pacchetto scaricato più recente, se è più nuovo di questa versione; "" altrimenti.
## Cancella quelli più vecchi (quello che sta girando resta).
static func newest_downloaded() -> String:
	var best := 0
	var d := DirAccess.open(DIR)
	if d == null:
		return ""
	for f in d.get_files():
		var m := RegEx.create_from_string("^meditaly-b(\\d+)\\.pck$").search(f)
		if m == null:
			if f.ends_with(".part"):
				d.remove(f)
			continue
		var b := m.get_string(1).to_int()
		if b < Version.build():
			d.remove(f)
		elif b > best:
			best = b
	return pck_path(best) if best > Version.build() else ""


## Riavvia subito il gioco: la nuova istanza parte con il pacchetto scaricato.
func restart() -> void:
	if OS.create_instance(PackedStringArray()) > 0:
		get_tree().quit()


func _ready() -> void:
	if enabled():
		newest_downloaded()  # fa pulizia dei pacchetti superati
		check()


func check() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	if _http.request(manifest_url) != OK:
		_done()
		return
	var r: Array = await _http.request_completed
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		_done()  # niente rete o niente Release: si gioca con quello che c'è
		return
	var m: Variant = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if m is Dictionary:
		await _handle(m)
	_done()


func _handle(m: Dictionary) -> void:
	var build := int(m.get("build", 0))
	if build <= Version.build():
		return
	var page := "https://github.com/%s/releases/latest" % Version.REPO
	if str(m.get("engine", "")) != engine_version():
		full_needed.emit(build, page)
		return
	var entry: Variant = (m.get("pck", {}) as Dictionary).get(OS.get_name())
	if not entry is Dictionary:
		full_needed.emit(build, page)
		return
	var sha := str(entry.get("sha256", "")).to_lower()
	var dest := pck_path(build)
	if not (FileAccess.file_exists(dest) and FileAccess.get_sha256(dest) == sha):
		DirAccess.make_dir_recursive_absolute(DIR)
		var part := dest + ".part"
		_http.download_file = part
		_http.timeout = 600.0
		if _http.request(str(entry.get("url", ""))) != OK:
			return
		var r: Array = await _http.request_completed
		_http.download_file = ""
		if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200 or FileAccess.get_sha256(part) != sha:
			DirAccess.remove_absolute(part)  # scaricato a metà o diverso dal Release: si riprova al prossimo avvio
			return
		DirAccess.rename_absolute(part, dest)
	update_ready.emit(build, str(m.get("note", "")))


func _done() -> void:
	if is_instance_valid(_http):
		_http.queue_free()
