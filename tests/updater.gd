extends SceneTree
## Aggiornamenti: un server HTTP locale fa la parte del Release di GitHub.
##   godot --headless --path . -s tests/updater.gd
## Scarica il pacchetto nuovo e ne controlla lo sha256, ignora versioni vecchie e file guasti,
## chiede la versione completa se cambia il motore, e il menu mostra (e richiude) l'avviso.

const PORT := 27891

var fails := 0
var srv_dir := ""
var srv_pid := -1

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()


func _manifest(build: int, engine: String, sha: String) -> void:
	var m := {"build": build, "engine": engine, "note": "Prova",
		"pck": {OS.get_name(): {"url": "http://127.0.0.1:%d/meditaly.pck" % PORT, "sha256": sha}}}
	var f := FileAccess.open(srv_dir + "/aggiornamento.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()


## Esegue un controllo e dice quali segnali sono arrivati.
func _check_once() -> Dictionary:
	var got := {}
	var u := Updater.new()
	u.manifest_url = "http://127.0.0.1:%d/aggiornamento.json" % PORT
	u.update_ready.connect(func(b: int, _n: String): got.ready = b)
	u.full_needed.connect(func(b: int, _p: String): got.full = b)
	root.add_child(u)
	await u.check()
	u.queue_free()
	return got


func _wipe() -> void:
	var d := DirAccess.open(Updater.DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


func _run() -> void:
	srv_dir = OS.get_cache_dir().path_join("meditaly_updater_test")
	DirAccess.make_dir_recursive_absolute(srv_dir)
	var pck := FileAccess.open(srv_dir + "/meditaly.pck", FileAccess.WRITE)
	pck.store_buffer("finto pacchetto".repeat(5000).to_utf8_buffer())
	pck.close()
	var sha := FileAccess.get_sha256(srv_dir + "/meditaly.pck")
	srv_pid = OS.create_process("python3", ["-m", "http.server", str(PORT), "--bind", "127.0.0.1", "--directory", srv_dir])
	await create_timer(1.5).timeout
	_wipe()
	var next := Version.build() + 1

	check("dall'editor non si aggiorna", not Updater.enabled())
	check("versione letta da version.txt", Version.build() > 0)

	_manifest(Version.build(), Updater.engine_version(), sha)
	var g := await _check_once()
	check("stessa versione: nessun avviso", g.is_empty())

	_manifest(next, Updater.engine_version(), "0".repeat(64))
	g = await _check_once()
	check("sha256 sbagliato: nessun avviso", g.is_empty())
	check("…e niente file a metà", not FileAccess.file_exists(Updater.pck_path(next)) and not FileAccess.file_exists(Updater.pck_path(next) + ".part"))

	_manifest(next, "3.0.0", sha)
	g = await _check_once()
	check("motore diverso: serve la versione completa", g.get("full", 0) == next and not g.has("ready"))

	_manifest(next, Updater.engine_version(), sha)
	g = await _check_once()
	check("versione nuova: pronta", g.get("ready", 0) == next)
	check("pacchetto scaricato e integro", FileAccess.get_sha256(Updater.pck_path(next)) == sha)
	check("all'avvio si sceglie il pacchetto nuovo", Updater.newest_downloaded() == Updater.pck_path(next))
	g = await _check_once()
	check("già scaricato: avviso subito", g.get("ready", 0) == next)

	# i pacchetti più vecchi di questa versione si cancellano
	var old := FileAccess.open(Updater.pck_path(Version.build() - 1), FileAccess.WRITE)
	old.store_string("vecchio")
	old.close()
	Updater.newest_downloaded()
	check("pacchetto vecchio cancellato", not FileAccess.file_exists(Updater.pck_path(Version.build() - 1)))

	# l'avviso nel menu, e «Dopo» lo chiude per la sessione
	root.size = Vector2i(1600, 900)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	main._set_notice({"build": next, "note": "Prova"})
	await process_frame
	var notes: Array = main.menu.find_children("", "UpdateNotice", true, false)
	check("il menu mostra l'avviso", notes.size() == 1)
	if notes.size() == 1:
		notes[0].dismissed.emit()
		notes[0].queue_free()
	await process_frame
	main.back_to_menu()
	await process_frame
	check("dopo «Dopo» non torna col menu nuovo", main.menu.find_children("", "UpdateNotice", true, false).is_empty())
	main._set_notice({"build": next, "page": "https://example.org"})
	await process_frame
	check("versione completa: avviso con «Scarica»", main.menu.find_children("", "UpdateNotice", true, false).size() == 1)

	_wipe()
	OS.kill(srv_pid)
	print("FAIL: %d" % fails if fails else "TUTTO OK")
	quit(1 if fails else 0)
