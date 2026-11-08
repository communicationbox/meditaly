class_name Sfx
extends Node3D
## Effetti sonori: file CC0 in res://assets/sfx (nome_1.wav, nome_2.wav… = varianti scelte a caso,
## vedi CREDITS.md lì). Se un suono manca resta quello sintetizzato a runtime.

const RATE := 22050
static var cache: Dictionary = {}
var pool: Array[AudioStreamPlayer3D] = []
var pool_i := 0


func _ready() -> void:
	for k in 18:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 45.0
		p.max_distance = 700.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		pool.append(p)
	if cache.is_empty():
		var r := RandomNumberGenerator.new()
		r.seed = 7
		cache["boom"] = _noise_hit(r, 0.8, 0.12, 2.0, 260.0)
		cache["boom_big"] = _noise_hit(r, 1.5, 0.09, 1.0, 180.0)
		cache["crash"] = _noise_hit(r, 1.0, 0.25, 3.0, 800.0)
		cache["hit"] = _noise_hit(r, 0.14, 0.5, 18.0, 2600.0)
		cache["whoosh"] = _whoosh(r)
		cache["cannon"] = _noise_hit(r, 0.7, 0.2, 3.5, 700.0)
		cache["moo"] = _moo()
		cache["boing"] = _boing()
		cache["quake"] = _noise_hit(r, 3.2, 0.05, 0.3, 90.0)
		cache["horn"] = _horn()
		_load_files()


const SFX_DIR := "res://assets/sfx/"
const FILES := ["boom", "boom_big", "cannon", "crash", "hit", "moo", "boing", "quake", "horn", "voice", "bell"]
## Volume di ogni file rispetto al sintetizzato che sostituisce (i file sono normalizzati al massimo).
const FILE_DB := {"hit": -8.0, "crash": -4.0, "voice": -6.0, "moo": -2.0, "boing": -3.0, "bell": -4.0}


static func _load_files() -> void:
	for n: String in FILES:
		var list: Array = []
		for k in range(1, 10):
			var path := "%s%s_%d.wav" % [SFX_DIR, n, k]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		if not list.is_empty():
			cache[n] = list


func play(name_: String, at: Vector3, vol_db := 0.0, pitch_var := 0.12) -> void:
	if not cache.has(name_):
		return
	var p := pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	var st: Variant = cache[name_]
	if st is Array:
		p.stream = (st as Array)[randi() % (st as Array).size()]
		vol_db += float(FILE_DB.get(name_, 0.0))
	else:
		p.stream = st
	p.global_position = at
	p.volume_db = vol_db
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s


## Rumore filtrato passa-basso con decadimento esponenziale: esplosioni e colpi.
static func _noise_hit(r: RandomNumberGenerator, dur: float, attack_mix: float, decay: float, cutoff: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var a := clampf(TAU * cutoff / RATE, 0.0, 1.0)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * (1.0 - t / dur)
		var c := a * (1.0 + 6.0 * exp(-t * 18.0))
		lp += clampf(c, 0.0, 1.0) * (r.randf_range(-1, 1) - lp)
		var thump := sin(TAU * 55.0 * t * exp(-t * 2.0)) * exp(-t * 7.0) * 0.7
		out[i] = (lp * 1.6 + thump + r.randf_range(-1, 1) * attack_mix * exp(-t * 40.0)) * env
	return _to_stream(out)


static func _whoosh(r: RandomNumberGenerator) -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += 0.12 * (r.randf_range(-1, 1) - lp)
		out[i] = lp * sin(t * PI) * 1.4 + sin(TAU * 90.0 * t * 0.5) * exp(-t * 16.0) * 0.5
	return _to_stream(out)


static func _moo() -> AudioStreamWAV:
	var n := int(1.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := 135.0 + 45.0 * sin(t * PI) + 3.0 * sin(t * 55.0)
		ph += f / RATE
		var saw := 2.0 * fmod(ph, 1.0) - 1.0
		var form := saw * 0.6 + sin(TAU * ph * 2.0) * 0.25 + sin(TAU * ph * 3.0) * 0.15
		out[i] = form * smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.7, t) * 0.7
	return _to_stream(out)


static func _boing() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += (140.0 + 180.0 * t + sin(t * 30.0) * 40.0) / RATE
		out[i] = sin(TAU * ph) * exp(-t * 3.5) * 0.7
	return _to_stream(out)


static func _horn() -> AudioStreamWAV:
	var n := int(1.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [261.6, 329.6, 392.0, 523.2]
	for i in n:
		var t := float(i) / RATE
		var idx := mini(int(t / 0.26), 3)
		var f: float = notes[idx]
		var local := t - idx * 0.26
		var s := 0.0
		for h in range(1, 6):
			s += sin(TAU * f * h * t) / h
		var env := minf(local * 25.0, 1.0) * (exp(-local * 1.2) if idx == 3 else 0.9)
		out[i] = s * env * 0.35
	return _to_stream(out)
