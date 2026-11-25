class_name Sim
extends Node
## Simulazione autoritativa: gira solo sul server. I client ricevono snapshot ed eventi.

class U:
	var id := 0
	var type := 0
	var team := 0
	var pos := Vector3.ZERO
	var target := Vector3.ZERO
	var home := Vector3.ZERO
	var has_order := false
	var goal := -1
	var vox_t := false
	var vox_pos := Vector3.ZERO
	var hp := 1.0
	var cd := 0.0
	var retarget := 0.0
	var tgt: U = null
	var auto_castle := -1
	var moving := false
	var attacking := false
	var water := false
	var drunk := 0.0
	## Spaventato dal terremoto: colpisce a metà forza e più piano finché dura.
	var fear := 0.0
	var shield := false
	var garrison := false
	var pass_gate := false
	var inside_own := -1
	## Cortile nemico in cui si trova (-1 = nessuno): lì il bersaglio è il re sul gabinetto.
	var inside_enemy := -1
	var yaw := 0.0
	var stuck := 0.0
	var fall_from := -1.0
	## Fino a quando (Sim.time) scende dalle mura per un ordine: si cala giù, la caduta non fa male.
	var descend := 0.0
	## Castello proprio da cui sta uscendo (-1 = nessuno): resta valido finché non ha passato la porta.
	var exiting := -1
	## Percorso locale trovato quando era bloccata (vicoli ciechi, borghi, monumenti).
	var path := PackedVector3Array()
	var path_i := 0
	var path_dest := Vector3.ZERO
	var replan_cd := 0.0
	## Controllo dei progressi: chi oscilla senza avanzare non risulta mai "bloccato".
	var prog_t := 0.0
	var prog_pos := Vector3.ZERO
	## Frate addormentato: secondi che restano (non prega).
	var sleep := 0.0
	## Evento comico in corso (sagra, mamma che chiama): va lì e non combatte.
	var feast := 0.0
	var feast_pos := Vector3.ZERO
	var said_hurt := false
	## Scappa urlando davanti a una forma di Parmigiano (secondi, e verso dove).
	var flee := 0.0
	var flee_pos := Vector3.ZERO
	## C'è un menestrello nemico vicino che stona: si combatte peggio.
	var sung := false
	## Recluta in marcia verso la bandiera di raduno del suo castello: arrivata, saluta.
	var to_flag := false
	## Edificio nemico che sta abbattendo (-1 = nessuno).
	var btgt := -1

const R := WorldGen.R
## Scala dei castelli: le distanze legate alle mura crescono con lei.
const CS := WorldGen.CS
const WALL_T := WorldGen.WALL_T
const CELL := 12
const GRAVITY := 30.0
const FIELD_R := 42 + 12 * (CS - 1) * 2
const FIELD_D := FIELD_R * 2 + 1
const MAX_FRAGMENTS := 26

var game: Node
var world: VoxelWorld
var castles: Array = []
var houses: Array = []
var ulist: Array[U] = []
var by_id: Dictionary = {}
var next_uid := 1
var grid: Dictionary = {}
var projectiles: Dictionary = {}
var next_proj := 1
var wheels: Array = []
var domes: Array = []
var sched: Array = []
var oils: Array = []
var fragments: Dictionary = {}
var next_frag := 1
var arrow_fx := PackedFloat32Array()
var winner := -1
var time := 0.0
var rng := RandomNumberGenerator.new()
var _accum := 0.0
var _slow := 0.0
var _state_t := 0.0
var _snap_t := 0.0
var _ai_t := 0.0
var _ai_i := 0
var _integ_i := 0
var ai_aggression := 1.0
var ai_enabled := true
## Pausa (solo partite contro l'IA, dal menu di pausa).
var paused := false
## Modalità (Defs.MODES) e Drappo del Palio: castello, quando si sposta, punti per casata.
var mode := Defs.MODE_CONQUISTA
var drappo := -1
var drappo_move_t := 0.0
var drappo_pts: Array = []
var _drappo_last: Array[int] = []
## Sala d'attesa di chi ospita: il mondo c'è, ma il tempo non scorre finché non si avvia la partita.
var lobby := false
## Difficoltà: rendita dell'IA rispetto a un umano e moltiplicatore del suo esercito massimo.
var ai_income := 0.8
var ai_cap_mult := 1.0
var news_read := {}  # casate che hanno già girato pagina
var news_t := 0.0  # secondi di fermo per il giornale, non si salva
const NEWS_TIME := 14.0
const NEWS_ITEMS := 3
var _cur_event := 0
var _last_king_death := -1
var equal_houses := false  # opzione del menu: spegne i caratteri delle casate
var ai_saving := {}  # casata -> macchina d'assedio per cui sta risparmiando (non si salva)
var _isolation := {}  # castello -> fattore di isolamento, calcolato una volta dalla mappa
var ai_stage := {}  # casata -> raduno in corso {c, pos, ids, t}; non si salva: al caricamento riparte
var bards: Array[U] = []
## Edifici costruiti (fuori dalle mura), di chi li ha costruiti.
var buildings: Array = []
var bldg_by_id: Dictionary = {}
## Voxel da posare per ogni cantiere, dal basso in alto (si ricalcola dopo un caricamento).
var build_plans: Dictionary = {}
var next_bid := 1
## Le torri più alte vedono un po' più lontano.
const TOWER_EXTRA := 5.0 * (CS - 1)
## Sotto attacco la riparazione va a un quarto: aiuta a resistere ma non annulla le catapulte.
## «Ripara tutto»: si paga subito, 0,5 fiorini per blocco mancante, e i muratori ci mettono il tempo che serve.
const REPAIR_COST := 0.5
const REPAIR_PER_SEC := 40.0
## Sotto attacco i muratori lavorano a un quarto della velocità.
const REPAIR_PER_SEC_ATTACKED := 10.0
## Primi due minuti di tregua: nessuna IA attacca, tutti hanno tempo di prepararsi.
const TRUCE_TIME := 120.0
const AI_GUARD := 4
## Fin dove l'IA guarda che soldati le mandano contro, per scegliere le reclute.
const AI_HORSE_SEE := 160.0
const AI_MIN_ARMY := 22
const AI_DEFEND_MIN := 4
const AI_HOUSE_GRACE := 120.0
## Chi ha almeno tanti castelli diventa il bersaglio preferito: le altre casate reagiscono.
const AI_LEADER_CASTLES := 3
const AI_LEADER_FACTOR := 0.75
## Castello che nessuno attacca da QUIET_START secondi: sembra sempre più vicino alle IA,
## fino a QUIET_MIN volte la sua distanza dopo QUIET_FULL secondi. Così nessuno resta al sicuro.
const QUIET_START := 120.0
const QUIET_FULL := 480.0
const QUIET_MIN := 0.3
## Un castello lontano da tutti (le isole) non deve essere al sicuro per geografia: la sua distanza
## viene ridotta quanto più il vicino più prossimo supera ISOLATION_REF, fino a ISOLATION_MIN volte.
const ISOLATION_REF := 240.0
const ISOLATION_MIN := 0.35
const TOWER_DAMAGE := 6.0
## Difese automatiche: ogni torre (e il mastio) tira TOWER_SHOTS frecce a bersagli diversi ogni TOWER_CD s,
## prima alle macchine d'assedio. Il mangano del mastio tira da solo dove i nemici sono ammassati,
## e l'olio bollente cade da solo su chi si accalca sotto le mura.
const TOWER_CD := 1.0
const TOWER_SHOTS := 1
const TOWER_RANGE := 34.0 + 10.0 * (WorldGen.CS - 1)
const MANGANO_AUTO_CD := 9.0
const OIL_AUTO_CD := 20.0
const OIL_AUTO_MIN := 4
## Con nemici più vicini di così la milizia gratuita non arriva: non deve annullare una conquista.
const MILITIA_SAFE_DIST := 35.0 + 12.0 * (CS - 1)
## Il re: si conquista il castello solo uccidendolo. Senza colpi si riprende in fretta.
const KING_HP := 800.0
const KING_REGEN := 12.0
const KING_CALM := 3.0
## Il nuovo re appena seduto ha bisogno di un momento (e non lo si può colpire).
const KING_SAFE := 12.0
## Ogni truppa già in marcia verso un castello lo rende meno appetibile: niente accanimenti in più casate.
const AI_PILE_PENALTY := 0.06
const AI_RAMP_SECONDS := 600.0
## L'armata dell'IA si raduna fuori tiro dalle torri e assalta compatta: se ognuno arrivasse
## con il suo passo (cavalieri davanti, arieti ore dopo) le torri li mangerebbero a piccoli gruppi.
const AI_STAGE_TIMEOUT := 90.0
const AI_STAGE_RADIUS := 22.0
const AI_STAGE_READY := 0.8
const AI_STAGE_MIN := 6
## Fonti di danno nelle statistiche: dopo i tipi di unità (Frate, Nonna e Menestrello sono 6, 7, 8).
const SRC_TOWER := 9
const SRC_POWER := 10
const SRC_CASTLE := 11
var repair_slow_when_attacked := true
var seed_override := -1
var truce_until := TRUCE_TIME
## Eventi a sorpresa: il prossimo fra quanti secondi, e fino a quando dura la processione.
var event_t := 240.0
var procession_until := 0.0
## Palio in corso: traguardo e fino a quando (0 = nessuno).
var palio_pos := Vector3.ZERO
var palio_until := 0.0
var say_cd := 0.0
var taunt_cd: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## Uno sfottò ogni tanto, non a raffica.
const TAUNT_CD := 15.0
## Falso nei test di bilanciamento: gli eventi cambierebbero i risultati.
var events_enabled := true
## Storia: cosa può usare chi gioca (vedi Campaign.unlocked_at). Vuoto = tutto, come nella partita libera.
## Vale solo per le casate umane: l'IA della missione usa quello che il setup le dà.
var locks: Dictionary = {}


## Gli sblocchi della missione n: la missione 12 (o più) sblocca tutto.
func set_story_locks(n: int) -> void:
	var u := Campaign.unlocked_at(n)
	locks = {} if bool(u.all) else u
	events_enabled = locks.is_empty() or bool(locks.events)


## Storia: prepara la partita della missione. Il mondo è appena nato: si tolgono soldati e padroni
## della partita libera e si mette quello che dice Campaign (vedi lì il formato di setup).
func story_setup(hero: int, setup: Dictionary) -> void:
	mode = Defs.MODE_CONQUISTA  # la storia ha i suoi obiettivi
	ulist.clear()
	by_id.clear()
	truce_until = 0.0
	ai_aggression = float(setup.get("aggr", 1.0))
	ai_cap_mult = float(setup.get("cap", 1.0))
	var owners: Dictionary = setup.get("owners", {})
	var guards: Dictionary = setup.get("guards", {})
	for c: Dictionary in castles:
		c.owner = int(owners.get(c.id, Defs.NEUTRAL))
		c.queue = []
		c.lord = ""  # la storia ha i suoi personaggi: niente signorie minori, solo il Podestà
		c.flag_on = false
	castles[Campaign.HOME_CASTLE].owner = hero
	castles[Campaign.HOME_CASTLE].name = Campaign.HOME_NAME
	var ai_on: Array = setup.get("ai", [])
	for t in houses.size():
		houses[t].pname = ""
		houses[t].alive = t != Defs.NEUTRAL
		if t != hero:
			houses[t].ai = t in ai_on
	var pn: Dictionary = setup.get("pnames", {})
	for t: int in pn:
		houses[t].pname = String(pn[t])
	houses[hero].pname = "Conte di Borgo Spigolo"
	houses[hero].gold = float(setup.get("gold", 200))
	houses[hero].faith = float(setup.get("faith", 0))
	for c: Dictionary in castles:
		var g: Array = guards.get(c.id, [])
		if g.is_empty():
			g = [0, 0, 0] if c.owner == hero else ([5, 2, 0] if c.owner == Defs.NEUTRAL else [4, 2, 0])
		var types: Array[int] = []
		for k in int(g[0]): types.append(Defs.FANTE)
		for k in int(g[1]): types.append(Defs.BALESTRIERE)
		for k in int(g[2]): types.append(Defs.CAVALIERE)
		for t in types:
			var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)) * CS
			var u := spawn_unit(t, c.owner, (c.rally as Vector3) + off)
			u.home = u.pos
	var home: Dictionary = castles[Campaign.HOME_CASTLE]
	var army: Dictionary = setup.get("army", {})
	var k := 0
	var dir: Vector3 = home.dir
	var side := Vector3(-dir.z, 0, dir.x)
	for t: int in army:
		for i in int(army[t]):
			var u := spawn_unit(t, hero, (home.gate_out as Vector3) + dir * (3.0 + k / 5 * 2.2) + side * (k % 5 - 2.0) * 2.2)
			u.home = u.pos
			k += 1


## Storia: manda un'ondata di soldati della casata team contro un castello, partendo da lontano.
func story_attack(team: int, units: Dictionary, target_cid: int) -> Array[U]:
	var c: Dictionary = castles[target_cid]
	var from: Vector3 = (c.center as Vector3) + (c.dir as Vector3) * 70.0
	var out: Array[U] = []
	var ids := PackedInt32Array()
	var k := 0
	for t: int in units:
		for i in int(units[t]):
			var p := from + Vector3(k % 5 * 2.2 - 4.4, float(world.top_y(int(from.x), int(from.z))), k / 5 * 2.2)
			var u := spawn_unit(t, team, p)
			out.append(u)
			ids.append(u.id)
			k += 1
	cmd_order(team, ids, c.center, false)
	return out


## Può la casata usare questa cosa? kind: unit, defense, build, power, groups, faith, special, events, taunts.
func allowed(team: int, kind: String, id: Variant = null) -> bool:
	if locks.is_empty() or team < 0 or team >= houses.size() or houses[team].ai:
		return true
	match kind:
		"unit": return int(id) in locks.units
		"defense": return String(id) in locks.defense
		"build": return int(id) in locks.build
		"power": return int(id) in locks.powers
	return bool(locks.get(kind, false))


## Un comando arrivato da chi gioca: è fra le cose già sbloccate?
func cmd_allowed(team: int, kind: String, a: Array) -> bool:
	match kind:
		"recruit": return allowed(team, "unit", a[1])
		"garrison", "repair", "mangano", "oil": return allowed(team, "defense", kind)
		"power", "power_aim": return allowed(team, "power", a[0])
		"build": return allowed(team, "build", a[0])
		"special": return allowed(team, "special")
		"taunt": return allowed(team, "taunts")
	return true
## Statistiche per il simulatore di bilanciamento (spente in partita).
var stats: Dictionary = {}


func setup(g: Node, castle_defs: Array) -> void:
	game = g
	world = g.world
	if seed_override >= 0:
		rng.seed = seed_override
	else:
		rng.randomize()
	castles = castle_defs
	for i in Defs.HOUSES.size():
		houses.append({"gold": 220.0, "faith": 35.0, "cd": [0.0, 0.0, 0.0, 0.0, 0.0], "ai": true, "peer": 0, "pname": "", "army_t": rng.randf_range(10.0, 25.0), "alive": i != Defs.NEUTRAL, "repair_spent": 0.0, "repair_rate": 0.0, "all_shops": false, "sleep_msg_t": 0.0, "faith_rate": 0.0})
	for c: Dictionary in castles:
		c.owner = c.start_house
		c.capture = 0.0
		c.capture_by = -1
		c.queue = []
		c.tower_cd = 0.0
		c.shot_cd = 0.0
		c.oil_cd = 0.0
		c.repair = false
		c.repair_i = 0
		c.repair_left = 0
		c.repair_total = 0
		c.repair_acc = 0.0
		c.repair_found = false
		c.missing = 0
		c.quiet_t = 0.0
		c.flag = Vector3.ZERO
		c.flag_on = false
		c.integrity = 1.0
		c.field = PackedInt32Array()
		c.field_dirty = true
		c.field_t = -10.0
		c.militia_t = 6.0
		c.under_attack = false
		c.king_hp = KING_HP
		c.king_calm = 0.0
		c.king_safe = 0.0
		c.king_by = -1
		c.king_quip_t = 0.0
		var bp: PackedInt64Array = c.blueprint
		c.bp_size = bp.size()
		# guarnigione iniziale
		var n: int = (7 if c.owner == Defs.NEUTRAL else 5) + int(Defs.CASTLES[c.id].get("guard", 0))
		for k in n:
			var t: int = Defs.BALESTRIERE if k % 3 == 2 else Defs.FANTE
			var off := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)) * CS
			var u := spawn_unit(t, c.owner, (c.rally as Vector3) + off)
			if c.owner == Defs.NEUTRAL:
				u.home = u.pos
	# i campi di percorso dei castelli si calcolano qui, al caricamento: il primo calcolo
	# durante la partita costava ~25 ms in un tick solo, appena qualcuno si avvicinava
	for c: Dictionary in castles:
		_compute_field(c)


# ---------------------------------------------------------------- comandi
func spawn_unit(type: int, team: int, p: Vector3) -> U:
	var u := U.new()
	u.id = next_uid
	next_uid = next_uid + 1 if next_uid < 60000 else 1
	u.type = type
	u.team = team
	u.pos = p
	var y := world.walk_y(p.x, p.y + 3.0, p.z, true)
	if y > -999.0:
		u.pos.y = y
	u.home = u.pos
	u.hp = float(Defs.UNITS[type].hp)
	u.retarget = rng.randf() * 0.5
	u.yaw = rng.randf() * TAU
	ulist.append(u)
	by_id[u.id] = u
	return u


func house_unit_count(team: int) -> int:
	var n := 0
	for u in ulist:
		if u.team == team:
			n += 1
	return n


func cmd_recruit(team: int, cid: int, type: int) -> void:
	if cid < 0 or cid >= castles.size() or type < 0 or type >= Defs.UNIT_TYPES:
		return
	var c: Dictionary = castles[cid]
	var d: Dictionary = Defs.UNITS[type]
	var price: float = float(d.cost) * (0.5 if float(houses[team].get("discount_until", 0.0)) > time else 1.0)
	if c.owner != team or float(houses[team].gold) < price:
		return
	if type == Defs.FRATE and not has_building(team, Defs.B_CHIESA):
		return
	if (c.queue as Array).size() >= 8:
		return
	if unit_room(team) <= 0:
		return
	houses[team].gold -= price
	if not stats.is_empty():
		stats.recruited[type] += 1
		stats.spent[team] += float(d.cost)
	(c.queue as Array).append({"type": type, "t": float(d.time)})


## Un castello distrutto recluta più piano: velocità pari alle mura in piedi, mai sotto RECRUIT_MIN.
const RECRUIT_MIN := 0.25


static func recruit_speed(c: Dictionary) -> float:
	return clampf(float(c.get("integrity", 1.0)), RECRUIT_MIN, 1.0)


## Il limite di truppe di una casata: cresce con i castelli che tiene.
func unit_cap(team: int) -> int:
	if houses[team].ai:
		return int((Defs.AI_UNIT_CAP + Defs.AI_UNIT_CAP_PER_CASTLE * _castles_of(team)) * ai_cap_mult)
	return Defs.unit_cap(_castles_of(team))


## Quanti soldati può ancora avere, contando quelli in coda nei castelli.
func unit_room(team: int) -> int:
	if team < 0 or team >= Defs.HOUSE_COUNT:
		return 0
	return unit_cap(team) - house_unit_count(team) - _queued(team)


func _castles_of(team: int) -> int:
	var n := 0
	for c: Dictionary in castles:
		if c.owner == team:
			n += 1
	return n


func _queued(team: int) -> int:
	var n := 0
	for c: Dictionary in castles:
		if c.owner == team:
			n += (c.queue as Array).size()
	return n


func castle_at(p: Vector3, margin := 3.0) -> int:
	for c: Dictionary in castles:
		var ce: Vector3 = c.center
		if absf(p.x - ce.x) <= R + margin and absf(p.z - ce.z) <= R + margin:
			return c.id
	return -1


## Tregua: le casate non si combattono fra loro (i castelli liberi invece si prendono).
func at_peace(a: int, b: int) -> bool:
	return time < truce_until and a != b and a != Defs.NEUTRAL and b != Defs.NEUTRAL and a >= 0 and b >= 0


func cmd_order(team: int, ids: PackedInt32Array, point: Vector3, on_struct: bool) -> void:
	var list: Array[U] = []
	for id in ids:
		var u: U = by_id.get(id)
		if u != null and u.team == team:
			list.append(u)
	if list.is_empty():
		return
	var goal := castle_at(point)
	var bhit := -1
	if on_struct:
		var bb := building_at(point)
		if not bb.is_empty() and int(bb.owner) != team:
			bhit = int(bb.id)
			if at_peace(team, int(bb.owner)):
				game.msg_house(team, "Tregua: le botteghe delle altre casate non si toccano fino alla fine", UiStyle.DANGER_TEXT)
				return
	if goal >= 0 and at_peace(team, int(castles[goal].owner)):
		game.msg_house(team, "Tregua: %s non si attacca ancora. Prendi i castelli liberi!" % castles[goal].name, UiStyle.DANGER_TEXT)
		return
	var p := point
	if goal >= 0 and not on_struct:
		p = castles[goal].rally
	var cols := int(ceil(sqrt(float(list.size()))))
	# il fronte della formazione guarda il bersaglio
	var center := Vector3.ZERO
	for u in list:
		center += u.pos
	center /= list.size()
	var fwd := (p - center); fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := Vector3(-fwd.z, 0, fwd.x)
	# in formazione: chi tira sta dietro, i cavalieri ai lati
	list.sort_custom(func(a: U, b: U): return _rank(a) < _rank(b))
	for k in list.size():
		var u := list[k]
		u.to_flag = false
		var row := k / cols
		var col := k % cols
		var offs := side * ((col - (cols - 1) * 0.5) * 2.0) - fwd * (row * 2.0)
		if u.garrison:
			u.descend = time + 5.0
		u.garrison = false
		u.has_order = true
		u.stuck = 0.0
		var is_siege: bool = u.type == Defs.CATAPULTA or u.type == Defs.BOMBARDA
		u.vox_t = false
		u.btgt = -1
		if on_struct and not is_siege and bhit >= 0:
			u.btgt = bhit
			u.goal = -1
			u.target = point + offs
			continue
		if is_siege and on_struct:
			u.vox_t = true
			u.vox_pos = point
			u.goal = -1
			u.target = point + offs
		else:
			u.goal = goal if not is_siege else -1
			u.target = p + offs


