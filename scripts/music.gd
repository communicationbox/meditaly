class_name Music
extends Node
## Musica di sottofondo in stile Tre-Quattrocento. Ogni brano ha il suo momento, niente rotazione a caso:
##   menu      → The Old Tower Inn (taverna tranquilla)
##   calma     → Thatched Villagers (tregua e momenti tranquilli: si costruisce)
##   partita   → Enchanted Festival (cornamusa e zufolo, festa da giullari)
##   battaglia → Minstrel Guild (il più veloce: un tuo castello attaccato, o tu che ne prendi uno)
##   conquista → Rejoicing, una volta, poi si torna al brano del momento
##   vittoria  → Victory Theme, poi The Medieval Banquet per il banchetto del finale
##   re caduto → «dun dun DUUUN» se era il tuo castello, tuba triste se era di un altro
## Brani CC0 e CC-BY: autori in assets/music/CREDITS.md e nella schermata «Crediti» del menu.

static var me: Music

const MENU := "res://assets/music/menu_old_tower_inn.mp3"
const MOODS := {
	"calma": "res://assets/music/game_thatched_villagers.mp3",
	"partita": "res://assets/music/game_enchanted_festival.mp3",
	"battaglia": "res://assets/music/game_minstrel_guild.mp3",
}
const CONQUEST := "res://assets/music/game_rejoicing.mp3"
const VICTORY := "res://assets/music/victory_medieval.mp3"
const BANQUET := "res://assets/music/game_medieval_banquet.mp3"
const STING_MINE := "res://assets/music/sting_der_kleber.mp3"
const STING_THEIRS := "res://assets/music/sting_tuba_sad.ogg"
## La musica sta sotto ai suoni: si devono sentire i crolli e le mucche.
const VOL_DB := -11.0
const FADE := 1.2
## Finito lo scontro la musica di battaglia resta ancora un po': niente salti avanti e indietro.
const BATTLE_HOLD := 10.0

var _player: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _tw: Tween
var _loop := ""  # il brano che torna quando finisce (quello del momento)
var _once := false  # sta suonando un brano da una volta sola (conquista, vittoria)
var _mood := ""
var _battle_until := 0.0


func _ready() -> void:
	me = self
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOL_DB
	add_child(_player)
	_player.finished.connect(_finished)
	_sting = AudioStreamPlayer.new()
	_sting.volume_db = -4.0
	add_child(_sting)


func _exit_tree() -> void:
	if me == self:
		me = null


func menu() -> void:
	_mood = ""
	_once = false
	_loop = MENU
	_play(MENU)


## Si entra in partita: si comincia tranquilli.
func game() -> void:
	_mood = ""
	_once = false
	mood("calma")


## Il momento della partita, deciso dall'interfaccia: calma (tregua), partita o battaglia.
## battle = c'è uno scontro adesso; la battaglia resta BATTLE_HOLD secondi dopo l'ultimo.
func update(truce: bool, battle: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if battle:
		_battle_until = now + BATTLE_HOLD
	var want := "battaglia" if now < _battle_until else ("calma" if truce else "partita")
	mood(want)


func mood(m: String) -> void:
	if m == _mood or not MOODS.has(m):
		return
	_mood = m
	_loop = MOODS[m]
	if not _once:
		_play(_loop)


## Hai preso un castello: Rejoicing una volta, poi si torna al brano del momento.
func conquest() -> void:
	_once = true
	_play(CONQUEST)


## Chi vince: il tema della vittoria, poi il banchetto.
func victory() -> void:
	_once = true
	_mood = "fine"
	_loop = BANQUET
	_play(VICTORY, false)


## Il re è caduto: un motivetto sopra la musica, che intanto si fa da parte.
func sting(mine: bool) -> void:
	if not Settings.music or DisplayServer.get_name() == "headless" or _sting.playing:
		return
	var st := load(STING_MINE if mine else STING_THEIRS) as AudioStream
	if st == null:
		return
	_sting.stream = st
	_sting.play()
	if _player.playing:
		var tw := create_tween()
		tw.tween_property(_player, "volume_db", VOL_DB - 18.0, 0.2)
		tw.tween_interval(maxf(st.get_length() - 0.2, 0.5))
		tw.tween_property(_player, "volume_db", VOL_DB, 1.0)


func refresh() -> void:
	if not Settings.music:
		_player.stop()
		_sting.stop()
	elif not _player.playing and _loop != "":
		_play(_loop)


func _finished() -> void:
	_once = false
	if _loop != "":
		_play(_loop, false)


func _play(path: String, fade := true) -> void:
	if not Settings.music or DisplayServer.get_name() == "headless":
		return
	var st := load(path) as AudioStream
	if st == null:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if fade and _player.playing:
		_tw = create_tween()
		_tw.tween_property(_player, "volume_db", -40.0, FADE * 0.5)
		_tw.tween_callback(func() -> void: _start(st, true))
	else:
		_start(st, fade)


func _start(st: AudioStream, fade: bool) -> void:
	_player.stream = st
	_player.volume_db = -40.0 if fade else VOL_DB
	_player.play()
	if fade:
		_tw = create_tween()
		_tw.tween_property(_player, "volume_db", VOL_DB, FADE)
