class_name Music
extends Node
## Musica di sottofondo: una taverna tranquilla nel menu, tre brani allegri a rotazione in partita
## e la fanfara di tuba per chi vince, seguita dal banchetto. Brani CC0, vedi assets/music/CREDITS.md.
## Si spegne dalle impostazioni («Musica»); il volume segue quello generale.

static var me: Music

const MENU := "res://assets/music/menu_old_tower_inn.mp3"
const GAME := ["res://assets/music/game_market_day.mp3", "res://assets/music/game_minstrel_dance.mp3", "res://assets/music/game_kings_feast.mp3"]
const VICTORY := "res://assets/music/victory_tuba.ogg"
const BANQUET := "res://assets/music/game_kings_feast.mp3"
## La musica sta sotto ai suoni: si devono sentire i crolli e le mucche.
const VOL_DB := -11.0
const FADE := 1.2

var _player: AudioStreamPlayer
var _playlist: Array = []
var _k := 0
var _tw: Tween


func _ready() -> void:
	me = self
	_player = AudioStreamPlayer.new()
	_player.volume_db = VOL_DB
	add_child(_player)
	_player.finished.connect(_next)


func _exit_tree() -> void:
	if me == self:
		me = null


func menu() -> void:
	_playlist = [MENU]
	_k = 0
	_play(MENU)


func game() -> void:
	_playlist = GAME.duplicate()
	_k = randi() % _playlist.size()
	_play(_playlist[_k])


## Chi vince: tuba allegra, poi il banchetto.
func victory() -> void:
	_playlist = [BANQUET]
	_k = 0
	_play(VICTORY, false)


func refresh() -> void:
	if not Settings.music:
		_player.stop()
	elif not _player.playing and not _playlist.is_empty():
		_play(_playlist[_k])


func _next() -> void:
	if _playlist.is_empty():
		return
	if _player.stream != null and String(_player.stream.resource_path) == VICTORY:
		_play(_playlist[0])
		return
	_k = (_k + 1) % _playlist.size()
	_play(_playlist[_k])


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