# ---------------------------------------------------------------- bandiera di raduno
## Clic destro con il castello selezionato: le reclute di quel castello andranno lì.
## Un clic sul castello stesso la toglie, come cmd_rally_clear.
func cmd_rally(team: int, cid: int, p: Vector3) -> void:
	var c: Dictionary = castles[cid]
	if int(c.owner) != team:
		return
	var on := castle_at(p, 2.0)
	if on == cid:
		c.flag_on = false
		return
	if on >= 0 and at_peace(team, int(castles[on].owner)):
		game.msg_house(team, "Tregua: %s non si attacca ancora. Metti il pentolone altrove" % castles[on].name, UiStyle.DANGER_TEXT)
		return
	p.y = float(world.top_y(int(p.x), int(p.z)))
	# accanto al pentolone di un altro tuo castello: ci si unisce, un pentolone solo
	for o: Dictionary in castles:
		if o.id != cid and int(o.owner) == team and bool(o.get("flag_on", false)) and Vector2(p.x - o.flag.x, p.z - o.flag.z).length() < RALLY_JOIN_R:
			p = o.flag
			game.msg_house(team, "Più siamo, meglio è! Le reclute di %s vanno al pentolone di %s" % [c.name, o.name], UiStyle.GOLD)
			break
	c.flag = p
	c.flag_on = true


## Entro questa distanza da un pentolone che c'è già, il nuovo si unisce a quello.
const RALLY_JOIN_R := 8.0


## La bandiera torna al castello: le reclute restano davanti alla porta.
func cmd_rally_clear(team: int, cid: int) -> void:
	if int(castles[cid].owner) == team:
		castles[cid].flag_on = false


## Manda la recluta appena uscita alla bandiera, un po' sparpagliata per non fare la fila.
func _to_flag(u: U, c: Dictionary) -> void:
	var ang := rng.randf() * TAU
	var at: Vector3 = (c.flag as Vector3) + Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(2.5, 6.0)
	cmd_order(u.team, PackedInt32Array([u.id]), at, false)
	u.to_flag = u.has_order


func _rank(u: U) -> int:
	match u.type:
		Defs.CAVALIERE: return 0
		Defs.FANTE, Defs.ARIETE: return 1
		Defs.BALESTRIERE: return 2
	return 3


## Manda i balestrieri vicini sul cammino di ronda.
func cmd_garrison(team: int, cid: int) -> void:
	var c: Dictionary = castles[cid]
	if c.owner != team:
		return
	var slots: Array = c.slots.duplicate()
	var ce: Vector3 = c.center
	for u in ulist:
		if u.team != team or u.type != Defs.BALESTRIERE or u.garrison or slots.is_empty():
			continue
		if u.pos.distance_to(ce) > 45.0 + R:
			continue
		var best := 0
		var bd := 1e9
		for k in slots.size():
			var d: float = (slots[k] as Vector3).distance_to(u.pos)
			if d < bd:
				bd = d
				best = k
		var s: Vector3 = slots[best]
		slots.remove_at(best)
		if world.get_v(int(s.x), int(s.y) - 1, int(s.z)) == 0:
			continue
		u.pos = s
		u.garrison = true
		u.has_order = false


# ---------------------------------------------------------------- signorie minori
## Ognuna ha il suo carattere (Defs.CASTLES, trait). Valgono solo finché il castello è della signoria.
func _lord_trait(c: Dictionary) -> String:
	if int(c.owner) != Defs.NEUTRAL or String(c.get("lord", "")) == "":
		return ""
	return String(c.get("trait", ""))


func _tick_lords(dt: float) -> void:
	for c: Dictionary in castles:
		match _lord_trait(c):
			"voltagabbana":
				_turncoat_check(c)
			"tributo":
				_tribute(c, dt)


## Malatesta: davanti a un'armata tre volte la loro, cambiano bandiera senza combattere.
func _turncoat_check(c: Dictionary) -> void:
	var ce: Vector3 = c.center
	var per := {}
	var guards := 0
	for u in ulist:
		if u.hp <= 0.0 or u.water:
			continue
		var d := Vector2(u.pos.x - ce.x, u.pos.z - ce.z).length()
		if u.team == Defs.NEUTRAL:
			if d < R + 6.0:
				guards += 1
		elif d < R + 28.0 and u.type != Defs.FRATE and u.feast <= 0.0:
			per[u.team] = int(per.get(u.team, 0)) + 1
	var best := -1
	var bn := 0
	for t: int in per:
		if int(per[t]) > bn:
			bn = per[t]
			best = t
	if best < 0 or bn < maxi(Defs.TURNCOAT_MIN, guards * Defs.TURNCOAT_RATIO):
		return
	game.msg_all("I Malatesta cambiano bandiera: %s passa a %s senza un colpo. «Siamo sempre stati con voi»" % [c.name, _hname(best)], Defs.HOUSES[best].color)
	_capture(c, best)


## Arborea: ogni tanto il Giudice paga chi lascia in pace la Sardegna. Chi la disturba resta senza per un po'.
func _tribute(c: Dictionary, dt: float) -> void:
	var island: Array[Vector3] = []
	var land := Defs.landmass(c.id)
	for o: Dictionary in castles:
		if Defs.landmass(o.id) == land:
			island.append(o.center)
	for u in ulist:
		if u.team != Defs.NEUTRAL and u.hp > 0.0 and u.team < Defs.HOUSE_COUNT:
			for oc: Vector3 in island:
				if Vector2(u.pos.x - oc.x, u.pos.z - oc.z).length() < R + 45.0:
					houses[u.team].arborea_until = time + Defs.TRIBUTE_GRUDGE
					break
	c.tribute_t = float(c.get("tribute_t", 0.0)) + dt
	if float(c.tribute_t) < Defs.TRIBUTE_EVERY:
		return
	c.tribute_t = 0.0
	for t in Defs.HOUSE_COUNT:
		if not houses[t].alive:
			continue
		if time >= float(houses[t].get("arborea_until", 0.0)):
			houses[t].gold = float(houses[t].gold) + Defs.TRIBUTE_GOLD
			game.msg_house(t, "Il Giudice d'Arborea ti manda %d fiorini: «Basta che lasciate in pace la Sardegna»" % int(Defs.TRIBUTE_GOLD), UiStyle.GOLD)
		else:
			game.msg_house(t, "Niente tributo dal Giudice d'Arborea: hai disturbato la Sardegna", UiStyle.MUTED)


## Este: il castello si compra. Si paga in contanti e si entra dalla porta principale.
func cmd_buy(team: int, cid: int) -> void:
	var c: Dictionary = castles[cid]
	if team < 0 or team >= Defs.HOUSE_COUNT or _lord_trait(c) != "compra":
		return
	if float(houses[team].gold) < Defs.LORD_PRICE:
		game.msg_house(team, "Gli Este vogliono %d fiorini. In contanti" % Defs.LORD_PRICE, UiStyle.DANGER_TEXT)
		return
	houses[team].gold = float(houses[team].gold) - Defs.LORD_PRICE
	game.msg_all("%s compra %s dagli Este. «Affare fatto: il gabinetto è compreso»" % [_hname(team), c.name], Defs.HOUSES[team].color)
	_capture(c, team, true)


## «Ripara tutto il castello»: conta i blocchi mancanti, fa pagare subito tutto il conto e avvia i lavori.
## Finché i lavori non sono finiti non si riclicca.
func cmd_repair(team: int, cid: int) -> void:
	var c: Dictionary = castles[cid]
	if c.owner != team or bool(c.repair):
		return
	_update_integrity(c)
	var n: int = c.missing
	if n <= 0:
		game.msg_house(team, "Le mura di %s sono intatte" % c.name, UiStyle.MUTED)
		return
	var cost := repair_cost(n)
	if float(houses[team].gold) < cost:
		game.msg_house(team, "Per riparare tutto %s servono %d fiorini" % [c.name, cost], UiStyle.DANGER_TEXT)
		return
	houses[team].gold = float(houses[team].gold) - cost
	houses[team].repair_spent = float(houses[team].repair_spent) + cost
	c.repair = true
	c.repair_total = n
	c.repair_left = n
	c.repair_i = 0
	c.repair_acc = 0.0
	c.repair_found = false
	game.msg_house(team, "Muratori al lavoro a %s: %d blocchi, %d fiorini, circa %d secondi" % [c.name, n, cost, repair_secs(n)], UiStyle.GOLD)


static func repair_cost(blocks: int) -> int:
	return ceili(blocks * REPAIR_COST)


static func repair_secs(blocks: int) -> int:
	return maxi(ceili(blocks / REPAIR_PER_SEC), 1)


func cmd_mangano(team: int, cid: int, p: Vector3) -> void:
	var c: Dictionary = castles[cid]
	if c.owner != team or c.shot_cd > 0.0:
		return
	var from: Vector3 = (c.keep as Vector3) + Vector3(0, WorldGen.KEEP_H + 2, 0)
	if from.distance_to(p) > 60.0 + R:
		return
	if time < truce_until and _truce_target(team, p):
		game.msg_house(team, "Tregua: il mangano tira solo sui castelli liberi", UiStyle.DANGER_TEXT)
		return
	c.shot_cd = 5.0
	_fire_arc(from, p, Defs.SHOT_STONE, team, 34.0)


func cmd_oil(team: int, cid: int, p: Vector3) -> void:
	var c: Dictionary = castles[cid]
	if c.owner != team or c.oil_cd > 0.0 or houses[team].gold < 25.0 or (time < truce_until and _truce_target(team, p)):
		return
	var ce: Vector3 = c.center
	if Vector2(p.x - ce.x, p.z - ce.z).length() > R + 14.0:
		return
	houses[team].gold -= 25.0
	c.oil_cd = 14.0
	oils.append({"pos": p, "t": 5.0, "team": team})
	game.fx_all("oil", p, 5.0)


# ---------------------------------------------------------------- poteri
func cmd_power(team: int, kind: int, p: Vector3, aim := Vector3.ZERO) -> void:
	if kind < 0 or kind >= Defs.POWER_COUNT:
		return
	var h: Dictionary = houses[team]
	var pw: Dictionary = Defs.POWERS[kind]
	if h.faith < pw.cost or h.cd[kind] > 0.0 or not has_building(team, Defs.POWER_BUILDING[kind]):
		return
	if time < procession_until:
		game.msg_house(team, "Processione in corso: i poteri aspettano che passi il Santo", UiStyle.DANGER_TEXT)
		return
	if time < truce_until and _truce_target(team, p):
		game.msg_house(team, "Tregua: niente poteri sulle altre casate. Usali sui castelli liberi", UiStyle.DANGER_TEXT)
		return
	h.faith -= float(pw.cost)
	h.cd[kind] = float(pw.cd)
	if not stats.is_empty():
		stats.powers[kind] += 1
	if _concerns_humans(team, p):
		game.msg_all(_quip(kind, team, p), Defs.HOUSES[team].color)
	match kind:
		Defs.P_MUCCHE:
			for k in 12:
				sched.append({"t": 0.15 + k * 0.22, "kind": "cow", "pos": p, "team": team})
		Defs.P_PARMIGIANO:
			if Vector2(aim.x, aim.z).length() >= WHEEL_AIM_MIN:
				_spawn_wheel_aimed(team, p, aim)
			else:
				_spawn_wheel(team, p)
		Defs.P_VINO:
			for u in ulist:
				if u.team == team and u.pos.distance_to(p) < 34.0:
					u.drunk = 16.0
					u.hp = minf(u.hp + 15.0, float(Defs.UNITS[u.type].hp))
					if rng.randf() < 0.12:
						_say(u, Defs.SAY_UBRIACO, true)
			game.fx_all("wine", p, 34.0)
		Defs.P_TERREMOTO:
			for k in 14:
				sched.append({"t": 0.2 + k * 0.33, "kind": "quake", "pos": p, "team": team})
			game.fx_all("quake", p, 5.0)
		Defs.P_SCUDO:
			domes.append({"pos": p, "r": 20.0, "t": 13.0, "team": team})
			game.fx_all("dome", p, 13.0)


## Un potere fa notizia se lo lancia un giocatore o se cade vicino a un suo castello.
func _concerns_humans(team: int, p: Vector3) -> bool:
	if not houses[team].ai:
		return true
	for c: Dictionary in castles:
		if not houses[int(c.owner)].ai and (c.center as Vector3).distance_to(p) < 58.0 + R:
			return true
	return false


