class_name Mission
extends CanvasLayer
## Una missione della storia: prepara la partita, apre e chiude con la Gazzetta, tiene d'occhio
## l'obiettivo e salva i progressi. I dati sono in Campaign.

var game: Game
var sim: Sim
var n := 1  # numero della missione, da 1
var m: Dictionary
var hero := Campaign.HERO_HOUSE
var running := false
var ended := false
var start_time := 0.0
var waves_sent := 0
var next_wave := 0.0
var wave_units: Array = []
var hints: Tutorial
var _check_t := 0.0
var box: PanelContainer
var goal_lbl: Label
var news_lbl: Label


func setup(g: Game, num: int) -> void:
	game = g
	sim = g.sim
	n = clampi(num, 1, Campaign.MISSIONS.size())
	m = Campaign.MISSIONS[n - 1]
	layer = 4
	var st: Dictionary = m.setup
	sim.story_setup(hero, st)
	sim.set_story_locks(n)
	sim.paused = true
	# la partita resta ferma sotto il giornale: interfaccia e soldati si aggiornano subito lo stesso
	sim._send_snapshot()
	sim._send_snapshot()  # due volte: anche la posizione «precedente» è quella nuova
	game.broadcast_state(sim.state_array())
	var home: Dictionary = g.castles[Campaign.HOME_CASTLE]
	g.ctrl.home_castle = Campaign.HOME_CASTLE
	g.ctrl.selected_castle = Campaign.HOME_CASTLE
	g.ctrl.focus = home.center
	g.ctrl.target_dist = 85.0
	var atk: Dictionary = st.get("attack", {})
	next_wave = float(atk.get("at", 1e9))
	_build_box()
	_intro.call_deferred()


func _intro() -> void:
	var p: Dictionary = m.intro
	game.hud.newspaper(0, p.title, p.sub, PackedInt32Array(), {"side": p.side, "mini": "conte", "buttons": [["Si comincia", _start]]})


func _start() -> void:
	game.hud.close_paper()
	sim.paused = false
	running = true
	start_time = sim.time
	game.hud.flash_home(Campaign.HOME_CASTLE)
	if m.setup.get("hints", false):
		hints = Tutorial.new()
		hints.story = true
		hints.story_target = int(m.goal.castles[0])
		game.add_child(hints)
		hints.setup(game)