## Il castello più vicino a un punto: dà il nome della città alle battute dei poteri.
func _city_near(p: Vector3) -> String:
	var best := ""
	var bd := 1e9
	for c: Dictionary in castles:
		var d: float = (c.center as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = c.name
	return best


## Annuncio comico di un potere: casata che lo lancia e città colpita.
func _quip(kind: int, team: int, p: Vector3) -> String:
	var lines: Array = Defs.QUIPS[kind]
	var line: String = lines[rng.randi() % lines.size()]
	return line.format({"c": _hname(team), "t": _city_near(p)})


func _wheel_report(wh: Dictionary, p: Vector3) -> void:
	var k: int = wh.kills
	if k < 2 or not _concerns_humans(int(wh.team), p):
		return
	var lines: Array = Defs.WHEEL_REPORTS
	var line: String = lines[rng.randi() % lines.size()]
	game.msg_all(line.format({"n": k, "c": _hname(wh.team), "t": _city_near(p)}), Defs.HOUSES[wh.team].color)


func _hname(team: int) -> String:
	var h: Dictionary = houses[team]
	return (h.pname as String) if h.pname != "" else String(Defs.HOUSES[team].name)


## Margine attorno a un castello proprio entro cui la forma si ferma (mura, torri e raggio della forma).
const WHEEL_OWN_MARGIN := R + 8.0
const WHEEL_START_DIST := 55.0
## Lancio a mano: quanto va trascinato il mouse (in metri di mappa) e la velocità che ne esce.
const WHEEL_AIM_MIN := 6.0
const WHEEL_AIM_MAX := 80.0
const WHEEL_SPEED_MIN := 22.0
const WHEEL_SPEED_MAX := 64.0
const WHEEL_OVERSHOOT := 70.0
## Danno a chi viene travolto (una volta sola per forma): un Fante sopravvive di un soffio.
const WHEEL_DMG := 38.0
## Blocchi di muro che la forma può scavare prima di sbriciolarsi.
const WHEEL_WALL_BUDGET := 260 * CS


## Tiro scelto da chi gioca: parte da dove si è premuto, va dove si è trascinato, e più lungo
## è il vettore più corre.
func _spawn_wheel_aimed(team: int, p: Vector3, aim: Vector3) -> void:
	var flat := Vector3(aim.x, 0.0, aim.z)
	var k := clampf((flat.length() - WHEEL_AIM_MIN) / (WHEEL_AIM_MAX - WHEEL_AIM_MIN), 0.0, 1.0)
	var s := Vector3(clampf(p.x, 8.0, Defs.WX - 8.0), 0.0, clampf(p.z, 8.0, Defs.WZ - 8.0))
	s.y = world.top_y(int(s.x), int(s.z)) + 8.0
	var vel := flat.normalized() * lerpf(WHEEL_SPEED_MIN, WHEEL_SPEED_MAX, k)
	wheels.append({"id": next_proj, "pos": s, "vel": vel, "t": 11.0, "team": team, "roll": 0.0, "hit": {}, "kills": 0, "carved": 0})
	next_proj += 1


## La forma non deve passare sui propri castelli: tra 16 direzioni sceglie la più lontana da loro,
## preferendo partire da terra e dal lato del castello amico più vicino.
func _spawn_wheel(team: int, p: Vector3) -> void:
	var toward_home := Vector3.ZERO
	var best_home := 1e9
	for c: Dictionary in castles:
		if c.owner == team:
			var d: float = (c.center as Vector3).distance_to(p)
			if d < best_home and d > 6.0:
				best_home = d
				toward_home = ((c.center as Vector3) - p).normalized()
	var start_dir := Vector3.BACK
	var best_score := -1e9
	for k in 16:
		var ang := k * TAU / 16.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var from := p + dir * WHEEL_START_DIST
		var to := p - dir * WHEEL_OVERSHOOT
		var clearance := 1e9
		for c: Dictionary in castles:
			if c.owner == team:
				clearance = minf(clearance, _segment_distance_2d(from, to, c.center))
		var score := minf(clearance, 60.0) + dir.dot(toward_home) * 8.0
		if world.top_y(int(clampf(from.x, 0.0, Defs.WX - 1.0)), int(clampf(from.z, 0.0, Defs.WZ - 1.0))) > Defs.SEA:
			score += 20.0
		if score > best_score:
			best_score = score
			start_dir = dir
	var s := p + start_dir * WHEEL_START_DIST
	s.x = clampf(s.x, 8.0, Defs.WX - 8.0)
	s.z = clampf(s.z, 8.0, Defs.WZ - 8.0)
	s.y = world.top_y(int(s.x), int(s.z)) + 22.0
	var vel := (p - s); vel.y = 0.0
	vel = vel.normalized() * 34.0
	wheels.append({"id": next_proj, "pos": s, "vel": vel, "t": 11.0, "team": team, "roll": 0.0, "hit": {}, "kills": 0, "carved": 0})
	next_proj += 1


# ---------------------------------------------------------------- tick
func _physics_process(dt: float) -> void:
	if paused:
		return
	if news_t > 0.0:  # tutti leggono il giornale: la guerra aspetta
		news_t -= dt
		return
	_accum += dt
	var step := 1.0 / Defs.SIM_HZ
	if _accum >= step:
		_accum -= step
		if _accum > step * 3.0:
			_accum = 0.0
		if not lobby:
			tick(step)
	_snap_t += dt
	if _snap_t >= 0.1:
		_snap_t = 0.0
		_send_snapshot()
	_state_t += dt
	if _state_t >= 0.4:
		_state_t = 0.0
		game.broadcast_state(state_array())


func tick(dt: float) -> void:
	time += dt
	_plans_left = PLAN_PER_TICK
	_rebuild_grid()
	bards.clear()
	for u: U in ulist:
		if u.type == Defs.MENESTRELLO and u.hp > 0.0:
			bards.append(u)
	for u: U in ulist.duplicate():
		if u.hp > 0.0:
			_tick_unit(u, dt)
	_cleanup_dead()
	_advance_fields()
	_tick_projectiles(dt)
	_tick_wheels(dt)
	_tick_sched(dt)
	_tick_domes(dt)
	_tick_oil(dt)
	_slow += dt
	if _slow >= 0.5:
		_tick_slow(_slow)
		_slow = 0.0
	_ai_t += dt
	if _ai_t >= 0.25:
		_ai_t = 0.0
		_ai_i = (_ai_i + 1) % Defs.HOUSE_COUNT
		if ai_enabled and houses[_ai_i].ai and houses[_ai_i].alive:
			_ai_tick(_ai_i, 2.0)
	# integrità mura: un castello per tick
	if int(time * Defs.SIM_HZ) % 8 == 0:
		_integ_i = (_integ_i + 1) % castles.size()
		_update_integrity(castles[_integ_i])


func _rebuild_grid() -> void:
	grid.clear()
	for u in ulist:
		var k := int(u.pos.x) / CELL + int(u.pos.z) / CELL * 1000
		var a: Array = grid.get(k, [])
		if a.is_empty():
			grid[k] = a
		a.append(u)


func _cleanup_dead() -> void:
	var i := ulist.size() - 1
	while i >= 0:
		var u := ulist[i]
		if u.hp <= 0.0:
			by_id.erase(u.id)
			ulist[i] = ulist[ulist.size() - 1]
			ulist.resize(ulist.size() - 1)
		i -= 1


func _find_enemy(u: U, radius: float, melee: bool) -> U:
	var best: U = null
	var bd := radius * radius
	var cr := int(radius) / CELL + 1
	var cx := int(u.pos.x) / CELL
	var cz := int(u.pos.z) / CELL
	for dz in range(-cr, cr + 1):
		for dx in range(-cr, cr + 1):
			var a: Variant = grid.get(cx + dx + (cz + dz) * 1000)
			if a == null:
				continue
			for o: U in a:
				if o.team == u.team or o.hp <= 0.0 or o.feast > 0.0 or at_peace(u.team, o.team):  # chi è a tavola non si tocca
					continue
				var d := o.pos.distance_squared_to(u.pos)
				if d < bd:
					if melee and absf(o.pos.y - u.pos.y) > 2.6:
						continue
					bd = d
					best = o
	return best


## Il moltiplicatore del carattere di una casata; 1 se la partita è a casate uguali.
func _stat(team: int, stat: int) -> float:
	return 1.0 if equal_houses else Defs.stat_mult(team, stat)


# ---------------------------------------------------------------- il potere scemo di ogni casata
const SPECIAL_CD := 90.0
const DISCOUNT_T := 25.0  # Prendi 2 paghi 1
const SPECIAL_R := 34.0


func _zone_enemies(team: int, p: Vector3) -> Array:
	var out: Array = []
	for u: U in ulist:
		if u.team != team and u.hp > 0.0 and not u.garrison and not at_peace(team, u.team) and u.pos.distance_to(p) < SPECIAL_R:
			out.append(u)
	return out


## Chi difende il proprio re in pericolo non molla il posto: niente spritz, moduli, fughe o buste.
## Vale vicino a un castello della sua casata col re colpito da poco o già ferito.
const DUTY_R := R + 30.0


func _king_in_danger(c: Dictionary) -> bool:
	return float(c.king_calm) > 0.0 or float(c.king_hp) < KING_HP * 0.95


func _on_duty(u: U) -> bool:
	if u.team == Defs.NEUTRAL or u.team >= Defs.HOUSE_COUNT:
		return false
	for c: Dictionary in castles:
		if int(c.owner) == u.team and _king_in_danger(c) and (c.center as Vector3).distance_to(u.pos) < DUTY_R:
			return true
	return false


## Il re è stato colpito: chi della sua casata era a tavola o scappava lì vicino torna di corsa.
func _call_to_arms(c: Dictionary) -> void:
	var ce: Vector3 = c.center
	for u: U in ulist:
		if u.team == int(c.owner) and u.hp > 0.0 and (u.feast > 0.0 or u.flee > 0.0) and ce.distance_to(u.pos) < DUTY_R:
			u.feast = 0.0
			u.flee = 0.0


func _nearest_castle_of(team: int, p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e12
	for c: Dictionary in castles:
		if int(c.owner) == team and (c.center as Vector3).distance_squared_to(p) < bd:
			bd = (c.center as Vector3).distance_squared_to(p)
			best = c
	return best


## Chi si fa più vedere nella zona; se non c'è nessuno, il padrone del castello più vicino.
func _excom_target(team: int, p: Vector3) -> int:
	var per := {}
	for u: U in _zone_enemies(team, p):
		if u.team != Defs.NEUTRAL:
			per[u.team] = int(per.get(u.team, 0)) + 1
	var best := -1
	var bn := 0
	for t: int in per:
		if int(per[t]) > bn:
			bn = per[t]
			best = t
	if best >= 0:
		return best
	var bd := 1e12
	for c: Dictionary in castles:
		var o := int(c.owner)
		if o != team and o != Defs.NEUTRAL and not at_peace(team, o) and (c.center as Vector3).distance_squared_to(p) < bd:
			bd = (c.center as Vector3).distance_squared_to(p)
			best = o
	return best


func cmd_special(team: int, p: Vector3) -> bool:
	if team < 0 or team >= Defs.HOUSE_COUNT or equal_houses:
		return false
	var h: Dictionary = houses[team]
	var left := float(h.get("sp_t", 0.0)) - time
	if left > 0.0:
		game.msg_house(team, "Il potere torna fra %d secondi" % ceili(left), UiStyle.MUTED)
		return false
	var pw: Dictionary = Defs.HOUSE_POWERS[team]
	var home := _nearest_castle_of(team, p)
	if bool(pw.self):
		if home.is_empty():
			return false
		p = home.center
	elif team != 6 and time < truce_until and _truce_target(team, p):
		game.msg_house(team, "Tregua: niente scherzi alle altre casate. Usalo sui castelli liberi", UiStyle.DANGER_TEXT)
		return false
	var enemies := _zone_enemies(team, p)
	# i poteri che fermano, distraggono, spaventano o comprano non toccano chi difende il re in pericolo
	if team in Defs.DUTY_POWERS:
		var loyal := enemies.filter(func(u: U) -> bool: return _on_duty(u))
		if not loyal.is_empty():
			enemies = enemies.filter(func(u: U) -> bool: return not _on_duty(u))
			game.msg_house(team, "%d soldati difendono il loro re e non mollano il posto" % loyal.size(), UiStyle.MUTED)
			if rng.randf() < 0.5:
				_say(loyal[rng.randi() % loyal.size()], Defs.SAY_LEALE, true)
	match team:
		0:
			for u: U in enemies:
				_stop_unit(u)
				u.sleep = 12.0
				if rng.randf() < 0.3:
					_say(u, Defs.SAY_MODULO, true)
		1:
			for u: U in enemies:
				var ang := rng.randf() * TAU
				_stop_unit(u)
				u.feast = 12.0
				u.feast_pos = p + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(3.0, 8.0)
				_take_gold(u.team, team, 8.0)
		2:
			for u: U in enemies:
				_take_gold(u.team, team, 12.0)
		3:
			h.discount_until = time + DISCOUNT_T
			game.msg_house(team, "Saldi! Per %d secondi i soldati costano la metà" % int(DISCOUNT_T), UiStyle.GOLD)
		4:
			var room := unit_room(team)
			if room <= 0:
				game.msg_house(team, "Hai già il massimo di truppe: nessuno da comprare", UiStyle.MUTED)
				return false
			enemies.sort_custom(func(a: U, b: U) -> bool: return a.pos.distance_squared_to(p) < b.pos.distance_squared_to(p))
			for k in mini(mini(4, room), enemies.size()):
				_turn_coat(enemies[k], team)
		5:
			var victim := _excom_target(team, p)
			if victim < 0:
				game.msg_house(team, "Non c'è nessuno da scomunicare, per ora", UiStyle.MUTED)
				return false
			houses[victim].excom_until = time + 30.0
			for u: U in enemies:
				if u.team == victim:
					_stop_unit(u)
					u.sleep = 6.0
		6:
			for u: U in ulist:
				if u.team == team and u.hp > 0.0 and u.pos.distance_to(p) < SPECIAL_R:
					u.drunk = 14.0
					u.hp = minf(u.hp + 25.0, float(Defs.UNITS[u.type].hp))
		7:
			var room := unit_room(team)
			if room <= 0:
				game.msg_house(team, "Hai già il massimo di truppe: i cugini restano a casa", UiStyle.MUTED)
				return false
			var at: Vector3 = (home.gate_out as Vector3) + (home.dir as Vector3) * 12.0
			for k in mini(5, room):
				var q := at + Vector3(float(k) * 2.0 - 4.0, 0.0, 0.0)
				q.y = world.top_y(int(q.x), int(q.z))
				spawn_unit(Defs.FANTE, team, q)
		8:
			for u: U in enemies:
				var away := Vector3(u.pos.x - p.x, 0.0, u.pos.z - p.z)
				if away.length() < 0.5:
					away = Vector3(cos(float(u.id)), 0.0, sin(float(u.id)))
				_stop_unit(u)
				u.flee = 7.0
				u.flee_pos = u.pos + away.normalized() * 55.0
				_hurt(u, 6.0, SRC_POWER)
				if rng.randf() < 0.3:
					_say(u, Defs.SAY_PANICO, true)
	h.sp_t = time + SPECIAL_CD
	game.fx_all("special", p, float(team))
	if _concerns_humans(team, p):
		game.msg_all("%s, %s: %s" % [_hname(team), pw.name, pw.quip], Defs.HOUSES[team].color)
	return true


func _stop_unit(u: U) -> void:
	u.has_order = false
	u.goal = -1
	u.tgt = null


func _take_gold(from_t: int, to_t: int, amount: float) -> void:
	if from_t == Defs.NEUTRAL:
		houses[to_t].gold = float(houses[to_t].gold) + amount * 0.5  # i Comuni liberi pagano poco e male
		return
	var pay := minf(amount, float(houses[from_t].gold))
	houses[from_t].gold = float(houses[from_t].gold) - pay
	houses[to_t].gold = float(houses[to_t].gold) + pay


func _turn_coat(u: U, team: int) -> void:
	for o: U in ulist:
		if o.tgt == u:
			o.tgt = null
	_stop_unit(u)
	u.team = team
	u.inside_own = -1
	u.inside_enemy = -1
	u.feast = 0.0
	u.flee = 0.0
	u.sleep = 0.0


## Pannello debug: prova il potere di una casata, con i soldati che servono per vederlo.
func debug_special(house: int, p: Vector3) -> bool:
	truce_until = minf(truce_until, time)
	houses[house].sp_t = 0.0
	var other := (house + 1) % Defs.HOUSE_COUNT
	for k in 10:
		for t: int in [other, house]:
			if t == house and k > 3:
				continue
			var q := p + Vector3(float(k % 5) * 2.4 - 5.0, 0.0, float(k / 5) * 2.4 + (-6.0 if t == house else 2.0))
			q.y = world.top_y(int(q.x), int(q.z))
			spawn_unit(Defs.FANTE, t, q)
	return cmd_special(house, p)


# ---------------------------------------------------------------- la Gazzetta: si riparte quando tutti hanno letto
func cmd_news_read(team: int) -> void:
	if news_t <= 0.0 or team < 0 or team >= Defs.HOUSE_COUNT:
		return
	news_read[team] = true
	var total := 0
	var done := 0
	for t in Defs.HOUSE_COUNT:
		if not bool(houses[t].ai):
			total += 1
			if news_read.has(t):
				done += 1
	if done >= total:
		news_t = 0.0
	game.news_status_all(done, total)


func _hurt(u: U, dmg: float, src := SRC_POWER) -> void:
	if u.shield:
		dmg *= 0.3
	dmg /= _stat(u.team, Defs.STAT_FORZA)
	var was := u.hp
	u.hp -= dmg
	if was > 0.0 and u.hp <= 0.0:
		if rng.randf() < 0.06:
			_say(u, Defs.SAY_MORTE)
	elif not u.said_hurt and u.hp < float(Defs.UNITS[u.type].hp) * 0.35 and u.hp > 0.0:
		u.said_hurt = true
		if rng.randf() < 0.3:
			_say(u, Defs.SAY_NONNA if u.type == Defs.NONNA else Defs.SAY_FERITO)
	if not stats.is_empty() and was > 0.0:
		stats.damage[src] += minf(dmg, was)
		if u.hp <= 0.0:
			stats.kills[src] += 1
			stats.deaths[u.type] += 1


func _is_siege(u: U) -> bool:
	return u.type == Defs.CATAPULTA or u.type == Defs.BOMBARDA


func _tick_unit(u: U, dt: float) -> void:
	var d: Dictionary = Defs.UNITS[u.type]
	u.cd -= dt
	# lo sciopero non si rompe con un ordine: il frate invece si sveglia se lo chiami
	if u.sleep > 0.0 and (not u.has_order or u.type != Defs.FRATE):
		u.moving = false
		u.attacking = false
		if u.type != Defs.FRATE:
			u.sleep = maxf(u.sleep - dt, 0.0)
		_settle(u, dt)
		return
	if u.flee > 0.0:
		u.flee -= dt
		u.tgt = null
		u.attacking = false
		_move_to(u, u.flee_pos, dt, d, false)
		return
	if u.feast > 0.0:
		u.feast -= dt
		u.attacking = false
		u.tgt = null
		if u.feast <= 0.0:
			u.has_order = false
			u.goal = -1
			u.home = u.pos
		elif Vector2(u.feast_pos.x - u.pos.x, u.feast_pos.z - u.pos.z).length() > 2.0:
			_move_to(u, u.feast_pos, dt, d, false)
			return
		else:
			if palio_until > time and u.type == Defs.CAVALIERE and u.feast_pos == palio_pos:
				_palio_win(u)
			u.moving = false
			_settle(u, dt)
			return
	if u.fear > 0.0:
		u.fear -= dt
	if u.drunk > 0.0:
		u.drunk -= dt
	u.moving = false
	u.attacking = false
	var range_: float = d.range
	var aggro: float = d.aggro
	var ranged: bool = range_ > 10.0
	if ranged and u.pos.y > u.home.y + 4.0:
		range_ *= 1.35
		aggro *= 1.35

	u.retarget -= dt
	if u.retarget <= 0.0:
		u.retarget = 0.45 + rng.randf() * 0.25
		_retarget(u, aggro)

	if u.tgt != null and u.tgt.hp <= 0.0:
		u.tgt = null

	# --- bersagli a distanza e assedio
	if ranged:
		var aim_ok := false
		var aim := Vector3.ZERO
		if u.vox_t:
			var vp := Vector3i(u.vox_pos)
			var guard := 0
			while world.get_v(vp.x, vp.y, vp.z) < Defs.STRUCT_MIN and guard < 14:
				vp.y -= 1
				guard += 1
			if world.get_v(vp.x, vp.y, vp.z) >= Defs.STRUCT_MIN:
				aim = Vector3(vp) + Vector3(0.5, 0.5, 0.5)
				u.vox_pos = aim
				aim_ok = true
			else:
				u.vox_t = false
				u.has_order = false
		elif _is_siege(u):
			if u.tgt != null:
				aim = u.tgt.pos + Vector3(0, 1, 0)
				aim_ok = true
			elif u.auto_castle >= 0:
				var picked := _pick_castle_voxel(castles[u.auto_castle], u.pos)
				if picked.y > 0.0:
					aim = picked
					aim_ok = true
		elif u.tgt != null:
			aim = u.tgt.pos + Vector3(0, 1, 0)
			aim_ok = true
		if aim_ok and u.pos.distance_to(aim) <= range_:
			u.yaw = atan2(aim.x - u.pos.x, aim.z - u.pos.z)
			u.attacking = true
			if u.cd <= 0.0:
				u.cd = float(d.cd) * (0.7 if u.drunk > 0.0 else 1.0) * (FEAR_CD if u.fear > 0.0 else 1.0)
				_ranged_attack(u, aim, d)
			_settle(u, dt)
			return
		if u.garrison:
			_settle(u, dt)
			return
	else:
		# --- mischia
		if u.tgt != null:
			var dist := u.pos.distance_to(u.tgt.pos)
			if dist <= range_ + 0.4:
				u.yaw = atan2(u.tgt.pos.x - u.pos.x, u.tgt.pos.z - u.pos.z)
				u.attacking = true
				if u.cd <= 0.0:
					u.cd = float(d.cd) * (0.7 if u.drunk > 0.0 else 1.0) * (FEAR_CD if u.fear > 0.0 else 1.0)
					var dmg: float = float(d.dmg) * (1.5 if u.drunk > 0.0 else 1.0) * (Defs.BARD_FACTOR if u.sung else 1.0) * (FEAR_DMG if u.fear > 0.0 else 1.0) * _stat(u.team, Defs.STAT_FORZA)
					if u.type == Defs.FANTE and u.tgt.type == Defs.CAVALIERE:
						dmg *= Defs.PIKE_VS_HORSE
					_hurt(u.tgt, dmg, u.type)
				_settle(u, dt)
				return
			if u.team != Defs.NEUTRAL or u.pos.distance_to(u.home) < 30.0:
				_move_to(u, u.tgt.pos, dt, d, false)
				return

	# --- abbattere un edificio nemico (anche da soli, se è a portata e non c'è altro da fare)
	if u.btgt >= 0 and u.tgt == null and not _is_siege(u):
		var bd: Dictionary = bldg_by_id.get(u.btgt, {})
		if bd.is_empty() or int(bd.owner) == u.team:
			u.btgt = -1
		else:
			var aim := _building_aim(bd, u.pos)
			var bdist := Vector2(aim.x - u.pos.x, aim.z - u.pos.z).length()
			if bdist <= range_ + 1.2:
				u.has_order = false
				u.yaw = atan2(aim.x - u.pos.x, aim.z - u.pos.z)
				u.attacking = true
				if u.cd <= 0.0:
					u.cd = float(d.cd) * (0.7 if u.drunk > 0.0 else 1.0) * (FEAR_CD if u.fear > 0.0 else 1.0)
					if ranged:
						_arrow(u.pos + Vector3(0, 1.4, 0), aim + Vector3(0, 1.0, 0))
					_hit_building(bd, u, 1 if ranged else (5 if u.type == Defs.NONNA else (1 if u.type == Defs.CAVALIERE else 3)))
				_settle(u, dt)
				return
			_move_to(u, aim, dt, d, false)
			return

	# --- nel cortile nemico, senza nemici da combattere: dritti dal re
	if u.inside_enemy >= 0 and u.tgt == null and not _is_siege(u) and (not u.has_order or u.goal == u.inside_enemy):
		var kc: Dictionary = castles[u.inside_enemy]
		if int(kc.owner) != u.team:
			var kp: Vector3 = kc.king
			var kd := Vector2(kp.x - u.pos.x, kp.z - u.pos.z).length()
			var reach := range_ + 0.9 if not ranged else range_
			# i balestrieri tirano dalla porta del mastio: da fuori non lo vedono
			if kd <= reach and (not ranged or Vector2(kp.x - u.pos.x, kp.z - u.pos.z).normalized().dot(-Vector2((kc.dir as Vector3).x, (kc.dir as Vector3).z)) > 0.6 or kd < 3.0):
				u.has_order = false
				u.goal = -1
				u.yaw = atan2(kp.x - u.pos.x, kp.z - u.pos.z)
				u.attacking = true
				if u.cd <= 0.0:
					u.cd = float(d.cd) * (0.7 if u.drunk > 0.0 else 1.0) * (FEAR_CD if u.fear > 0.0 else 1.0)
					var kdmg: float = float(d.dmg) * (1.5 if u.drunk > 0.0 else 1.0) * (Defs.BARD_FACTOR if u.sung else 1.0) * (FEAR_DMG if u.fear > 0.0 else 1.0) * _stat(u.team, Defs.STAT_FORZA)
					if u.type == Defs.CAVALIERE:
						kdmg *= Defs.HORSE_VS_KING
					if ranged:
						_arrow(u.pos + Vector3(0, 1.4, 0), kp + Vector3(0, 1.0, 0))
					_hurt_king(kc, kdmg, u.team)
				_settle(u, dt)
				return
			var stand: Vector3 = kp if not ranged else kc.king_door
			_move_to(u, stand, dt, d, false)
			return

	# il frate che va in chiesa si ferma appena è abbastanza vicino per pregare
	if u.type == Defs.FRATE and u.has_order and u.goal < 0 and _near_own_church(u, PRAY_R * 0.6):
		u.has_order = false
		u.home = u.pos

	# --- ordine di movimento
	if u.has_order:
		var to := u.target - u.pos
		to.y = 0.0
		if to.length() < 1.2 and u.goal < 0:
			u.has_order = false
			u.home = u.pos
			if u.to_flag:
				u.to_flag = false
				if rng.randf() < 0.3:
					_say(u, Defs.SAY_RADUNO)
		elif u.goal >= 0 and (u.pos.distance_to(u.target) < 2.5 or _in_courtyard_of(u, castles[u.goal])):
			u.has_order = false
			u.home = u.pos
			u.goal = -1
		else:
			_move_to(u, u.target, dt, d, true)
			return
	elif u.team == Defs.NEUTRAL and u.pos.distance_to(u.home) > 4.0:
		_move_to(u, u.home, dt, d, false)
		return
	_settle(u, dt)


func _retarget(u: U, aggro: float) -> void:
	u.shield = false
	u.sung = false
	for b: U in bards:
		if b.team != u.team and b.hp > 0.0 and b.pos.distance_squared_to(u.pos) < Defs.BARD_RADIUS * Defs.BARD_RADIUS:
			u.sung = true
			break
	for dm: Dictionary in domes:
		if dm.team == u.team and (dm.pos as Vector3).distance_to(u.pos) < float(dm.r):
			u.shield = true
	# accesso alle porte amiche e castello in cui si trova
	u.pass_gate = false
	u.inside_own = -1
	u.inside_enemy = -1
	u.auto_castle = -1
	var bd := 1e9
	var d: Dictionary = Defs.UNITS[u.type]
	for c: Dictionary in castles:
		var ce: Vector3 = c.center
		var dist := Vector2(ce.x - u.pos.x, ce.z - u.pos.z).length()
		if c.owner == u.team:
			if dist < R + 12.0:
				u.pass_gate = true
			if absf(ce.x - u.pos.x) < R - WALL_T and absf(ce.z - u.pos.z) < R - WALL_T:
				u.inside_own = c.id
		elif dist < float(d.range) + R and dist < bd and not at_peace(u.team, int(c.owner)):
			if absf(ce.x - u.pos.x) < R - WALL_T + 0.5 and absf(ce.z - u.pos.z) < R - WALL_T + 0.5 and u.team != Defs.NEUTRAL:
				u.inside_enemy = c.id
			bd = dist
			u.auto_castle = c.id
	if u.btgt < 0 and not u.has_order and u.type != Defs.FRATE and u.team != Defs.NEUTRAL and not _is_siege(u) and u.type != Defs.ARIETE:
		var nb := _enemy_building_near(u, aggro + 6.0)
		if nb >= 0:
			u.btgt = nb
	if u.type == Defs.FRATE and not u.has_order and u.sleep <= 0.0:
		_friar_to_church(u)
	if u.type == Defs.ARIETE:
		u.tgt = null
	elif _is_siege(u):
		u.tgt = _find_enemy(u, 30.0, false) if not u.vox_t else null
	else:
		var had := u.tgt
		u.tgt = _find_enemy(u, aggro, float(d.range) < 10.0)
		if had == null and u.tgt != null and u.team != Defs.NEUTRAL and rng.randf() < 0.035:
			_say_charge(u)


func _pick_castle_voxel(c: Dictionary, from: Vector3) -> Vector3:
	var bp: PackedInt64Array = c.blueprint
	var best := Vector3(0, -1, 0)
	var bd := 1e12
	for t in 10:
		var e: int = bp[rng.randi() % bp.size()]
		var p := world.pos_of(e >> Defs.EDIT_SHIFT)
		if world.get_v(p.x, p.y, p.z) == 0:
			continue
		var v := Vector3(p) + Vector3(0.5, 0.5, 0.5)
		var dd := v.distance_squared_to(from)
		if dd < bd:
			bd = dd
			best = v
	return best


func _ranged_attack(u: U, aim: Vector3, d: Dictionary) -> void:
	if u.type == Defs.BALESTRIERE:
		var from := u.pos + Vector3(0, 1.6, 0)
		_arrow(from, aim)
		if u.tgt != null:
			_hurt(u.tgt, float(d.dmg) * (1.5 if u.drunk > 0.0 else 1.0) * (Defs.BARD_FACTOR if u.sung else 1.0) * (FEAR_DMG if u.fear > 0.0 else 1.0) * _stat(u.team, Defs.STAT_FORZA)
				* (Defs.BOLT_VS_HORSE if u.tgt.type == Defs.CAVALIERE else 1.0), u.type)
	elif u.type == Defs.CATAPULTA:
		var spread := Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-0.6, 0.6), rng.randf_range(-1.2, 1.2))
		_fire_arc(u.pos + Vector3(0, 3.6, 0), aim + spread, Defs.SHOT_STONE, u.team, float(d.dmg) * _stat(u.team, Defs.STAT_FORZA), u.type)
		game.fx_all("whoosh", u.pos, 1.0)
	elif u.type == Defs.BOMBARDA:
		var from := u.pos + Vector3(0, 1.4, 0)
		var dist := from.distance_to(aim)
		var t := maxf(dist / 70.0, 0.25)
		var vel := (aim - from) / t + Vector3(0, 0.5 * GRAVITY * t, 0)
		_spawn_projectile(from, vel, Defs.SHOT_BALL, u.team, float(d.dmg) * _stat(u.team, Defs.STAT_FORZA), u.type)
		game.fx_all("cannon", from, 1.0)


func _arrow(from: Vector3, to: Vector3) -> void:
	if arrow_fx.size() < 240:
		arrow_fx.append_array(PackedFloat32Array([from.x, from.y, from.z, to.x, to.y, to.z]))


func _fire_arc(from: Vector3, to: Vector3, kind: int, team: int, dmg: float, src := SRC_CASTLE) -> void:
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var t := clampf(dist / 26.0, 1.0, 3.2)
	var vel := Vector3((to.x - from.x) / t, (to.y - from.y + 0.5 * GRAVITY * t * t) / t, (to.z - from.z) / t)
	_spawn_projectile(from, vel, kind, team, dmg, src)


func _spawn_projectile(from: Vector3, vel: Vector3, kind: int, team: int, dmg: float, src := SRC_POWER) -> void:
	var id := next_proj
	next_proj += 1
	projectiles[id] = {"pos": from, "vel": vel, "kind": kind, "team": team, "dmg": dmg, "life": 12.0, "pierce": 1 if kind == Defs.SHOT_BALL else 0, "src": src}
	game.proj_all(id, kind, from, vel)


# ---------------------------------------------------------------- movimento
func _settle(u: U, dt: float) -> void:
	var ny := world.walk_y(u.pos.x, u.pos.y, u.pos.z, true)
	if ny < -999.0:
		u.pos.y += 1.0  # sepolto da una riparazione: risale
		return
	_apply_fall(u, ny, dt)


func _apply_fall(u: U, ny: float, dt: float) -> void:
	u.water = ny <= Defs.SEA + 0.5
	if u.pos.y > ny + 0.05:
		if u.fall_from < 0.0:
			u.fall_from = u.pos.y
		u.pos.y = maxf(u.pos.y - 22.0 * dt, ny)
		if u.pos.y <= ny:
			var drop := u.fall_from - ny
			if drop > 4.0:
				if not u.water and time >= u.descend:
					_hurt(u, drop * 3.0)
				u.descend = 0.0  # arrivato giù: da qui in poi le cadute fanno di nuovo male
			u.fall_from = -1.0
			if u.garrison:
				u.garrison = false
	else:
		u.fall_from = -1.0
		u.pos.y = move_toward(u.pos.y, ny, 14.0 * dt)


func _dir_from_field(u: U, c: Dictionary) -> Vector3:
	if c.field_dirty and time - float(c.field_t) > 1.5:
		if (c.field as PackedInt32Array).is_empty():
			_compute_field(c)
		else:
			_queue_field(c)
	var f: PackedInt32Array = c.field
	if f.is_empty():
		return Vector3.ZERO
	var ce: Vector3 = c.center
	# stesse caselle di _compute_field (origine int(ce) - FIELD_R): con int(pos - ce) il centro a
	# x,5 spostava la lettura di una casella e chi stava attaccato alle mura leggeva il muro (-1)
	var fx := int(floor(u.pos.x)) - (int(ce.x) - FIELD_R)
	var fz := int(floor(u.pos.z)) - (int(ce.z) - FIELD_R)
	if fx < 1 or fz < 1 or fx >= FIELD_D - 1 or fz >= FIELD_D - 1:
		return Vector3.ZERO
	var cur: int = f[fx + fz * FIELD_D]
	# su una casella irraggiungibile (bordo di un muro, macerie) va verso la vicina migliore
	var best := cur if cur >= 0 else 1 << 30
	var bdir := Vector3.ZERO
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var v: int = f[fx + dx + (fz + dz) * FIELD_D]
			if v >= 0 and v < best:
				best = v
				bdir = Vector3(dx, 0, dz)
	return bdir.normalized()


## BFS dal punto di conquista: tiene conto delle brecce aperte nelle mura.
## Il primo campo di un castello si calcola subito; i ricalcoli (mura che cadono) vanno a
## fette di FIELD_STEP caselle per tick in _advance_fields, e intanto vale il campo vecchio:
## un campo intero costa ~25 ms e in un tick solo faceva scattare la partita durante gli assedi.
func _compute_field(c: Dictionary) -> void:
	var job := _field_begin(c)
	_field_run(job, 1 << 30)


func _field_begin(c: Dictionary) -> Dictionary:
	c.field_dirty = false
	c.field_t = time
	var f := PackedInt32Array()
	f.resize(FIELD_D * FIELD_D)
	f.fill(-1)
	var ys := PackedFloat32Array()
	ys.resize(FIELD_D * FIELD_D)
	var ce: Vector3 = c.center
	var cap: Vector3 = c.rally
	var sx := int(floor(cap.x)) - (int(ce.x) - FIELD_R)
	var sz := int(floor(cap.z)) - (int(ce.z) - FIELD_R)
	var start := sx + sz * FIELD_D
	f[start] = 0
	ys[start] = cap.y
	return {"c": c, "f": f, "ys": ys, "q": PackedInt32Array([start]), "head": 0, "ox": int(ce.x) - FIELD_R, "oz": int(ce.z) - FIELD_R}


## Avanza la BFS di al più budget caselle; a BFS finita il campo passa al castello.
func _field_run(job: Dictionary, budget: int) -> bool:
	var f: PackedInt32Array = job.f
	var ys: PackedFloat32Array = job.ys
	var q: PackedInt32Array = job.q
	var head: int = job.head
	var ox: int = job.ox
	var oz: int = job.oz
	var w := world
	var stop := head + budget
	while head < q.size() and head < stop:
		var cur: int = q[head]
		head += 1
		var cx := cur % FIELD_D
		var cz := cur / FIELD_D
		var cy: float = ys[cur]
		var cd: int = f[cur] + 1
		# vicini nell'ordine +x, -x, +z, -z: l'ordine decide da quale casella si eredita la quota
		for n in 4:
			var nx := cx + (1 if n == 0 else -1 if n == 1 else 0)
			var nz := cz + (1 if n == 2 else -1 if n == 3 else 0)
			if nx < 0 or nz < 0 or nx >= FIELD_D or nz >= FIELD_D:
				continue
			var k := nx + nz * FIELD_D
			if f[k] >= 0:
				continue
			var ny := w.walk_y(ox + nx + 0.5, cy, oz + nz + 0.5, true)
			if ny < -999.0:
				continue
			if cy - ny > 1.6:
				continue  # nella direzione inversa sarebbe un dislivello in salita
			f[k] = cd
			ys[k] = ny
			q.append(k)
	job.head = head
	job.q = q
	if head < q.size():
		return false
	(job.c as Dictionary).field = f
	return true


const FIELD_STEP := 2500
var _field_jobs: Array[Dictionary] = []


func _advance_fields() -> void:
	var budget := FIELD_STEP
	while budget > 0 and not _field_jobs.is_empty():
		var job: Dictionary = _field_jobs[0]
		var before: int = job.head
		if _field_run(job, budget):
			_field_jobs.remove_at(0)
		budget -= int(job.head) - before


## Un ricalcolo già in corso non riparte da capo (con molti assedi insieme non finirebbe mai):
## il castello resta da rifare e il giro dopo prende le mura cadute nel frattempo.
func _queue_field(c: Dictionary) -> void:
	for job: Dictionary in _field_jobs:
		if is_same(job.c, c):
			return
	_field_jobs.append(_field_begin(c))


func _move_to(u: U, dest: Vector3, dt: float, d: Dictionary, can_chop: bool) -> void:
	var to := dest - u.pos
	to.y = 0.0
	var want := to.normalized() if to.length() > 0.01 else Vector3.ZERO
	u.replan_cd -= dt
	u.prog_t += dt
	if u.prog_t > 3.0:
		var moved := Vector2(u.pos.x - u.prog_pos.x, u.pos.z - u.prog_pos.z).length()
		u.prog_t = 0.0
		u.prog_pos = u.pos
		if moved < 2.0 and u.replan_cd <= 0.0 and u.path.is_empty():
			u.replan_cd = 2.5
			_plan_local(u, dest)
	if not u.path.is_empty() and Vector2(dest.x - u.path_dest.x, dest.z - u.path_dest.z).length() > 6.0:
		u.path.clear()  # la destinazione è cambiata: il vecchio percorso non serve più
	if not u.path.is_empty():
		var wp: Vector3 = u.path[u.path_i]
		if Vector2(wp.x - u.pos.x, wp.z - u.pos.z).length() < 1.2:
			u.path_i += 1
			if u.path_i >= u.path.size():
				u.path.clear()
	var on_path := not u.path.is_empty()
	if on_path:
		var wp2: Vector3 = u.path[u.path_i]
		want = Vector3(wp2.x - u.pos.x, 0.0, wp2.z - u.pos.z).normalized()
	# uscita dal proprio castello: passa dalla porta. L'uscita resta "agganciata" finché la porta
	# non è superata: prima, appena l'unità lasciava il quadrato del cortile, tornava a puntare
	# dritta al bersaglio, sbatteva contro le mura, rientrava e oscillava lì per sempre.
	if on_path:
		pass
	elif u.inside_own >= 0 and u.exiting < 0:
		var c0: Dictionary = castles[u.inside_own]
		var ce0: Vector3 = c0.center
		if absf(dest.x - ce0.x) > R or absf(dest.z - ce0.z) > R:
			u.exiting = u.inside_own
	if u.exiting >= 0 and not on_path:
		var w := _exit_waypoint(u, castles[u.exiting], dest)
		if w.y < -999.0:
			u.exiting = -1
		else:
			want = (w - u.pos)
			want.y = 0.0
			want = want.normalized()
	var steered := on_path
	if u.exiting < 0 and u.goal >= 0 and not on_path:
		var c: Dictionary = castles[u.goal]
		var ce: Vector3 = c.center
		if absf(u.pos.x - ce.x) < FIELD_R - 2 and absf(u.pos.z - ce.z) < FIELD_R - 2:
			var fd := _dir_from_field(u, c)
			if fd != Vector3.ZERO:
				want = fd
				steered = true
	if u.exiting < 0 and not steered:
		var detour := _around_castles(u, dest)
		if detour.y > -999.0:
			want = detour - u.pos
			want.y = 0.0
			want = want.normalized()

	# separazione dagli alleati
	var sep := Vector3.ZERO
	var a: Variant = grid.get(int(u.pos.x) / CELL + int(u.pos.z) / CELL * 1000)
	if a != null:
		var count := 0
		for o: U in a:
			if o == u:
				continue
			# chi ha una meta passa in mezzo ai compagni fermi: prima la folla in attesa nel cortile
			# respingeva nel tunnel della porta chi rientrava, che oscillava lì per sempre
			if u.has_order and not o.moving and o.team == u.team:
				continue
			var dx := u.pos.x - o.pos.x
			var dz := u.pos.z - o.pos.z
			var q := dx * dx + dz * dz
			if q < 2.6 and q > 0.0001:
				sep += Vector3(dx, 0, dz) / q
				count += 1
				if count > 6:
					break
	var dir := (want + sep * 0.35)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var speed: float = float(d.speed) * (1.6 if u.drunk > 0.0 else 1.0) * _stat(u.team, Defs.STAT_VELOCITA)
	if u.water:
		speed *= 0.85
	if u.drunk > 0.0:
		dir = dir.rotated(Vector3.UP, sin(time * 3.0 + u.id) * 0.5)
	var step := speed * dt
	for ang: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
		var tryd := dir if ang == 0.0 else dir.rotated(Vector3.UP, ang)
		var nx := u.pos.x + tryd.x * step
		var nz := u.pos.z + tryd.z * step
		var ny := world.walk_y(nx, u.pos.y, nz, u.pass_gate)
		if ny > -999.0:
			var probe := world.walk_y(nx + tryd.x * 0.5, u.pos.y, nz + tryd.z * 0.5, u.pass_gate)
			if probe < -999.0 and ang != 1.4 and ang != -1.4:
				continue
			u.pos.x = nx
			u.pos.z = nz
			_apply_fall(u, ny, dt)
			u.moving = true
			u.yaw = lerp_angle(u.yaw, atan2(tryd.x, tryd.z), 0.35)
			if ang == 0.0:
				u.stuck = maxf(u.stuck - dt, 0.0)
			else:
				u.stuck += dt * 0.35
			return
	u.stuck += dt
	u.yaw = atan2(want.x, want.z)
	if u.stuck > 0.5 and _climb_terrain(u, want):
		return
	# bloccata: prima cerca una strada vera attorno all'ostacolo, solo dopo picchia o rinuncia
	if u.stuck > 0.6 and u.replan_cd <= 0.0:
		u.replan_cd = 2.5
		if _plan_local(u, dest):
			u.stuck = 0.0
			return
	if can_chop and u.stuck > 0.5:
		_chop(u, want, d)
	elif u.stuck > 3.0:
		u.has_order = false


## Arrivata nel cortile del castello obiettivo, vicino al punto di conquista: basta così.
## Prima doveva arrivare a 2,5 m dal punto preciso, e in venti si spingevano lì attorno per sempre.
func _in_courtyard_of(u: U, c: Dictionary) -> bool:
	var ce: Vector3 = c.center
	if absf(u.pos.x - ce.x) > R - WALL_T - 0.5 or absf(u.pos.z - ce.z) > R - WALL_T - 0.5:
		return false
	return Vector2(u.pos.x - (c.rally as Vector3).x, u.pos.z - (c.rally as Vector3).z).length() < 8.0 * CS


## Se la linea dritta verso la destinazione taglia un castello (proprio o di altri, escluso
## quello in cui deve entrare), restituisce l'angolo da cui aggirarlo; altrimenti y < -999.
## Senza, chi usciva dalla porta verso un bersaglio dietro il castello si incollava alle mura.
## Quadrato del castello per l'aggiramento: il filo delle mura. Chi cammina nell'anello davanti alle
## mura è fuori, e viene guidato agli angoli (abbastanza larghi da girare attorno alle torri).
const DETOUR_HALF := R + 2.0
const DETOUR_CORNER := R + 11.0
func _around_castles(u: U, dest: Vector3) -> Vector3:
	var none := Vector3(0, -1e6, 0)
	var best_c: Dictionary = {}
	var best_d := 1e9
	for c: Dictionary in castles:
		var ce: Vector3 = c.center
		var dd := Vector2(ce.x - u.pos.x, ce.z - u.pos.z).length()
		if dd > 70.0 or dd >= best_d:
			continue
		if c.id == u.goal:
			continue
		if absf(dest.x - ce.x) < DETOUR_HALF and absf(dest.z - ce.z) < DETOUR_HALF:
			continue  # la destinazione è dentro: ci pensa la porta
		if absf(u.pos.x - ce.x) < DETOUR_HALF - 0.5 and absf(u.pos.z - ce.z) < DETOUR_HALF - 0.5:
			continue  # è già dentro o sulle mura
		if _segment_hits_square(u.pos, dest, ce, DETOUR_HALF):
			best_d = dd
			best_c = c
	if best_c.is_empty():
		return none
	var ce: Vector3 = best_c.center
	var pick := none
	var plen := 1e9
	for k in 4:
		var corner := ce + Vector3(DETOUR_CORNER if k & 1 else -DETOUR_CORNER, 0.0, DETOUR_CORNER if k & 2 else -DETOUR_CORNER)
		var to_c := Vector2(corner.x - u.pos.x, corner.z - u.pos.z).length()
		# l'angolo su cui si trova già non serve: dall'angolo opposto al bersaglio va preso il successivo
		if to_c < 2.0 or _segment_hits_square(u.pos, corner, ce, DETOUR_HALF):
			continue
		var l := to_c + Vector2(dest.x - corner.x, dest.z - corner.z).length()
		if _segment_hits_square(corner, dest, ce, DETOUR_HALF):
			l += DETOUR_CORNER * 2.0  # da lì servirà un altro angolo
		if l < plen:
			plen = l
			pick = corner
	return pick


## Il segmento a-b (in pianta) attraversa il quadrato centrato in c con semilato h?
func _segment_hits_square(a: Vector3, b: Vector3, c: Vector3, h: float) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := Vector2(b.x - a.x, b.z - a.z)
	var p := Vector2(a.x - c.x, a.z - c.z)
	for axis in 2:
		var pa: float = p[axis]
		var da: float = d[axis]
		if absf(da) < 1e-6:
			if absf(pa) > h:
				return false
			continue
		var ta := (-h - pa) / da
		var tb := (h - pa) / da
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


## Ricerca in ampiezza sulle caselle percorribili attorno all'unità (raggio PLAN_R): sceglie
## la casella raggiungibile più vicina alla destinazione e ne ricava i punti da seguire.
## false se nessuna casella è sensibilmente più vicina di dove si trova già.
const PLAN_R := 40
const PLAN_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Al più PLAN_PER_TICK ricerche per tick: ognuna costa ~10 ms e un gruppo fermo contro un muro
## le faceva partire tutte nello stesso tick (scatti da 40 ms e oltre). Chi resta senza turno
## si comporta come se la ricerca fosse fallita e riprova al tick dopo.
const PLAN_PER_TICK := 1
var _plans_left := PLAN_PER_TICK


func _plan_local(u: U, dest: Vector3) -> bool:
	if _plans_left <= 0:
		u.replan_cd = 0.0
		return false
	_plans_left -= 1
	var D := PLAN_R * 2 + 1
	var ox := int(floor(u.pos.x)) - PLAN_R
	var oz := int(floor(u.pos.z)) - PLAN_R
	var prev := PackedInt32Array()
	prev.resize(D * D)
	prev.fill(-2)
	var ys := PackedFloat32Array()
	ys.resize(D * D)
	var start := PLAN_R + PLAN_R * D
	prev[start] = -1
	ys[start] = u.pos.y
	var q := PackedInt32Array([start])
	var head := 0
	var best := start
	var best_d := Vector2(dest.x - u.pos.x, dest.z - u.pos.z).length()
	var start_d := best_d
	while head < q.size():
		var cur: int = q[head]
		head += 1
		var cx := cur % D
		var cz := cur / D
		# anche in diagonale: il movimento è continuo e le unità passano (e restano chiuse) tra due spigoli
		for n: Vector2i in PLAN_DIRS:
			var nx := cx + n.x
			var nz := cz + n.y
			if nx < 0 or nz < 0 or nx >= D or nz >= D:
				continue
			var k := nx + nz * D
			if prev[k] != -2:
				continue
			var ny := world.walk_y(ox + nx + 0.5, ys[cur], oz + nz + 0.5, u.pass_gate)
			if ny < -999.0 or ys[cur] - ny > 4.0:
				continue
			prev[k] = cur
			ys[k] = ny
			q.append(k)
			var dd := Vector2(dest.x - (ox + nx + 0.5), dest.z - (oz + nz + 0.5)).length()
			if dd < best_d:
				best_d = dd
				best = k
	if best == start or best_d > start_d - 3.0:
		return false
	var cells := PackedInt32Array()
	var c := best
	while c >= 0:
		cells.append(c)
		c = prev[c]
	cells.reverse()
	var pts := PackedVector3Array()
	for i in range(3, cells.size(), 3):
		var k: int = cells[i]
		pts.append(Vector3(ox + k % D + 0.5, ys[k], oz + k / D + 0.5))
	var last: int = cells[cells.size() - 1]
	pts.append(Vector3(ox + last % D + 0.5, ys[last], oz + last / D + 0.5))
	u.path = pts
	u.path_i = 0
	u.path_dest = dest
	return true