func _build_box() -> void:
	box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 8))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 86
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	box.add_child(v)
	var t := UiStyle.label("Missione %d · %s" % [n, m.title], 15, UiStyle.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	goal_lbl = UiStyle.label("", 15, UiStyle.INK)
	goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(goal_lbl)
	news_lbl = UiStyle.label(_news_text(), 13, UiStyle.MUTED)
	news_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news_lbl.visible = news_lbl.text != ""
	v.add_child(news_lbl)
	add_child(box)
	goal_lbl.text = goal_text()


## Cosa si è appena sbloccato, in parole.
func _news_text() -> String:
	var u: Dictionary = m.unlock
	var out: Array[String] = []
	for t: int in u.get("units", []):
		out.append(Defs.UNITS[t].name)
	var dn := {"repair": "Ripara (R)", "garrison": "Sulle mura (G)", "mangano": "Mangano (M)", "oil": "Olio bollente (O)"}
	for d: String in u.get("defense", []):
		out.append(dn[d])
	for b: int in u.get("build", []):
		out.append(Defs.BUILDINGS[b].name)
	for p: int in u.get("powers", []):
		out.append("%s (%s)" % [Defs.POWERS[p].name, Defs.POWERS[p].key])
	if u.get("groups", false): out.append("gruppi Ctrl+1-0 e Tab")
	if u.get("faith", false): out.append("la Fede")
	if u.get("special", false): out.append("il potere della casata (F)")
	if u.get("events", false): out.append("gli eventi a sorpresa")
	if u.get("taunts", false): out.append("gli sfottò")
	if u.get("all", false): out.append("tutto quanto")
	return ("Novità: " + ", ".join(out)) if not out.is_empty() else ""


func _names(ids: Array) -> String:
	var a: Array[String] = []
	for c: int in ids:
		a.append(String(game.castles[c].name))
	return " e ".join(a)


func goal_text() -> String:
	var g: Dictionary = m.goal
	var el := maxf(sim.time - start_time, 0.0) if running else 0.0
	match String(g.kind):
		"capture":
			return "Obiettivo: prendi %s" % _names(g.castles)
		"survive":
			return "Obiettivo: tieni %s ancora %s" % [Campaign.HOME_NAME, _clock(float(g.secs) - el)]
		"hold":
			return "Obiettivo: tieni %s ancora %s" % [_names(g.castles), _clock(float(g.secs) - el)]
		"waves":
			return "Obiettivo: respingi i banditi (ondata %d di %d)" % [waves_sent, int(m.setup.attack.times)]
		"faith":
			return "Obiettivo: arriva a %d di Fede (ora %d)" % [int(g.amount), int(sim.houses[hero].faith)]
	return ""


static func _clock(s: float) -> String:
	var k := maxi(ceili(s), 0)
	return "%d:%02d" % [k / 60, k % 60]


func _process(dt: float) -> void:
	if not running or ended or sim.paused:
		return
	_waves()
	_check_t += dt
	if _check_t < 0.5:
		return
	_check_t = 0.0
	goal_lbl.text = goal_text()
	if lost():
		finish(false)
	elif won():
		finish(true)


func _waves() -> void:
	var atk: Dictionary = m.setup.get("attack", {})
	if atk.is_empty() or sim.time - start_time < next_wave:
		return
	var times := int(atk.get("times", 1 if not atk.has("every") else 99))
	if waves_sent >= times:
		next_wave = 1e9
		return
	wave_units.append_array(sim.story_attack(int(atk.house), atk.units, Campaign.HOME_CASTLE))
	waves_sent += 1
	next_wave = next_wave + float(atk.get("every", 1e9))
	if game.hud:
		game.hud.notify("Arrivano %s!" % String(sim.houses[int(atk.house)].pname), UiStyle.DANGER_TEXT, 4.0)


func _owns(ids: Array) -> bool:
	for c: int in ids:
		if int(game.castles[c].owner) != hero:
			return false
	return true


func won() -> bool:
	var g: Dictionary = m.goal
	var el := sim.time - start_time
	match String(g.kind):
		"capture": return _owns(g.castles)
		"survive": return el >= float(g.secs)
		"hold": return el >= float(g.secs) and _owns(g.castles)
		"faith": return float(sim.houses[hero].faith) >= float(g.amount)
		"waves":
			if waves_sent < int(m.setup.attack.times):
				return false
			for u: Sim.U in wave_units:
				if u.hp > 0.0:
					return false
			return true
	return false


func lost() -> bool:
	if int(game.castles[Campaign.HOME_CASTLE].owner) != hero:
		return true
	if String(m.goal.kind) == "hold" and not _owns(m.goal.castles):
		return true
	# senza soldati e senza fiorini per farne non si va avanti
	if String(m.goal.kind) == "capture" and sim.house_unit_count(hero) == 0 and float(sim.houses[hero].gold) < 20.0:
		for c: Dictionary in game.castles:
			if int(c.owner) == hero and not (c.queue as Array).is_empty():
				return false
		return true
	return false


func finish(win: bool) -> void:
	if ended:
		return
	ended = true
	running = false
	if is_instance_valid(hints) and not hints.finished:
		hints._finish()
	sim.paused = true
	box.visible = false
	if win and n > Settings.story_done:
		Settings.story_done = n
		Settings.save_all()
	var p: Dictionary = m.win if win else m.lose
	var buttons: Array = []
	if win and m.goal.get("finale", false):
		buttons.append(["Al banchetto!", _finale])
	elif win and n < Campaign.MISSIONS.size():
		buttons.append(["Missione successiva", func(): _restart(n + 1)])
	elif not win:
		buttons.append(["Riprova", func(): _restart(n)])
	buttons.append(["Torna al menu", _to_menu])
	game.hud.newspaper(0, p.title, p.sub, PackedInt32Array(), {"side": p.get("side", []), "mini": "conte" if win else "", "buttons": buttons})


func _finale() -> void:
	game.hud.close_paper()
	sim.paused = false
	sim.winner = hero  # l'interfaccia fa partire il finale di chi vince


func _restart(k: int) -> void:
	game.get_parent().call_deferred("story_from_menu", k)


func _to_menu() -> void:
	game.get_parent().call_deferred("back_to_menu")