## Prossimo punto per uscire da un castello proprio: davanti alla porta da dentro, poi fuori.
## y < -999 quando l'unità è ormai fuori (o il castello non è più suo) e può puntare al bersaglio.
func _exit_waypoint(u: U, c: Dictionary, dest: Vector3) -> Vector3:
	var ce: Vector3 = c.center
	if c.owner != u.team or (absf(dest.x - ce.x) <= R and absf(dest.z - ce.z) <= R):
		return Vector3(0, -1e6, 0)
	var gdir: Vector3 = c.dir
	var rel := Vector3(u.pos.x - ce.x, 0.0, u.pos.z - ce.z)
	var depth := rel.dot(gdir)  # quanto è avanti verso la porta
	var lateral := absf(rel.dot(Vector3(-gdir.z, 0.0, gdir.x)))
	# finisce oltre la zona in cui l'aggiramento dei castelli non interviene (DETOUR_HALF - 0.5)
	var done := DETOUR_HALF + 0.5
	var outside: bool = absf(rel.x) > done or absf(rel.z) > done
	if outside or depth > done:
		return Vector3(0, -1e6, 0)
	if depth < R - WALL_T - 2.0 and lateral > 3.0:
		return c.gate_in
	return c.gate_out


## Bloccata da un dislivello di terreno (cratere, pendio ripido): si arrampica.
func _climb_terrain(u: U, dir: Vector3) -> bool:
	var x := int(u.pos.x + dir.x * 1.2)
	var z := int(u.pos.z + dir.z * 1.2)
	for dy in range(0, 3):
		var m := world.get_v(x, int(u.pos.y) + dy, z)
		if m >= Defs.STRUCT_MIN:
			return false
		if m != 0:
			u.pos.y += 1.2
			u.stuck = 0.0
			u.moving = true
			return true
	return false


## L'unità è ferma contro una struttura: la demolisce a colpi.
func _chop(u: U, dir: Vector3, d: Dictionary) -> void:
	u.attacking = true
	if u.cd > 0.0:
		return
	u.cd = float(d.cd)
	var fx := u.pos.x + dir.x * 1.2
	var fz := u.pos.z + dir.z * 1.2
	if u.type == Defs.ARIETE:
		var p := Vector3(fx + dir.x, u.pos.y + 1.5, fz + dir.z)
		blast(p, 2.6, 1.3, u.team, 0.0, "ram")
		return
	var ids := PackedInt32Array()
	for dy in range(0, 3):
		var x := int(fx)
		var y := int(u.pos.y) + dy
		var z := int(fz)
		var m := world.get_v(x, y, z)
		if m >= Defs.STRUCT_MIN:
			if not ids.is_empty() and rng.randf() > 0.5:
				continue
			# le porte cedono subito, la pietra molto più lentamente
			var chance := 1.0 if m == Defs.GATE else 0.32
			if rng.randf() < chance:
				ids.append(world.index(x, y, z))
	if not ids.is_empty():
		_remove_voxels(ids)
		game.fx_all("hit", Vector3(fx, u.pos.y + 1.0, fz), 1.0)
	elif u.stuck > 4.0:
		u.has_order = false


func _remove_voxels(ids: PackedInt32Array) -> void:
	var edits := PackedInt64Array()
	edits.resize(ids.size())
	for k in ids.size():
		edits[k] = ids[k] << Defs.EDIT_SHIFT
	game.push_edits(edits)
	_mark_fields(world.pos_of(ids[0]))
	_collapse_check(ids)


func _mark_fields(p: Vector3) -> void:
	for c: Dictionary in castles:
		if (c.center as Vector3).distance_to(p) < 48.0 + R * 2:
			c.field_dirty = true


# ---------------------------------------------------------------- esplosioni e crolli
## Cratere con risoluzione autoritativa: scava, ferisce e fa crollare ciò che resta sospeso.
func blast(p: Vector3, radius: float, power: float, team: int, dmg: float, fx := "boom", src := SRC_POWER) -> void:
	var ir := int(ceil(radius))
	var cx := int(floor(p.x))
	var cy := int(floor(p.y))
	var cz := int(floor(p.z))
	var r2 := radius * radius
	var removed := PackedInt32Array()
	for y in range(maxi(cy - ir, 3), mini(cy + ir + 1, Defs.WY)):
		for z in range(cz - ir, cz + ir + 1):
			for x in range(cx - ir, cx + ir + 1):
				var dx := x + 0.5 - p.x
				var dy := y + 0.5 - p.y
				var dz := z + 0.5 - p.z
				var q := dx * dx + dy * dy + dz * dz
				if q > r2:
					continue
				var m := world.get_v(x, y, z)
				if m == 0:
					continue
				# i crateri non scendono mai sotto il mare: i cortili non si allagano
				if m < Defs.STRUCT_MIN and y <= Defs.SEA + 1:
					continue
				var strength := power * (1.0 - sqrt(q) / radius) / Defs.hardness(m)
				if strength > 0.32 or rng.randf() < strength * 3.0:
					removed.append(world.index(x, y, z))
	if not removed.is_empty():
		var edits := PackedInt64Array()
		edits.resize(removed.size())
		for k in removed.size():
			edits[k] = removed[k] << Defs.EDIT_SHIFT
		game.push_edits(edits)
		_collapse_check(removed)
	if fx != "":
		game.fx_all(fx, p, radius)
	_mark_fields(p)
	if dmg > 0.0:
		_splash(p, radius * 1.3, dmg, team, src)


func _splash(p: Vector3, radius: float, dmg: float, team: int, src := SRC_POWER) -> void:
	for u in ulist:
		if u.team != team and not at_peace(team, u.team) and u.pos.distance_to(p) < radius:
			var f := 1.0 - u.pos.distance_to(p) / radius * 0.6
			_hurt(u, dmg * f, src)


func _collapse_check(removed: PackedInt32Array) -> void:
	var seeds := PackedInt32Array()
	var offs := [1, -1, Defs.WX, -Defs.WX, VoxelWorld.LAYER_DY, -VoxelWorld.LAYER_DY]
	var seen := {}
	for r in removed:
		for o: int in offs:
			var j: int = r + o
			if j >= 0 and j < world.vox.size() and world.vox[j] >= Defs.STRUCT_MIN and not seen.has(j):
				seen[j] = true
				seeds.append(j)
	var comps := world.find_unsupported(seeds)
	for comp: PackedInt32Array in comps:
		_detach(comp)


## Il gruppo staccato diventa un vero corpo rigido che cade e si frantuma.
func _detach(comp: PackedInt32Array) -> void:
	var data := PackedInt64Array()
	data.resize(comp.size())
	var edits := PackedInt64Array()
	edits.resize(comp.size())
	var has_soft_only := true
	for k in comp.size():
		var m := world.vox[comp[k]]
		data[k] = (comp[k] << Defs.EDIT_SHIFT) | m
		edits[k] = comp[k] << Defs.EDIT_SHIFT
		if m != Defs.LEAF and m != Defs.CYPRESS and m != Defs.OLIVE and m != Defs.TRUNK:
			has_soft_only = false
	var big := comp.size() >= 6 and fragments.size() < MAX_FRAGMENTS
	game.push_edits(edits, big)
	if not big:
		return
	var id := next_frag
	next_frag += 1
	var n := comp.size()
	fragments[id] = {"size": n, "soft": has_soft_only}
	game.frag_all(id, data)


func fragment_landed(id: int, p: Vector3) -> void:
	if not fragments.has(id):
		return
	var n: int = fragments[id].size
	var soft: bool = fragments[id].soft
	fragments.erase(id)
	game.frag_break_all(id)
	if soft:
		return
	var r := clampf(1.8 + pow(float(n), 0.33) * 0.6, 2.0, 6.5)
	var p2 := p
	blast(p2, r, 0.75, -1, clampf(n * 0.4, 12.0, 90.0), "crash")


# ---------------------------------------------------------------- proiettili
func _tick_projectiles(dt: float) -> void:
	for id: int in projectiles.keys():
		var pr: Dictionary = projectiles[id]
		pr.life -= dt
		var from: Vector3 = pr.pos
		var vel: Vector3 = pr.vel
		var nv := vel + Vector3(0, -GRAVITY * dt, 0)
		var to := from + vel * dt + Vector3(0, -0.5 * GRAVITY * dt * dt, 0)
		var steps := int(from.distance_to(to) / 0.45) + 1
		var hit := false
		var hp := to
		for s in range(1, steps + 1):
			var q := from.lerp(to, float(s) / steps)
			# cupole
			var stopped := false
			for dm: Dictionary in domes:
				if dm.team != pr.team and (dm.pos as Vector3).distance_to(q) < float(dm.r):
					stopped = true
					break
			if stopped or q.y <= Defs.SEA + 0.3 or world.get_v(int(floor(q.x)), int(floor(q.y)), int(floor(q.z))) != 0:
				hit = true
				hp = q
				if stopped:
					pr.kind = -1
				break
		pr.pos = to
		pr.vel = nv
		if hit:
			_projectile_hit(id, pr, hp)
		elif pr.life <= 0.0:
			projectiles.erase(id)
			game.proj_end_all(id)


func _projectile_hit(id: int, pr: Dictionary, p: Vector3) -> void:
	var kind: int = pr.kind
	if kind == -1:
		projectiles.erase(id)
		game.proj_end_all(id)
		game.fx_all("dome_hit", p, 2.0)
		return
	if kind == Defs.SHOT_BALL and pr.pierce > 0:
		pr.pierce -= 1
		blast(p, 2.2, 1.4, pr.team, float(pr.dmg) * 0.7, "boom", pr.src)
		pr.vel = (pr.vel as Vector3) * 0.75
		pr.pos = p + (pr.vel as Vector3).normalized() * 1.5
		return
	projectiles.erase(id)
	game.proj_end_all(id)
	if p.y <= Defs.SEA + 0.4 and world.get_v(int(p.x), int(p.y), int(p.z)) == 0:
		game.fx_all("splash", p, 2.0)
		return
	match kind:
		Defs.SHOT_STONE: blast(p, 3.3, 1.65, pr.team, pr.dmg, "boom", pr.src)
		Defs.SHOT_BALL: blast(p, 2.6, 1.6, pr.team, pr.dmg, "boom", pr.src)
		Defs.SHOT_METEOR: blast(p, 5.6, 2.5, pr.team, 70.0, "boom_big")
		Defs.SHOT_COW: blast(p, 4.4, 2.1, pr.team, 55.0, "moo")


func _tick_sched(dt: float) -> void:
	var i := sched.size() - 1
	while i >= 0:
		var e: Dictionary = sched[i]
		e.t -= dt
		if e.t <= 0.0:
			sched.remove_at(i)
			_run_sched(e)
		i -= 1


func _run_sched(e: Dictionary) -> void:
	var p: Vector3 = e.pos
	match e.kind:
		"meteor", "cow":
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.0, 15.0)
			var t := p + Vector3(cos(a) * r, 0, sin(a) * r)
			t.y = world.top_y(int(t.x), int(t.z))
			var from := t + Vector3(rng.randf_range(-18, 18), 70.0, rng.randf_range(-18, 18))
			var ft := 1.5
			var vel := (t - from) / ft + Vector3(0, 0.5 * GRAVITY * ft, 0)
			_spawn_projectile(from, vel, Defs.SHOT_METEOR if e.kind == "meteor" else Defs.SHOT_COW, e.team, 0.0)
		"quake":
			_quake_pulse(p, e.team)


## Il terremoto spaventa chi difende: per 10 secondi colpisce a metà forza e attacca più piano.
const FEAR_T := 10.0
const FEAR_DMG := 0.5
const FEAR_CD := 1.4


## Scossa: indebolisce la base delle strutture, il resto crolla per gravità.
## I nemici nel cerchio si spaventano (vedi FEAR_T): la paura parte alla prima scossa che li prende.
func _quake_pulse(p: Vector3, team: int) -> void:
	const QR := 24
	for u in ulist:
		if u.team != team and u.hp > 0.0 and u.fear <= 0.0 and not at_peace(team, u.team) and Vector2(u.pos.x - p.x, u.pos.z - p.z).length() < QR:
			u.fear = FEAR_T
			if rng.randf() < 0.2:
				_say(u, Defs.SAY_PANICO, true)
	var removed := PackedInt32Array()
	for z in range(int(p.z) - QR, int(p.z) + QR + 1):
		for x in range(int(p.x) - QR, int(p.x) + QR + 1):
			if Vector2(x - p.x, z - p.z).length() > QR:
				continue
			var top := world.top_y(x, z)
			if top == 0:
				continue
			var yy := top - 1
			var tries := 0
			while yy > 0 and world.get_v(x, yy, z) >= Defs.STRUCT_MIN and tries < 24:
				if rng.randf() < 0.055:
					removed.append(world.index(x, yy, z))
				yy -= 1
				tries += 1
	if not removed.is_empty():
		var edits := PackedInt64Array()
		edits.resize(removed.size())
		for k in removed.size():
			edits[k] = removed[k] << Defs.EDIT_SHIFT
		game.push_edits(edits)
		_collapse_check(removed)
	_mark_fields(p)
	_splash(p, float(QR), 3.0, team)


func _segment_distance_2d(a: Vector3, b: Vector3, q: Vector3) -> float:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pq := Vector2(q.x, q.z)
	return Geometry2D.get_closest_point_to_segment(pq, pa, pb).distance_to(pq)


func _near_own_castle(p: Vector3, team: int) -> bool:
	for c: Dictionary in castles:
		if c.owner == team or at_peace(team, int(c.owner)):  # in tregua non sfonda neanche i vicini
			var ce: Vector3 = c.center
			if absf(p.x - ce.x) <= WHEEL_OWN_MARGIN and absf(p.z - ce.z) <= WHEEL_OWN_MARGIN:
				return true
	return false


func _tick_wheels(dt: float) -> void:
	var i := wheels.size() - 1
	while i >= 0:
		var wh: Dictionary = wheels[i]
		if not wh.has("hit"):
			wh.merge({"hit": {}, "kills": 0, "carved": 0})
		wh.t -= dt
		var p: Vector3 = wh.pos
		var v: Vector3 = wh.vel
		v.y -= GRAVITY * dt
		p += v * dt
		const WR := 4.0
		var gy := _ground_under(p, WR)
		var speed0 := Vector2(v.x, v.z).length()
		if p.y - WR < gy:
			if p.y - WR < gy - 3.0 and speed0 > 0.0:
				# la scarpata è ripida: la forma rallenta ma scavalca
				v *= 0.9
			p.y = gy + WR
			if v.y < -8.0:
				v.y = -v.y * 0.45
			else:
				v.y = 0.0
		wh.roll += speed0 * dt / WR
		# davanti a un castello proprio la forma si sbriciola senza fare danni
		if _near_own_castle(p, wh.team):
			wheels.remove_at(i)
			game.fx_all("crash", p, 3.0)
			i -= 1
			continue
		var carved := _carve(p, WR)
		if carved > 0:
			# le mura frenano davvero: la forma apre una breccia, non un tunnel da parte a parte
			var f := clampf(1.0 - carved * 0.004, 0.45, 1.0)
			v.x *= f
			v.z *= f
			wh.carved = int(wh.carved) + carved
		# chi se la vede arrivare scappa urlando, dritto davanti alla forma come nei cartoni
		var dir := Vector3(v.x, 0, v.z).normalized()
		if not wh.has("fled"):
			wh.fled = {}
		for u in ulist:
			if u.team == wh.team or at_peace(wh.team, u.team) or u.hp <= 0.0 or u.flee > 0.0 or u.feast > 0.0 or (wh.fled as Dictionary).has(u.id):
				continue
			var rel := u.pos - p
			rel.y = 0.0
			var ahead := rel.dot(dir)
			if ahead > 0.0 and ahead < 16.0 and absf(rel.cross(dir).y) < WR + 3.0:
				wh.fled[u.id] = true
				var side := 1.0 if rel.cross(dir).y > 0.0 else -1.0
				u.flee = rng.randf_range(1.2, 1.8)
				u.flee_pos = u.pos + dir * 10.0 - Vector3(-dir.z, 0, dir.x) * side * 2.5
				if rng.randf() < 0.3:
					_say(u, Defs.SAY_PANICO, rng.randf() < 0.5)
		# ogni soldato viene travolto una volta sola (prima il danno era continuo: 90 al secondo)
		for u in ulist:
			if u.team != wh.team and not at_peace(wh.team, u.team) and u.hp > 0.0 and not (wh.hit as Dictionary).has(u.id) and u.pos.distance_to(p) < WR + 1.5:
				wh.hit[u.id] = true
				_hurt(u, WHEEL_DMG, SRC_POWER)
				if u.hp <= 0.0:
					wh.kills = int(wh.kills) + 1
		if int(wh.carved) > WHEEL_WALL_BUDGET:
			speed0 = 0.0  # crosta finita: si sbriciola contro le mura
		wh.pos = p
		wh.vel = v
		var dead: bool = wh.t <= 0.0 or speed0 < 3.0 or p.x < 4 or p.z < 4 or p.x > Defs.WX - 4 or p.z > Defs.WZ - 4 or p.y < Defs.SEA - 1.0
		if dead:
			wheels.remove_at(i)
			if p.y > Defs.SEA:
				blast(p, 4.0, 1.4, wh.team, 25.0, "boom_big")
			else:
				game.fx_all("splash", p, 5.0)
			_wheel_report(wh, p)
		i -= 1


func _ground_under(p: Vector3, r: float) -> float:
	var x := int(p.x)
	var z := int(p.z)
	var y := int(p.y + r)
	y = clampi(y, 0, Defs.WY - 1)
	while y > 0:
		var m := world.get_v(x, y, z)
		if m != 0 and m < Defs.STRUCT_MIN:
			return float(y + 1)
		y -= 1
	return float(Defs.SEA - 4)


## Scava solo strutture (la forma non fa crateri nel terreno).
func _carve(p: Vector3, r: float) -> int:
	var ir := int(ceil(r))
	var removed := PackedInt32Array()
	var r2 := r * r
	for y in range(int(p.y) - ir, int(p.y) + ir + 1):
		for z in range(int(p.z) - ir, int(p.z) + ir + 1):
			for x in range(int(p.x) - ir, int(p.x) + ir + 1):
				var q := Vector3(x + 0.5, y + 0.5, z + 0.5).distance_squared_to(p)
				if q > r2:
					continue
				if world.get_v(x, y, z) >= Defs.STRUCT_MIN:
					removed.append(world.index(x, y, z))
	if removed.is_empty():
		return 0
	var edits := PackedInt64Array()
	edits.resize(removed.size())
	for k in removed.size():
		edits[k] = removed[k] << Defs.EDIT_SHIFT
	game.push_edits(edits)
	_collapse_check(removed)
	_mark_fields(p)
	return removed.size()


func _tick_domes(dt: float) -> void:
	var i := domes.size() - 1
	while i >= 0:
		domes[i].t -= dt
		if domes[i].t <= 0.0:
			domes.remove_at(i)
		i -= 1


func _tick_oil(dt: float) -> void:
	var i := oils.size() - 1
	while i >= 0:
		var o: Dictionary = oils[i]
		o.t -= dt
		_splash(o.pos, 7.0, 22.0 * dt, o.team)
		if o.t <= 0.0:
			oils.remove_at(i)
		i -= 1


# ---------------------------------------------------------------- economia, castelli
func _tick_slow(dt: float) -> void:
	var faith_rate := _faith_rates(dt)
	_tick_events(dt)
	var counts := {}
	for c: Dictionary in castles:
		var o: int = c.owner
		counts[o] = int(counts.get(o, 0)) + 1
	for t in Defs.HOUSE_COUNT:
		var h: Dictionary = houses[t]
		var n: int = counts.get(t, 0)
		var was: bool = h.alive
		h.alive = n > 0
		if was and not h.alive:
			game.msg_all("%s è caduta!" % _hname(t), Defs.HOUSES[t].color)
		var ai_f := ai_income if h.ai else 1.0
		h.gold += Defs.income(n) * dt * ai_f * _stat(t, Defs.STAT_SOLDI)
		h.faith = minf(float(h.faith) + float(faith_rate[t]) * dt, Defs.FAITH_CAP)
		h.faith_rate = faith_rate[t]
		h.sleep_msg_t = float(h.sleep_msg_t) - dt
		# spesa in riparazioni al secondo, smussata per l'HUD
		h.repair_rate = lerpf(float(h.repair_rate), float(h.repair_spent) / dt, 0.5)
		if float(h.repair_rate) < 0.05:
			h.repair_rate = 0.0
		h.repair_spent = 0.0
		for k in Defs.POWER_COUNT:
			if h.cd[k] > 0.0:
				h.cd[k] = maxf(float(h.cd[k]) - dt, 0.0)
	_tick_lords(dt)
	_tick_mode(dt)
	for c: Dictionary in castles:
		_tick_castle(c, dt)
	_tick_buildings(dt)
	_check_winner()


func _tick_castle(c: Dictionary, dt: float) -> void:
	var owner_t: int = c.owner
	var ce: Vector3 = c.center
	if c.shot_cd > 0.0: c.shot_cd = maxf(float(c.shot_cd) - dt, 0.0)
	if c.oil_cd > 0.0: c.oil_cd = maxf(float(c.oil_cd) - dt, 0.0)
	# coda di reclutamento
	var q: Array = c.queue
	if not q.is_empty():
		q[0].t -= dt * recruit_speed(c)
		if q[0].t <= 0.0:
			var type: int = q[0].type
			q.remove_at(0)
			var gdir: Vector3 = c.dir
			var side := Vector3(-gdir.z, 0, gdir.x)
			var spawn: Vector3 = (c.gate_out as Vector3) + side * rng.randf_range(-3, 3) * CS + gdir * rng.randf_range(0, 3)
			var nu := spawn_unit(type, owner_t, spawn)
			if bool(c.get("flag_on", false)) and type != Defs.FRATE:
				_to_flag(nu, c)
			elif type == Defs.FRATE:
				# il frate entra subito a pregare nel cortile
				nu.target = (c.rally as Vector3) - gdir * rng.randf_range(2.0, 5.0) + side * rng.randf_range(-3.0, 3.0) * CS
				nu.has_order = true
	# nemici attorno al castello (allarme, torri, mangano, milizia)
	var hostile_near := 0
	var threat := 0
	var nearest: U = null
	var nd := 1e9
	for u in ulist:
		var dist := u.pos.distance_to(ce)
		if dist > 58.0 + R * 1.5:
			continue
		if u.team != owner_t and u.feast <= 0.0 and not at_peace(owner_t, u.team):  # chi è alla sagra non assedia
			hostile_near += 1
			if dist < 20.0 + R and u.type != Defs.FRATE:
				threat += 1
			if dist < nd:
				nd = dist
				nearest = u
	c.threat = threat
	c.under_attack = (hostile_near > 0 and nd < 20.0 + R) or float(c.king_calm) > 0.0
	# da quanto nessuno lo disturba: i castelli tranquilli (isolati, su un'isola) attirano le IA
	c.quiet_t = 0.0 if c.under_attack or hostile_near > 0 else float(c.get("quiet_t", 0.0)) + dt
	# il re si riprende se nessuno lo colpisce da qualche secondo
	c.king_safe = maxf(float(c.king_safe) - dt, 0.0)
	c.king_calm = float(c.king_calm) - dt
	c.king_quip_t = float(c.king_quip_t) - dt
	if c.king_calm <= 0.0:
		c.king_hp = minf(float(c.king_hp) + KING_REGEN * dt, KING_HP)
		if c.king_hp >= KING_HP:
			c.king_by = -1
	c.capture = 1.0 - float(c.king_hp) / KING_HP
	c.capture_by = c.king_by
	# torri e mastio che tirano
	c.tower_cd = float(c.tower_cd) - dt
	if c.tower_cd <= 0.0 and nearest != null:
		c.tower_cd = TOWER_CD
		var shooters: Array = (c.towers as Array).duplicate()
		var kp: Vector3 = c.keep
		var keep_wall := Vector3i(int(kp.x) + WorldGen.KEEP_K, int(c.base) + WorldGen.KEEP_H - 2, int(kp.z))
		if world.get_v(keep_wall.x, keep_wall.y, keep_wall.z) != 0:
			shooters.append(kp + Vector3(0, WorldGen.KEEP_H + 1, 0))
		for tp: Vector3 in shooters:
			if world.get_v(int(tp.x), int(tp.y) - 2, int(tp.z)) == 0 and tp.y < kp.y + WorldGen.KEEP_H:
				continue
			for tu: U in _tower_targets(tp, owner_t, TOWER_RANGE, TOWER_SHOTS):
				_arrow(tp, tu.pos + Vector3(0, 1, 0))
				_hurt(tu, TOWER_DAMAGE, SRC_TOWER)
	# mangano del mastio: da solo, per tutti, dove i nemici sono più ammassati
	if c.shot_cd <= 0.0 and nearest != null and nd < 48.0 + R:
		var spot := _crowd_spot(ce, owner_t, 48.0 + R, 6.0, -1.0)
		if spot.y > -999.0:
			c.shot_cd = MANGANO_AUTO_CD
			cmd_shot_auto(c, spot)
	# olio bollente automatico su chi si accalca sotto le mura o alla porta
	c.auto_oil_cd = maxf(float(c.get("auto_oil_cd", 0.0)) - dt, 0.0)
	if float(c.auto_oil_cd) <= 0.0 and nearest != null and nd < R + 10.0:
		var op := _crowd_spot(ce, owner_t, R + 9.0, 6.0, R - WALL_T - 1.0, OIL_AUTO_MIN)
		if op.y > -999.0:
			c.auto_oil_cd = OIL_AUTO_CD
			oils.append({"pos": op, "t": 5.0, "team": owner_t})
			game.fx_all("oil", op, 5.0)
	# milizia gratuita se il castello è sguarnito
	c.militia_t = float(c.militia_t) - dt
	if c.militia_t <= 0.0 and nd > MILITIA_SAFE_DIST:
		c.militia_t = 9.0
		var own := 0
		for u in ulist:
			if u.team == owner_t and u.pos.distance_to(ce) < 13.0 + R:
				own += 1
		var want := 6 if owner_t == Defs.NEUTRAL else 3
		# anche la milizia conta nelle truppe: al limite non ne arriva altra
		if own < want and (owner_t == Defs.NEUTRAL or unit_room(owner_t) > 0):
			var m := spawn_unit(Defs.FANTE, owner_t, (c.rally as Vector3) + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)) * CS)
			if owner_t == Defs.NEUTRAL:
				m.home = m.pos
	# riparazioni
	if c.repair:
		_repair(c, dt)


func cmd_shot_auto(c: Dictionary, p: Vector3) -> void:
	var from: Vector3 = (c.keep as Vector3) + Vector3(0, WorldGen.KEEP_H + 2, 0)
	_fire_arc(from, p, Defs.SHOT_STONE, c.owner, 26.0)


func _hurt_king(c: Dictionary, dmg: float, team: int) -> void:
	if float(c.king_safe) > 0.0 or int(c.owner) == team or at_peace(int(c.owner), team):
		return
	if float(c.king_calm) <= 0.0:
		_call_to_arms(c)
	c.king_hp = float(c.king_hp) - dmg
	c.king_calm = KING_CALM
	c.king_by = team
	c.under_attack = true
	if float(c.king_quip_t) <= 0.0:
		c.king_quip_t = 14.0
		var line := _king_line("KING_HIT", c, team)
		game.msg_house(int(c.owner), line, UiStyle.DANGER_TEXT)
		game.msg_house(team, line, Defs.HOUSES[team].color)
	if float(c.king_hp) <= 0.0:
		_king_dies(c, team)


func _king_dies(c: Dictionary, team: int) -> void:
	var was: int = c.owner
	var variant := rng.randi() % Defs.KING_DEATHS.size()
	if variant == _last_king_death:  # mai due volte di fila la stessa uscita di scena
		variant = (variant + 1) % Defs.KING_DEATHS.size()
	_last_king_death = variant
	game.fx_all("king_dead", c.king, float(was + 16 * team + 256 * variant))
	var line := _king_line("KING_DEAD", c, team)
	_capture(c, team)
	game.msg_all(line, Defs.HOUSES[team].color)
	# l'IA che vince sfotte anche lei, a volte
	if houses[team].ai and events_enabled and rng.randf() < 0.4:
		cmd_taunt(team, rng.randi() % Defs.TAUNTS.size())
	c.king_hp = KING_HP
	c.king_calm = 0.0
	c.king_safe = KING_SAFE
	c.king_by = -1
	c.capture = 0.0
	c.capture_by = -1


## Battuta sul re: {k} re o podestà di {t}, {c} la casata che attacca.
func _king_line(key: String, c: Dictionary, team: int) -> String:
	var lines: Array = Defs.KING_HIT if key == "KING_HIT" else Defs.KING_DEAD
	var who := Defs.castle_boss(c, int(c.owner))
	return String(lines[rng.randi() % lines.size()]).format({"k": who, "K": who.capitalize(), "t": c.name, "c": _hname(team)})


## Fino a n nemici a portata della torre: prima arieti, catapulte e bombarde, poi i più vicini.
func _tower_targets(p: Vector3, team: int, radius: float, n: int) -> Array[U]:
	var cand: Array = []
	var r2 := radius * radius
	for u in ulist:
		if u.team == team or u.hp <= 0.0 or u.feast > 0.0 or at_peace(team, u.team):
			continue
		var d := u.pos.distance_squared_to(p)
		if d < r2:
			var pri := 0.0 if u.type == Defs.ARIETE or _is_siege(u) else 1.0
			cand.append([pri * 1e6 + d, u])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[U] = []
	for k in mini(n, cand.size()):
		out.append(cand[k][1])
	return out


## Il punto con più nemici vicini (entro `near`), fra quelli a meno di `radius` dal centro e
## (se min_ring >= 0) fuori dal quadrato del cortile. y = -1000 se ce ne sono meno di `need`.
func _crowd_spot(ce: Vector3, team: int, radius: float, near: float, min_ring: float, need := 1) -> Vector3:
	var hostile: Array[U] = []
	for u in ulist:
		if u.team == team or u.hp <= 0.0 or u.feast > 0.0 or at_peace(team, u.team) or u.pos.distance_to(ce) > radius:
			continue
		if min_ring >= 0.0 and maxf(absf(u.pos.x - ce.x), absf(u.pos.z - ce.z)) < min_ring:
			continue
		hostile.append(u)
	var best := Vector3(0, -1000, 0)
	var bn := need - 1
	for a in hostile:
		var n := 0
		for b in hostile:
			if a.pos.distance_squared_to(b.pos) < near * near:
				n += 1
		if n > bn:
			bn = n
			best = a.pos
	return best


func _closest_hostile(p: Vector3, team: int, radius: float) -> U:
	var best: U = null
	var bd := radius * radius
	for u in ulist:
		if u.team == team or u.hp <= 0.0:
			continue
		var d := u.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = u
	return best


## Chi conquista un castello si prende anche le botteghe del vecchio padrone che gli stanno attorno
## (quelle per cui è il castello più vicino), con il loro potere. Anche i cantieri.
func _take_shops(c: Dictionary, was: int, team: int) -> void:
	if was < 0 or was >= Defs.HOUSE_COUNT or was == team:
		return
	var n := 0
	for b: Dictionary in buildings:
		if int(b.owner) != was:
			continue
		var bp := Vector3(float(b.x), 0.0, float(b.z))
		var near := -1
		var nd := 1e12
		for o: Dictionary in castles:
			var d := Vector2(bp.x - o.center.x, bp.z - o.center.z).length()
			if d < nd:
				nd = d
				near = o.id
		if near == c.id and nd <= Buildings.RANGE + 10.0:
			b.owner = team
			n += 1
	if n > 0:
		game.msg_house(team, "Con %s prendi anche %s: ora lavorano per te" % [c.name, "una bottega" if n == 1 else "%d botteghe" % n], UiStyle.GOLD)
		game.msg_house(was, "Con %s perdi anche %s" % [c.name, "una bottega" if n == 1 else "%d botteghe" % n], UiStyle.DANGER_TEXT)


## bought: il castello è stato comprato (Este), quindi niente premio di conquista.
func _capture(c: Dictionary, team: int, bought := false) -> void:
	var was: int = c.owner
	if not stats.is_empty():
		stats.captures += 1
		if stats.first_capture < 0.0:
			stats.first_capture = time
	c.owner = team
	c.capture = 0.0
	c.capture_by = -1
	c.queue = []
	c.flag_on = false  # la bandiera di raduno era del padrone di prima
	_take_shops(c, was, team)
	if not bought:
		houses[team].gold = float(houses[team].gold) + Defs.CAPTURE_REWARD
	c.repair = false
	var edits := PackedInt64Array()
	var bn: PackedInt32Array = c.banners
	for i in bn:
		if world.vox[i] != 0:
			edits.append((i << Defs.EDIT_SHIFT) | (Defs.TEAM0 + team))
	if not edits.is_empty():
		game.push_edits(edits, false)
	# nei castelli la truppa neutrale che resta si arrende
	game.msg_all("%s conquista %s!" % [_hname(team), c.name], Defs.HOUSES[team].color)
	game.fx_all("capture", c.center, float(was))
	# balli di vittoria: chi c'era festeggia, e qualcuno lo dice forte
	game.fx_all("dance", c.center, float(team))
	# chi ha preso il mastio esce nel cortile a farsi vedere (dentro al mastio nessuno li vedeva ballare)
	var ce: Vector3 = c.center
	var gdir: Vector3 = c.dir
	var side := Vector3(-gdir.z, 0, gdir.x)
	for u: U in ulist:
		if u.team == team and u.hp > 0.0 and not u.has_order and u.tgt == null and absf(u.pos.x - ce.x) < R - 1.0 and absf(u.pos.z - ce.z) < R - 1.0:
			# nelle fasce ai lati del mastio: davanti, sotto le mura, non li vedrebbe nessuno
			u.target = ce + side * (rng.randf_range(12.0, 19.0) * (-1.0 if rng.randf() < 0.5 else 1.0)) + gdir * rng.randf_range(-8.0, 8.0)
			u.has_order = true
	var said := 0
	for u: U in ulist:
		if u.team == team and u.hp > 0.0 and said < 3 and u.pos.distance_to(c.center) < R + 14.0 and rng.randf() < 0.35:
			said += 1
			_say(u, Defs.SAY_VITTORIA, true)
	_check_winner()


func _repair(c: Dictionary, dt: float) -> void:
	var bp: PackedInt64Array = c.blueprint
	var rate := REPAIR_PER_SEC_ATTACKED if repair_slow_when_attacked and c.under_attack else REPAIR_PER_SEC
	c.repair_acc = float(c.get("repair_acc", 0.0)) + rate * dt
	var budget := mini(int(c.repair_acc), int(c.repair_left))
	c.repair_acc = float(c.repair_acc) - float(budget)
	var edits := PackedInt64Array()
	var i: int = c.repair_i
	var scanned := 0
	var done := false
	while edits.size() < budget and scanned < 3000:
		if i >= bp.size():
			# giro completo senza buchi: non c'è altro da fare (il resto pagato torna indietro)
			if not bool(c.repair_found):
				done = true
				break
			c.repair_found = false
			i = 0
		var e: int = bp[i]
		var idx: int = e >> Defs.EDIT_SHIFT
		var mat: int = e & Defs.EDIT_MASK
		if world.vox[idx] == 0:
			if mat >= Defs.TEAM0:
				mat = Defs.TEAM0 + int(c.owner)
			edits.append((idx << Defs.EDIT_SHIFT) | mat)
			c.repair_found = true
		i += 1
		scanned += 1
	c.repair_i = i
	c.repair_left = int(c.repair_left) - edits.size()
	if not edits.is_empty():
		if not stats.is_empty():
			stats.repaired += edits.size()
		game.push_edits(edits, false)
		_mark_fields(c.center)
		game.fx_all("repair", c.center, 1.0)
	if int(c.repair_left) <= 0 or done:
		if done and int(c.repair_left) > 0:
			houses[c.owner].gold = float(houses[c.owner].gold) + float(c.repair_left) * REPAIR_COST
		c.repair = false
		c.repair_left = 0
		_update_integrity(c)
		game.msg_house(c.owner, "Mura di %s riparate" % c.name, UiStyle.GOLD)


func _update_integrity(c: Dictionary) -> void:
	var bp: PackedInt64Array = c.blueprint
	var alive := 0
	var total := bp.size()
	for e in bp:
		if world.vox[e >> Defs.EDIT_SHIFT] != 0:
			alive += 1
	c.integrity = float(alive) / maxf(total, 1.0)
	c.missing = total - alive


# ---------------------------------------------------------------- modalità
func _tick_mode(dt: float) -> void:
	if winner >= 0:
		return
	match mode:
		Defs.MODE_TEMPO:
			if time >= Defs.TIME_LIMIT:
				_declare_winner(_leader_by_castles(), "Tempo scaduto! %s ha più castelli e si prende l'Italia")
		Defs.MODE_PALIO:
			if drappo_pts.size() != Defs.HOUSE_COUNT:
				drappo_pts.resize(Defs.HOUSE_COUNT)
				drappo_pts.fill(0.0)
			if drappo < 0 or time >= drappo_move_t:
				_move_drappo()
			var o := int(castles[drappo].owner)
			if o >= 0 and o < Defs.HOUSE_COUNT and time >= truce_until:
				drappo_pts[o] = float(drappo_pts[o]) + dt
				if float(drappo_pts[o]) >= Defs.DRAPPO_GOAL:
					_declare_winner(o, "%s vince il Palio: il Drappo è suo!")


## Il Drappo passa a un castello lontano dagli ultimi dove è stato, a caso fra i migliori tre.
func _move_drappo() -> void:
	var cands: Array = []
	for c: Dictionary in castles:
		if c.id == drappo:
			continue
		var far := 1e9
		for k: int in _drappo_last:
			far = minf(far, (c.center as Vector3).distance_to(castles[k].center))
		cands.append([far, c.id])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	drappo = int(cands[rng.randi() % mini(3, cands.size())][1])
	_drappo_last.append(drappo)
	if _drappo_last.size() > 3:
		_drappo_last.pop_front()
	drappo_move_t = time + Defs.DRAPPO_EVERY
	game.banner_all("Il Drappo passa a %s!" % castles[drappo].name, "chi tiene il castello fa punti, fra 4 minuti si sposta", castles[drappo].center)


func _leader_by_castles() -> int:
	var best := -1
	var bn := -1
	var bu := -1
	for t in Defs.HOUSE_COUNT:
		var n := _castles_of(t)
		var u := house_unit_count(t)
		if n > bn or (n == bn and u > bu):
			best = t
			bn = n
			bu = u
	return best


func _declare_winner(t: int, line: String) -> void:
	if t < 0 or winner >= 0:
		return
	winner = t
	game.msg_all(line % _hname(t), Defs.HOUSES[t].color)
	game.fx_all("victory", castles[0].center, float(t))


func _check_winner() -> void:
	if winner >= 0:
		return
	var first: int = castles[0].owner
	for c: Dictionary in castles:
		if c.owner != first:
			return
	if first == Defs.NEUTRAL:
		return
	winner = first
	game.msg_all("%s domina tutta l'ITALIA!" % _hname(first), Defs.HOUSES[first].color)
	game.fx_all("victory", castles[0].center, float(first))


# ---------------------------------------------------------------- IA
## La recluta dell'IA: r sceglie dalla tabella, r2 decide se adattarsi ai nemici vicini.
## mix = quote di cavalieri (x) e di fanti (y) tra i soldati nemici a portata dei suoi castelli.
## Contro un'orda di cavalieri i balestrieri, i cavalieri e i menestrelli lasciano spesso il posto ai
## fanti con le picche; contro un'orda di fanti i cavalieri, che le picche le temono, fanno lo stesso.
## Le macchine d'assedio restano: servono per le mura.
static func ai_pick_unit(r: float, r2: float, mix: Vector2) -> int:
	var type: int = Defs.FANTE
	if r > 0.95: type = Defs.MENESTRELLO
	elif r > 0.90: type = Defs.NONNA
	elif r > 0.86: type = Defs.CATAPULTA
	elif r > 0.76: type = Defs.ARIETE
	elif r > 0.72: type = Defs.BOMBARDA
	elif r > 0.52: type = Defs.CAVALIERE
	elif r > 0.30: type = Defs.BALESTRIERE
	if (type == Defs.BALESTRIERE or type == Defs.CAVALIERE or type == Defs.MENESTRELLO) and r2 < clampf((mix.x - 0.2) * 2.0, 0.0, 0.9):
		type = Defs.FANTE
	elif type == Defs.CAVALIERE and r2 < clampf((mix.y - 0.4) * 2.0, 0.0, 0.9):
		type = Defs.FANTE
	return type


## La prossima recluta della casata t (le prove la sostituiscono per simulare un giocatore).
func _ai_pick(t: int) -> int:
	return ai_pick_unit(rng.randf(), rng.randf(), _ai_enemy_mix(t))


## Quote di cavalieri (x) e di fanti (y) tra i soldati nemici a portata dei castelli della casata.
func _ai_enemy_mix(t: int) -> Vector2:
	var horse := 0
	var foot := 0
	var all := 0
	for u: U in ulist:
		if u.team == t or u.team == Defs.NEUTRAL or u.hp <= 0.0 or at_peace(t, u.team):
			continue
		if u.type == Defs.FRATE or _is_siege(u) or u.type == Defs.ARIETE:
			continue
		var near := false
		for c: Dictionary in castles:
			if int(c.owner) == t and (c.center as Vector3).distance_squared_to(u.pos) < AI_HORSE_SEE * AI_HORSE_SEE:
				near = true
				break
		if near:
			all += 1
			if u.type == Defs.CAVALIERE:
				horse += 1
			elif u.type == Defs.FANTE:
				foot += 1
	if all < 4:
		return Vector2.ZERO
	return Vector2(horse, foot) / float(all)


func _ai_tick(t: int, _dt: float) -> void:
	var h: Dictionary = houses[t]
	var own: Array = []
	for c: Dictionary in castles:
		if c.owner == t:
			own.append(c)
	if own.is_empty():
		return
	_ai_build(t, own)
	# un castello degli Este in vendita: chi ha i fiorini ogni tanto lo compra
	if float(h.gold) > Defs.LORD_PRICE + 250.0 and rng.randf() < 0.02:
		for c: Dictionary in castles:
			if _lord_trait(c) == "compra":
				cmd_buy(t, c.id)
				break
	# reclutamento
	var c0: Dictionary = own[rng.randi() % own.size()]
	if (c0.queue as Array).size() < 2:
		var type := _ai_pick(t)
		# all'inizio servono soldati: i primi castelli da prendere sono quelli liberi
		if time < truce_until + AI_HOUSE_GRACE and (type == Defs.ARIETE or type == Defs.CATAPULTA or type == Defs.BOMBARDA):
			type = Defs.FANTE
		# le macchine d'assedio costano: chi ne vuole una mette da parte i fiorini, se no le mura restano in piedi
		if ai_saving.has(t):
			type = int(ai_saving[t])
		if h.gold >= Defs.UNITS[type].cost:
			cmd_recruit(t, c0.id, type)
			ai_saving.erase(t)
		elif type == Defs.ARIETE or type == Defs.CATAPULTA or type == Defs.BOMBARDA:
			ai_saving[t] = type
	# difesa
	var attacked: Dictionary = {}
	for c: Dictionary in own:
		if c.under_attack:
			attacked = c
			break
	if not attacked.is_empty():
		if rng.randf() < 0.1:
			cmd_garrison(t, attacked.id)
		if float(attacked.integrity) < 0.92 and h.gold > 120.0 and not attacked.repair:
			cmd_repair(t, attacked.id)
		var near_ids := PackedInt32Array()
		for u in ulist:
			if u.team == t and not u.has_order and not u.garrison and u.tgt == null and u.pos.distance_to(attacked.center) < 78.0 + R:
				near_ids.append(u.id)
		if not near_ids.is_empty() and rng.randf() < 0.25:
			cmd_order(t, near_ids, attacked.rally, false)
		# un soldato sperduto sotto le mura non deve tenere in casa l'armata per mezz'ora
		if int(attacked.get("threat", 0)) >= AI_DEFEND_MIN or float(attacked.king_calm) > 0.0:
			_ai_power(t, attacked.center, true)
			return
	# attacco
	if ai_stage.has(t):
		_ai_stage_tick(t, ai_stage[t])
		return
	h.army_t = float(h.army_t) - 2.0
	if h.army_t > 0.0:
		return
	h.army_t = rng.randf_range(16.0, 34.0) / (ai_aggression * (1.0 + time / AI_RAMP_SECONDS))
	var ids := _ai_army(t)
	if ids.size() < AI_MIN_ARMY:
		return
	var center := Vector3.ZERO
	for id in ids:
		center += (by_id[id] as U).pos
	center /= ids.size()
	# ogni tanto l'armata va ad abbattere una bottega nemica lì vicino (prima di tutto le chiese)
	if rng.randf() < 0.3:
		var eb := _ai_enemy_building(t, center)
		if not eb.is_empty():
			cmd_order(t, ids, _building_aim(eb, center), true)
			return
	var best := _ai_target(t, center)
	if best.is_empty():
		return
	var to_army := center - (best.center as Vector3)
	to_army.y = 0.0
	var sp: Vector3 = (best.center as Vector3) + to_army.normalized() * (float(TOWER_RANGE) + R + 14.0)
	cmd_order(t, ids, sp, false)
	ai_stage[t] = {"c": best.id, "pos": sp, "ids": ids, "t": time + AI_STAGE_TIMEOUT}


## Quando quasi tutta l'armata è al raduno (o il tempo è scaduto) parte l'assalto.
func _ai_stage_tick(t: int, st: Dictionary) -> void:
	var c: Dictionary = castles[st.c]
	var alive := PackedInt32Array()
	var arrived := 0
	for id: int in st.ids:
		var u: U = by_id.get(id)
		if u == null or u.team != t or u.hp <= 0.0:
			continue
		alive.append(id)
		if Vector2(u.pos.x - (st.pos as Vector3).x, u.pos.z - (st.pos as Vector3).z).length() < AI_STAGE_RADIUS:
			arrived += 1
	if int(c.owner) == t or alive.size() < AI_STAGE_MIN or at_peace(t, int(c.owner)):
		ai_stage.erase(t)
		return
	if float(arrived) >= float(alive.size()) * AI_STAGE_READY or time > float(st.t):
		ai_stage.erase(t)
		cmd_order(t, alive, c.rally, false)
		_ai_power(t, c.center, false)


## Le truppe libere da mandare all'attacco: ogni castello tiene a casa una piccola guarnigione.
func _ai_army(t: int) -> PackedInt32Array:
	var guards := {}
	var ids := PackedInt32Array()
	for u in ulist:
		if u.team != t or u.garrison or u.has_order or u.type == Defs.FRATE:
			continue
		var keep := false
		for c: Dictionary in castles:
			if c.owner == t and u.pos.distance_to(c.center) < 18.0 + R and int(guards.get(c.id, 0)) < AI_GUARD:
				guards[c.id] = int(guards.get(c.id, 0)) + 1
				keep = true
				break
		if not keep:
			ids.append(u.id)
	return ids


## Il castello da attaccare: vicino, indebolito, non già nel mirino di altri.
## In tregua l'IA non attacca nessuno, neanche i castelli liberi: si conquista dopo, ad armi pari.
func _ai_target(t: int, from: Vector3) -> Dictionary:
	if time < truce_until:
		return {}
	var incoming := {}
	for u in ulist:
		if u.team != t and u.goal >= 0:
			incoming[u.goal] = int(incoming.get(u.goal, 0)) + 1
	var owned := {}
	for c: Dictionary in castles:
		owned[c.owner] = int(owned.get(c.owner, 0)) + 1
	var best: Dictionary = {}
	var bd := 1e9
	for c: Dictionary in castles:
		if c.owner == t:
			continue
		if time < truce_until + AI_HOUSE_GRACE and c.owner != Defs.NEUTRAL:
			continue  # subito dopo la tregua solo i castelli liberi: chi gioca ha tempo di organizzarsi
		var d: float = (c.center as Vector3).distance_to(from)
		if c.owner == Defs.NEUTRAL:
			d *= 0.25  # finita la tregua si va prima sui castelli liberi: nessuno li difende
		d *= 0.5 + float(c.integrity)
		d *= 1.0 + float(incoming.get(c.id, 0)) * AI_PILE_PENALTY
		if c.owner != Defs.NEUTRAL and int(owned[c.owner]) >= AI_LEADER_CASTLES:
			d *= AI_LEADER_FACTOR
		if c.owner != Defs.NEUTRAL:
			d *= _quiet_factor(c) * _isolation_factor(c)
		if mode == Defs.MODE_PALIO and c.id == drappo:
			d *= 0.35  # il Drappo fa gola a tutti, anche su un castello libero
		if d < bd:
			bd = d
			best = c
	return best


func _quiet_factor(c: Dictionary) -> float:
	var q := clampf((float(c.get("quiet_t", 0.0)) - QUIET_START) / (QUIET_FULL - QUIET_START), 0.0, 1.0)
	return lerpf(1.0, QUIET_MIN, q)


## Quanto la distanza del castello va ridotta perché è isolato: 1 se ha un vicino a portata.
## I castelli della stessa isola (Cagliari e Oristano) non si fanno compagnia: conta il vicino
## più vicino fuori dall'isola. Dipende solo dalla mappa, quindi è uguale su ogni client e non va salvato.
func _isolation_factor(c: Dictionary) -> float:
	if _isolation.has(c.id):
		return _isolation[c.id]
	var nearest := 1e9
	var land := Defs.landmass(c.id)
	for o: Dictionary in castles:
		if o.id != c.id and (land == 0 or Defs.landmass(o.id) != land):
			nearest = minf(nearest, (c.center as Vector3).distance_to(o.center))
	var f := clampf(pow(ISOLATION_REF / nearest, 1.5), ISOLATION_MIN, 1.0)
	_isolation[c.id] = f
	return f


func _ai_power(t: int, p: Vector3, defending: bool) -> void:
	var h: Dictionary = houses[t]
	if not equal_houses and float(h.get("sp_t", 0.0)) <= time and rng.randf() < 0.5:
		cmd_special(t, p)
	if rng.randf() > 0.1:
		return
	var options: Array = [Defs.P_SCUDO, Defs.P_MUCCHE] if defending else [Defs.P_PARMIGIANO, Defs.P_MUCCHE, Defs.P_VINO, Defs.P_TERREMOTO]
	var k: int = options[rng.randi() % options.size()]
	if h.faith >= Defs.POWERS[k].cost and h.cd[k] <= 0.0:
		var tp := p
		tp.y = world.top_y(int(p.x), int(p.z))
		cmd_power(t, k, tp)


# ---------------------------------------------------------------- rete: stato e snapshot
func state_array() -> Array:
	var cs: Array = []
	for c: Dictionary in castles:
		var q: Array = []
		var q_prog := 0.0
		for e: Dictionary in c.queue:
			q.append(e.type)
		if not q.is_empty():
			var first: Dictionary = c.queue[0]
			q_prog = 1.0 - float(first.t) / float(Defs.UNITS[first.type].time)
		cs.append([c.owner, snappedf(c.capture, 0.01), c.capture_by, snappedf(c.integrity, 0.01), c.repair, snappedf(c.shot_cd, 0.1), snappedf(c.oil_cd, 0.1), c.under_attack, q, snappedf(q_prog, 0.01), c.flag if c.get("flag_on", false) else null,
			snappedf(1.0 - float(c.get("repair_left", 0)) / maxf(float(c.get("repair_total", 0)), 1.0), 0.01) if c.repair else 0.0, int(c.get("missing", 0))])
	var hs: Array = []
	for hi in houses.size():
		var h: Dictionary = houses[hi]
		var cd: Array = []
		for v in (h.cd as Array):
			cd.append(snappedf(v, 0.1))
		var shops := 0
		for k in Defs.BUILDING_COUNT:
			if has_building(hi, k):
				shops |= 1 << k
		hs.append([int(h.gold), int(h.faith), cd, h.ai, h.pname, h.alive, snappedf(h.repair_rate, 0.1), shops, snappedf(float(h.faith_rate), 0.01), ceili(maxf(float(taunt_cd[hi]) - time, 0.0)), ceili(maxf(float(h.get("excom_until", 0.0)) - time, 0.0)), -1 if equal_houses else ceili(maxf(float(h.get("sp_t", 0.0)) - time, 0.0)), ceili(maxf(float(h.get("discount_until", 0.0)) - time, 0.0))])
	var truce: int = ceili(maxf(truce_until - time, 0.0)) if ai_enabled else 0
	var bs: Array = []
	for b: Dictionary in buildings:
		var prog: float = 1.0 - float(b.t) / float(Defs.BUILDINGS[b.type].time) if float(b.t) > 0.0 else 1.0
		bs.append([int(b.id), int(b.type), int(b.owner), int(b.x), int(b.z), int(b.base), int(b.fx), int(b.fz), snappedf(prog, 0.01), bool(b.work)])
	var left := ceili(maxf(Defs.TIME_LIMIT - time, 0.0)) if mode == Defs.MODE_TEMPO else -1
	var md := {"mode": mode, "left": left, "drappo": drappo, "move": ceili(maxf(drappo_move_t - time, 0.0)), "pts": drappo_pts.map(func(v: Variant) -> int: return int(v))}
	return [cs, hs, winner, truce, bs, md]


func _send_snapshot() -> void:
	var buf := PackedByteArray()
	buf.resize(ulist.size() * 12)
	var o := 0
	for u in ulist:
		buf.encode_u16(o, u.id)
		buf.encode_u16(o + 2, int(u.pos.x * 8.0))
		buf.encode_u16(o + 4, int(u.pos.y * 16.0))
		buf.encode_u16(o + 6, int(u.pos.z * 8.0))
		buf[o + 8] = u.type * 16 + u.team
		var fl := 0
		if u.moving: fl |= 1
		if u.attacking: fl |= 2
		if u.water: fl |= 4
		if u.drunk > 0.0: fl |= 8
		if u.shield: fl |= 16
		if u.garrison: fl |= 32
		if u.sleep > 0.0: fl |= 64
		if u.sung: fl |= 128
		buf[o + 9] = fl
		var maxhp: float = Defs.UNITS[u.type].hp
		buf[o + 10] = clampi(int(u.hp / maxhp * 255.0), 0, 255)
		buf[o + 11] = int(posmod(u.yaw, TAU) / TAU * 255.0)
		o += 12
	var whs := PackedFloat32Array()
	for wh: Dictionary in wheels:
		var p: Vector3 = wh.pos
		whs.append_array(PackedFloat32Array([wh.id, p.x, p.y, p.z, atan2((wh.vel as Vector3).x, (wh.vel as Vector3).z), wh.roll]))
	game.snapshot_all(buf, whs, arrow_fx)
	arrow_fx = PackedFloat32Array()


# ---------------------------------------------------------------- edifici e fede
func cmd_build(team: int, type: int, p: Vector3) -> void:
	if type < 0 or type >= Defs.BUILDING_COUNT or team < 0 or team == Defs.NEUTRAL:
		return
	var def: Dictionary = Defs.BUILDINGS[type]
	if houses[team].gold < def.cost or _count_buildings(team) >= Buildings.MAX_PER_HOUSE:
		return
	if spot_problem(team, p) != "":
		return
	houses[team].gold -= float(def.cost)
	if not stats.is_empty():
		stats.spent[team] += float(def.cost)
	_new_building(team, type, p, float(def.time))


## Edificio finito all'istante (tutorial, test, prove).
func build_now(team: int, type: int, p: Vector3) -> Dictionary:
	return _new_building(team, type, p, 0.0)


func spot_problem(team: int, p: Vector3) -> String:
	var owners: Array = []
	for c: Dictionary in castles:
		owners.append(c.owner)
	var others: Array = []
	for b: Dictionary in buildings:
		others.append([b.x, b.z])
	return Buildings.check_spot(world, castles, owners, others, team, p)


func _new_building(team: int, type: int, p: Vector3, t: float) -> Dictionary:
	var ctr := Vector2i(int(floor(p.x)), int(floor(p.z)))
	var base := Buildings.ground_y(world, ctr.x, ctr.y)
	var near: Dictionary = {}
	var nd := 1e9
	for c: Dictionary in castles:
		var dd := (c.center as Vector3).distance_to(p)
		if int(c.owner) == team and dd < nd:
			nd = dd
			near = c
	var face := Buildings.face_toward(p, near.center if not near.is_empty() else p + Vector3.BACK)
	var b := {"id": next_bid, "type": type, "owner": team, "x": ctr.x, "z": ctr.y, "base": base, "fx": face.x, "fz": face.y, "t": t, "T": t, "placed": 0, "fx_t": 0.0, "work": false, "idx": PackedInt32Array()}
	next_bid += 1
	buildings.append(b)
	bldg_by_id[b.id] = b
	# il cantiere: si livella subito il terreno, così il posto è preso e si vede
	var found := Buildings.voxels(world, ctr, base, face, -1)
	_push_vox(found)
	if t <= 0.0:
		_place_building(b)
	return b


func _push_vox(vox: Dictionary) -> void:
	var edits := PackedInt64Array()
	for i: int in vox:
		edits.append((i << Defs.EDIT_SHIFT) | int(vox[i]))
	if not edits.is_empty():
		game.push_edits(edits, false)


func _place_building(b: Dictionary) -> void:
	var vox := Buildings.voxels(world, Vector2i(b.x, b.z), int(b.base), Vector2i(b.fx, b.fz), int(b.type))
	var idx := PackedInt32Array()
	var by := int(b.base)
	for i: int in vox:
		if int(vox[i]) >= Defs.STRUCT_MIN and world.pos_of(i).y >= by:
			idx.append(i)
	_push_vox(vox)
	b.idx = idx
	b.work = true
	b.t = 0.0
	game.fx_all("repair", Vector3(b.x, b.base + 4, b.z), 1.0)
	_mark_fields(Vector3(b.x, b.base, b.z))


func _tick_buildings(dt: float) -> void:
	for b: Dictionary in buildings.duplicate():
		if float(b.t) > 0.0:
			b.t = float(b.t) - dt
			if float(b.t) > 0.0:
				_grow_building(b, dt)
			else:
				build_plans.erase(b.id)
				_place_building(b)
				if int(b.type) == Defs.B_CHIESA:
					game.fx_all("bell", Vector3(b.x, b.base + 8, b.z), 1.0)
				var lines: Array = Defs.BUILD_DONE[b.type]
				var line := String(lines[rng.randi() % lines.size()]).format({"t": _city_near(Vector3(b.x, b.base, b.z)), "c": _hname(b.owner)})
				game.msg_house(int(b.owner), line, Defs.HOUSES[b.owner].color)
			continue
		var idx: PackedInt32Array = b.idx
		var alive := 0
		for i in idx:
			if world.vox[i] != 0:
				alive += 1
		var was: bool = b.work
		b.work = idx.size() > 0 and float(alive) / idx.size() > 0.5
		var name: String = Defs.BUILDINGS[b.type].name
		var where := _city_near(Vector3(b.x, b.base, b.z))
		if was and not b.work:
			game.msg_house(int(b.owner), "%s vicino a %s è crollata: il suo vantaggio è perso" % [name, where], UiStyle.DANGER_TEXT)
		# ridotto a macerie: sparisce, il posto torna libero
		if alive * 5 < idx.size():
			buildings.erase(b)
			bldg_by_id.erase(b.id)


## Il cantiere cresce come una riparazione: a ogni tick si posa la parte di voxel
## che corrisponde al tempo trascorso, strato dopo strato dal basso.
func _grow_building(b: Dictionary, dt: float) -> void:
	var plan: PackedInt64Array = build_plans.get(b.id, PackedInt64Array())
	if plan.is_empty():
		plan = _build_plan(b)
		build_plans[b.id] = plan
	var total: float = float(b.get("T", Defs.BUILDINGS[b.type].time))
	var frac := clampf(1.0 - float(b.t) / maxf(total, 0.01), 0.0, 1.0)
	var n := int(plan.size() * frac)
	var from: int = int(b.get("placed", 0))
	if n <= from:
		return
	var edits := PackedInt64Array()
	var top := 0
	for k in range(from, n):
		var e: int = plan[k] & ((1 << 40) - 1)
		edits.append(e)
		top = plan[k] >> 40
	b.placed = n
	game.push_edits(edits, false)
	b.fx_t = float(b.get("fx_t", 0.0)) - dt
	if float(b.fx_t) <= 0.0:
		b.fx_t = 0.6
		game.fx_all("build", Vector3(b.x + 0.5, top + 1, b.z + 0.5), 1.0)


func _build_plan(b: Dictionary) -> PackedInt64Array:
	var vox := Buildings.voxels(world, Vector2i(b.x, b.z), int(b.base), Vector2i(b.fx, b.fz), int(b.type))
	var by := int(b.base)
	var keys := PackedInt64Array()
	for i: int in vox:
		var m := int(vox[i])
		var y := world.pos_of(i).y
		if m == Defs.AIR or y < by:
			continue
		keys.append((int(y) << 40) | (i << Defs.EDIT_SHIFT) | m)
	keys.sort()
	return keys


func _count_buildings(team: int) -> int:
	var n := 0
	for b: Dictionary in buildings:
		if int(b.owner) == team:
			n += 1
	return n


func has_building(team: int, type: int) -> bool:
	if team < 0 or team >= houses.size():
		return false
	if houses[team].all_shops:
		return true
	for b: Dictionary in buildings:
		if int(b.owner) == team and int(b.type) == type and bool(b.work):
			return true
	return false


## L'edificio la cui area contiene p (vuoto se nessuno).
func building_at(p: Vector3) -> Dictionary:
	var half := Buildings.FOOT / 2.0 + 0.5
	for b: Dictionary in buildings:
		if absf(p.x - (float(b.x) + 0.5)) <= half and absf(p.z - (float(b.z) + 0.5)) <= half:
			return b
	return {}


## Punto da colpire: il bordo dell'edificio più vicino a chi attacca.
func _building_aim(b: Dictionary, from: Vector3) -> Vector3:
	var half := Buildings.FOOT / 2.0
	var cx := float(b.x) + 0.5
	var cz := float(b.z) + 0.5
	var ax := clampf(from.x, cx - half - 0.6, cx + half + 0.6)
	var az := clampf(from.z, cz - half - 0.6, cz + half + 0.6)
	return Vector3(ax, float(b.base), az)


## Ogni colpo stacca qualche voxel, quelli più vicini a chi colpisce: l'edificio si sbriciola a vista.
func _hit_building(b: Dictionary, u: U, n: int) -> void:
	if at_peace(u.team, int(b.owner)):
		return
	var idx: PackedInt32Array = b.idx
	if idx.is_empty():
		return
	var picks := PackedInt32Array()
	var best: Array = []
	for t in 24:
		var i: int = idx[rng.randi() % idx.size()]
		if world.vox[i] == 0:
			continue
		var p := Vector3(world.pos_of(i))
		best.append([p.distance_squared_to(u.pos) - p.y * 0.0, i])
	best.sort_custom(func(a: Array, c: Array) -> bool: return a[0] < c[0])
	for k in mini(n, best.size()):
		picks.append(best[k][1])
	if not picks.is_empty():
		_remove_voxels(picks)
		game.fx_all("hit", Vector3(world.pos_of(picks[0])), 1.0)


func _enemy_building_near(u: U, radius: float) -> int:
	var best := -1
	var bd := radius
	for b: Dictionary in buildings:
		if int(b.owner) == u.team or float(b.t) > 0.0 or at_peace(u.team, int(b.owner)):
			continue
		var d := Vector2(float(b.x) - u.pos.x, float(b.z) - u.pos.z).length() - Buildings.FOOT / 2.0
		if d < bd:
			bd = d
			best = int(b.id)
	return best


func _ai_enemy_building(t: int, from: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bs := 1e9
	for b: Dictionary in buildings:
		if int(b.owner) == t or not bool(b.work) or at_peace(t, int(b.owner)):
			continue
		var d := Vector2(float(b.x) - from.x, float(b.z) - from.z).length()
		if d > 160.0:
			continue
		var score := d - (60.0 if int(b.type) == Defs.B_CHIESA else 0.0)
		if score < bs:
			bs = score
			best = b
	return best


## Il frate libero va a pregare davanti alla chiesa più vicina della sua casata.
func _friar_to_church(u: U) -> void:
	var best: Dictionary = {}
	var bd := 1e9
	for b: Dictionary in buildings:
		if int(b.owner) != u.team or int(b.type) != Defs.B_CHIESA or not bool(b.work):
			continue
		var d := Vector2(float(b.x) - u.pos.x, float(b.z) - u.pos.z).length()
		if d < bd:
			bd = d
			best = b
	if best.is_empty() or bd < PRAY_R:
		return
	var fr: Array = Buildings.front(Vector2i(best.x, best.z), int(best.base), Vector2i(best.fx, best.fz))
	var f: Vector3 = fr[1]
	u.target = (fr[0] as Vector3) + f * rng.randf_range(0.0, 1.5) + Vector3(-f.z, 0, f.x) * rng.randf_range(-3.0, 3.0)
	u.has_order = true
	u.goal = -1


func _near_own_church(u: U, r: float) -> bool:
	for b: Dictionary in buildings:
		if int(b.owner) == u.team and int(b.type) == Defs.B_CHIESA and bool(b.work) and Vector2(float(b.x) - u.pos.x, float(b.z) - u.pos.z).length() < r + Buildings.FOOT / 2.0:
			return true
	return false


## Fede al secondo per casata: ogni chiesa in piedi, più i frati svegli che le pregano davanti.
## Qui i frati si addormentano anche, ogni tanto.
const PRAY_R := 12.0
func _faith_rates(dt: float) -> Array:
	var rate: Array = []
	rate.resize(houses.size())
	rate.fill(0.0)
	var churches: Array = []
	for b: Dictionary in buildings:
		if int(b.type) == Defs.B_CHIESA and bool(b.work):
			churches.append(b)
	var friars := {}
	for u: U in ulist:
		if u.type != Defs.FRATE or u.hp <= 0.0:
			continue
		if u.sleep > 0.0:
			u.sleep = maxf(u.sleep - dt, 0.0)
			continue
		if u.has_order:
			continue
		for b: Dictionary in churches:
			if int(b.owner) == u.team and Vector2(float(b.x) - u.pos.x, float(b.z) - u.pos.z).length() < PRAY_R:
				if rng.randf() < dt / 70.0:
					u.sleep = rng.randf_range(10.0, 18.0)
					_friar_sleep_msg(u, Vector3(b.x, b.base, b.z))
				else:
					friars[b.id] = int(friars.get(b.id, 0)) + 1
				break
	for b: Dictionary in churches:
		var o: int = b.owner
		rate[o] = float(rate[o]) + Defs.FAITH_CHURCH + Defs.FAITH_FRIAR * mini(int(friars.get(b.id, 0)), Defs.FAITH_MAX_FRIARS)
	for t in houses.size():
		if float(houses[t].get("excom_until", 0.0)) > time:
			rate[t] = 0.0
		else:
			rate[t] = float(rate[t]) * _stat(t, Defs.STAT_FEDE)
	return rate


func _friar_sleep_msg(u: U, p: Vector3) -> void:
	_say(u, Defs.SAY_FRATE, true)
	var h: Dictionary = houses[u.team]
	if h.ai or float(h.sleep_msg_t) > 0.0:
		return
	h.sleep_msg_t = 75.0
	var line: String = Defs.FRIAR_SLEEP[rng.randi() % Defs.FRIAR_SLEEP.size()]
	game.msg_house(u.team, line.format({"n": Defs.FRIARS[u.id % Defs.FRIARS.size()], "t": _city_near(p)}), UiStyle.MUTED)


## Un posto libero per costruire attorno al castello c (o -1,-1,-1 se non c'è).
func find_spot(team: int, c: Dictionary) -> Vector3:
	var ce: Vector3 = c.center
	for ring: float in [Buildings.WALL_GAP + 8.0, Buildings.WALL_GAP + 22.0, Buildings.WALL_GAP + 36.0, Buildings.WALL_GAP + 50.0]:
		var off := rng.randf() * TAU
		for k in 16:
			var a := off + k * TAU / 16.0
			var p := ce + Vector3(cos(a), 0, sin(a)) * ring
			if spot_problem(team, p) == "":
				return p
	return Vector3(-1, -1, -1)


## L'IA costruisce: prima la chiesa (senza non ha Fede), poi le botteghe, poi altre chiese; e recluta frati.
func _ai_build(t: int, own: Array) -> void:
	var h: Dictionary = houses[t]
	var churches := 0
	var mine := {}
	for b: Dictionary in buildings:
		if int(b.owner) == t:
			mine[int(b.type)] = int(mine.get(int(b.type), 0)) + 1
			if int(b.type) == Defs.B_CHIESA:
				churches += 1
	var friars := 0
	for u: U in ulist:
		if u.team == t and u.type == Defs.FRATE:
			friars += 1
	if churches > 0 and friars < 3 * churches and h.gold >= 60.0 and rng.randf() < 0.3:
		cmd_recruit(t, own[rng.randi() % own.size()].id, Defs.FRATE)
	if rng.randf() > 0.35:
		return
	var want := -1
	if churches == 0:
		want = Defs.B_CHIESA
	else:
		var shops := [Defs.B_CASEIFICIO, Defs.B_STALLA, Defs.B_CANTINA, Defs.B_SANTUARIO, Defs.B_ASTROLOGO]
		for k in shops.size():
			var ty: int = shops[(k + t * 2) % shops.size()]
			if not mine.has(ty):
				want = ty
				break
		if want < 0 and churches < own.size() + 1:
			want = Defs.B_CHIESA
	if want < 0 or h.gold < float(Defs.BUILDINGS[want].cost) + 40.0:
		return
	var p := find_spot(t, own[rng.randi() % own.size()])
	if p.y > -0.5:
		cmd_build(t, want, p)


# ---------------------------------------------------------------- salvataggio
const CASTLE_SAVE := ["owner", "capture", "capture_by", "queue", "tower_cd", "shot_cd", "oil_cd", "repair", "repair_i",
	"integrity", "missing", "repair_left", "repair_total", "repair_acc", "repair_found", "militia_t", "under_attack", "king_hp", "king_calm", "king_safe", "king_by", "king_quip_t", "auto_oil_cd", "quiet_t", "flag", "flag_on"]
const UNIT_SAVE := ["id", "type", "team", "pos", "target", "home", "has_order", "goal", "hp", "cd", "yaw", "drunk", "fear",
	"garrison", "sleep", "btgt", "vox_t", "vox_pos", "water", "feast", "feast_pos", "flee", "flee_pos"]


func save_state() -> Dictionary:
	var cs: Array = []
	for c: Dictionary in castles:
		var e := {}
		for k: String in CASTLE_SAVE:
			e[k] = c.get(k)
		cs.append(e)
	var us: Array = []
	for u in ulist:
		if u.hp <= 0.0:
			continue
		var e := {}
		for k: String in UNIT_SAVE:
			e[k] = u.get(k)
		us.append(e)
	return {"time": time, "winner": winner, "truce_until": truce_until, "event_t": event_t, "procession_until": procession_until, "palio_pos": palio_pos, "palio_until": palio_until, "next_uid": next_uid, "next_bid": next_bid,
		"mode": mode, "drappo": drappo, "drappo_move_t": drappo_move_t, "drappo_pts": drappo_pts.duplicate(), "drappo_last": Array(_drappo_last),
		"ai_aggression": ai_aggression, "ai_income": ai_income, "ai_cap_mult": ai_cap_mult, "equal_houses": equal_houses,
		"houses": houses.duplicate(true), "castles": cs, "units": us, "buildings": buildings.duplicate(true)}


## Rimette la partita salvata (dopo setup su un mondo con le stesse modifiche già applicate).
func load_state(d: Dictionary) -> void:
	time = d.time
	winner = d.winner
	truce_until = d.truce_until
	event_t = float(d.get("event_t", 240.0))
	procession_until = float(d.get("procession_until", 0.0))
	palio_pos = d.get("palio_pos", Vector3.ZERO)
	palio_until = float(d.get("palio_until", 0.0))
	next_uid = d.next_uid
	next_bid = d.next_bid
	ai_aggression = d.ai_aggression
	ai_income = d.ai_income
	ai_cap_mult = d.ai_cap_mult
	equal_houses = bool(d.get("equal_houses", false))
	mode = int(d.get("mode", Defs.MODE_CONQUISTA))
	drappo = int(d.get("drappo", -1))
	drappo_move_t = float(d.get("drappo_move_t", 0.0))
	drappo_pts = (d.get("drappo_pts", []) as Array).duplicate()
	_drappo_last.clear()
	for k: Variant in d.get("drappo_last", []):
		_drappo_last.append(int(k))
	houses = (d.houses as Array).duplicate(true)
	for i in castles.size():
		var e: Dictionary = d.castles[i]
		for k: String in e:
			castles[i][k] = e[k]
		castles[i].field_dirty = true
	_field_jobs.clear()
	ulist.clear()
	by_id.clear()
	for e: Dictionary in d.units:
		var u := U.new()
		for k: String in e:
			u.set(k, e[k])
		ulist.append(u)
		by_id[u.id] = u
	buildings = (d.buildings as Array).duplicate(true)
	bldg_by_id.clear()
	build_plans.clear()
	for b: Dictionary in buildings:
		bldg_by_id[b.id] = b
	projectiles.clear()
	wheels.clear()
	domes.clear()
	sched.clear()
	oils.clear()


# ---------------------------------------------------------------- si deve ridere
## Fumetto sopra un soldato. Limitato a pochi al secondo su tutta la mappa: ogni client
## mostra solo quelli che ha in vista. a = id * 1000 + categoria * 50 + riga.
func _say(u: U, cat: int, force := false) -> void:
	if not force and say_cd > 0.0:
		return
	say_cd = 0.35
	var lines: Array = Defs.SAY[cat]
	game.fx_all("say", u.pos, float(u.id * 1000 + cat * 50 + rng.randi() % lines.size()))


## Chi carica: se dall'altra parte, o alle sue spalle, c'è una persona vera, la chiama per nome.
func _say_charge(u: U) -> void:
	if u.type == Defs.NONNA:
		_say(u, Defs.SAY_NONNA)
		return
	var enemy := -1
	if u.goal >= 0 and u.goal < castles.size():
		enemy = int(castles[u.goal].owner)
	elif u.tgt != null:
		enemy = u.tgt.team
	var roll := rng.randf()
	if enemy >= 0 and enemy < Defs.HOUSE_COUNT and not bool(houses[enemy].ai) and roll < 0.5:
		_say_named(u, Defs.SAY_CONTRO, enemy)
	elif not bool(houses[u.team].ai) and roll < 0.35:
		_say_named(u, Defs.SAY_PER_CAPO, u.team)
	else:
		_say(u, Defs.SAY_CARICA)


## Fumetto che nomina il giocatore «who»: il nome lo mette ogni client al momento di mostrarlo.
func _say_named(u: U, cat: int, who: int) -> void:
	if say_cd > 0.0:
		return
	say_cd = 0.35
	var lines: Array = Defs.SAY[cat]
	game.fx_all("say_name", u.pos, float(u.id * 100000 + who * 1000 + cat * 50 + rng.randi() % lines.size()))


func cmd_taunt(team: int, k: int) -> void:
	if k < 0 or k >= Defs.TAUNTS.size() or team < 0 or team >= houses.size():
		return
	if float(taunt_cd[team]) > time:
		game.msg_house(team, "Calma: il prossimo sfottò fra %d secondi" % ceili(float(taunt_cd[team]) - time), UiStyle.MUTED)
		return
	taunt_cd[team] = time + TAUNT_CD
	game.msg_all("%s: «%s»" % [_hname(team), Defs.TAUNTS[k]], Defs.HOUSES[team].color)
	game.fx_all("taunt", Vector3.ZERO, float(team * 10 + k))
	# e qualche soldato della casata lo ripete, col fumetto
	var mine: Array = []
	for u: U in ulist:
		if u.team == team and u.hp > 0.0:
			mine.append(u)
	for n in mini(3, mine.size()):
		var u: U = mine[rng.randi() % mine.size()]
		game.fx_all("say", u.pos, float(u.id * 1000 + Defs.SAY_SFOTTO * 50 + (k if k < Defs.SAY[Defs.SAY_SFOTTO].size() else 0)))


func _tick_events(dt: float) -> void:
	say_cd = maxf(say_cd - dt, 0.0)
	if palio_until > 0.0 and time >= palio_until:
		palio_until = 0.0
		game.fx_all("palio_end", palio_pos, -1.0)
		game.msg_all("Nessun cavaliere è arrivato al traguardo: il drappo resta al Comune", UiStyle.MUTED)
	if not events_enabled or winner >= 0 or time < truce_until + 60.0:
		return
	event_t -= dt
	if event_t > 0.0:
		return
	event_t = rng.randf_range(170.0, 260.0)
	var order := [0, 1, 2, 3, 4, 5]
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	for e: int in order:
		if _run_event(e):
			return
	event_t = 30.0


## La casata in testa: più castelli, a parità più soldati. Gli eventi cattivi toccano a lei.
func _leader() -> int:
	var best := -1
	var bs := -1
	var counts := {}
	for c: Dictionary in castles:
		counts[c.owner] = int(counts.get(c.owner, 0)) + 1
	var troops := {}
	for u: U in ulist:
		troops[u.team] = int(troops.get(u.team, 0)) + 1
	for t in Defs.HOUSE_COUNT:
		if t == Defs.NEUTRAL or not houses[t].alive:
			continue
		var sc: int = int(counts.get(t, 0)) * 1000 + int(troops.get(t, 0))
		if sc > bs:
			bs = sc
			best = t
	return best


func _field(u: U) -> bool:
	return u.hp > 0.0 and not u.water and not u.garrison and u.team != Defs.NEUTRAL and u.inside_own < 0 and u.inside_enemy < 0 and u.feast <= 0.0


func _run_event(e: int) -> bool:
	var ev: Array = Defs.EVENTS[e]
	_cur_event = e
	match e:
		0:  # sagra: dove c'è più gente in campo, tutti (di ogni casata) vanno a mangiare
			var field: Array = []
			for u: U in ulist:
				if _field(u):
					field.append(u)
			if field.size() < 8:
				return false
			var best: U = null
			var bn := 0
			for k in 12:
				var cand: U = field[rng.randi() % field.size()]
				var n := 0
				for o: U in field:
					if o.pos.distance_squared_to(cand.pos) < 45.0 * 45.0:
						n += 1
				if n > bn:
					bn = n
					best = cand
			if bn < 6:
				return false
			var spot := best.pos
			spot.y = world.top_y(int(spot.x), int(spot.z))
			var said := 0
			for o: U in field:
				if o.pos.distance_squared_to(spot) < 55.0 * 55.0:
					var ang := rng.randf() * TAU
					o.feast = rng.randf_range(16.0, 20.0)
					o.feast_pos = spot + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(3.0, 7.0)
					o.tgt = null
					if said < 3 and rng.randf() < 0.3:
						said += 1
						_say(o, Defs.SAY_SAGRA, true)
			game.fx_all("porchetta", spot, 22.0)
			_banner(ev[0], ev[1], spot, 20.0)
		1:  # sciopero: il tipo più numeroso della casata in testa si siede
			var lead := _leader()
			if lead < 0:
				return false
			var per := {}
			for u: U in ulist:
				if u.team == lead and u.hp > 0.0 and not _is_siege(u) and u.type != Defs.FRATE and not u.water:
					per[u.type] = int(per.get(u.type, 0)) + 1
			var ty := -1
			var tn := 4
			for t: int in per:
				if int(per[t]) > tn:
					tn = int(per[t])
					ty = t
			if ty < 0:
				return false
			var said := 0
			var where := Vector3.ZERO
			for u: U in ulist:
				if u.team == lead and u.type == ty:
					u.sleep = 20.0
					u.has_order = false
					u.goal = -1
					u.tgt = null
					where = u.pos
					if said < 3 and rng.randf() < 0.4:
						said += 1
						_say(u, Defs.SAY_SCIOPERO, true)
			var plural: String = {Defs.FANTE: "fanti", Defs.BALESTRIERE: "balestrieri", Defs.CAVALIERE: "cavalieri", Defs.NONNA: "nonne", Defs.MENESTRELLO: "menestrelli"}.get(ty, "soldati")
			_banner(ev[0], String(ev[1]).format({"u": plural, "c": _hname(lead)}), where, 20.0)
		2:  # la mamma chiama: metà dell'armata in campo della casata in testa torna al castello
			var lead := _leader()
			if lead < 0:
				return false
			var mine: Array = []
			for u: U in ulist:
				if u.team == lead and _field(u) and not _is_siege(u):
					mine.append(u)
			if mine.size() < 6:
				return false
			var said := 0
			for k in mine.size():
				if k % 2 == 1:
					continue
				var u: U = mine[k]
				var home := _nearest_own_castle(u)
				if home.is_empty():
					continue
				u.feast = 15.0
				u.feast_pos = home.gate_out
				u.tgt = null
				if said < 3 and rng.randf() < 0.3:
					said += 1
					_say(u, Defs.SAY_MAMMA, true)
			_banner(ev[0], String(ev[1]).format({"c": _hname(lead)}), (mine[0] as U).pos, 15.0)
		3:  # processione: niente poteri per nessuno
			procession_until = time + 25.0
			_banner(ev[0], ev[1], castles[7].center, 25.0)  # la processione sfila da Roma
		4:  # palio: i cavalieri in campo di almeno due casate corrono al traguardo
			var riders: Array = []
			var teams := {}
			var sum := Vector3.ZERO
			for u: U in ulist:
				if u.type == Defs.CAVALIERE and _field(u) and u.sleep <= 0.0:
					riders.append(u)
					teams[u.team] = true
					sum += u.pos
			if riders.size() < 3 or teams.size() < 2:
				return false
			# traguardo lontano da tutti, così la corsa dura qualche secondo e si guarda
			var mid := sum / riders.size()
			var fin := Vector3(0, -1, 0)
			for k in 16:
				var ang := rng.randf() * TAU
				var cand := mid + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(80.0, 110.0)
				if cand.x < 20 or cand.z < 20 or cand.x > Defs.WX - 20 or cand.z > Defs.WZ - 20:
					continue
				cand.y = world.top_y(int(cand.x), int(cand.z))
				if cand.y > Defs.SEA + 0.5 and castle_at(cand, 8.0) < 0:
					fin = cand
					break
			if fin.y < 0.0:
				return false
			palio_pos = fin
			palio_until = time + 45.0
			var said := 0
			for u: U in riders:
				u.feast = 45.0
				u.feast_pos = fin
				u.tgt = null
				if said < 3 and rng.randf() < 0.35:
					said += 1
					_say(u, Defs.SAY_PALIO, true)
			game.fx_all("palio", fin, 45.0)
			_banner(ev[0], ev[1], fin, 45.0)
		5:  # scomunica: la casata in testa resta senza Fede per un po'
			var lead := _leader()
			if lead < 0:
				return false
			houses[lead].excom_until = time + 40.0
			var seat := Vector3.ZERO
			for c: Dictionary in castles:
				if int(c.owner) == lead:
					seat = c.center
					break
			_banner(ev[0], String(ev[1]).format({"c": _hname(lead)}), seat, 40.0)
	return true


## Pannello debug: fa partire un evento adesso. Se in campo mancano i soldati che servono,
## li schiera fuori dal primo castello di chi gioca e riprova.
func debug_event(e: int, house: int) -> bool:
	if _run_event(e):
		return true
	var c: Dictionary = {}
	for k: Dictionary in castles:
		if int(k.owner) == house:
			c = k
			break
	if c.is_empty():
		c = castles[0]
	var base: Vector3 = (c.gate_out as Vector3) + (c.dir as Vector3) * 34.0
	var teams := [house, _leader(), (house + 1) % Defs.HOUSE_COUNT]
	for i in teams.size():
		if int(teams[i]) < 0:
			continue
		for k in 8:
			var ty := Defs.CAVALIERE if k < 3 else Defs.FANTE
			var p := base + Vector3(float(i) * 8.0 - 8.0 + float(k % 4) * 1.6, 0.0, float(k / 4) * 1.6)
			p.y = world.top_y(int(p.x), int(p.z))
			spawn_unit(ty, int(teams[i]), p)
	return _run_event(e)


func _palio_win(u: U) -> void:
	palio_until = 0.0
	houses[u.team].gold = float(houses[u.team].gold) + Defs.PALIO_PRIZE
	for o: U in ulist:
		if o.feast > 0.0 and o.feast_pos == palio_pos:
			o.feast = 0.01
	_say(u, Defs.SAY_VITTORIA, true)
	game.fx_all("palio_end", palio_pos, float(u.team))
	_banner("%s vince il Palio!" % _hname(u.team), "Il cavaliere arriva primo: %d fiorini alla casata" % int(Defs.PALIO_PRIZE), palio_pos)


func _nearest_own_castle(u: U) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e12
	for c: Dictionary in castles:
		if int(c.owner) != u.team:
			continue
		var d := (c.center as Vector3).distance_squared_to(u.pos)
		if d < bd:
			bd = d
			best = c
	return best


## life: per quanti secondi resta l'icona che porta sull'evento; 0 = chiude quella già aperta in p.
func _banner(title: String, sub: String, p: Vector3, life := 0.0) -> void:
	var picks := PackedInt32Array()
	if life > 0.0:
		news_t = NEWS_TIME
		news_read.clear()
		while picks.size() < NEWS_ITEMS:
			var k := rng.randi() % News.HEADLINES.size()
			if not picks.has(k):
				picks.append(k)
	game.banner_all(title, sub, p, life, _cur_event, picks)


## In tregua un potere non può cadere vicino ai castelli o ai soldati di un'altra casata.
func _truce_target(team: int, p: Vector3) -> bool:
	for c: Dictionary in castles:
		if at_peace(team, int(c.owner)) and Vector2((c.center as Vector3).x - p.x, (c.center as Vector3).z - p.z).length() < R + 40.0:
			return true
	for u: U in ulist:
		if at_peace(team, u.team) and u.hp > 0.0 and Vector2(u.pos.x - p.x, u.pos.z - p.z).length() < 36.0:
			return true
	return false
