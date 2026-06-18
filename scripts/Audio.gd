extends Node
## Procedural SFX + adaptive music — port of the WebAudio synth (playTone /
## playNoise / SFX / startMusic / updateMusic). Buffers are generated at runtime
## as AudioStreamWAV and played through a round-robin pool of players.

const RATE := 44100
var _pool: Array[AudioStreamPlayer] = []
var _idx := 0
var _cache := {}
var enabled := true
var music_enabled := true

# music state
var music_on := false
var intensity := 0.0
var _arp_step := 0
var _arp_t := 0.0
var _bass_t := 0.0
var combo_provider: Callable = Callable()

func _ready() -> void:
	for i in 18:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

func _process(dt: float) -> void:
	if not music_on or not music_enabled:
		return
	var combo := 1
	if combo_provider.is_valid():
		combo = combo_provider.call()
	var target: float = clamp((combo - 1) / 15.0, 0.0, 1.0)
	intensity += (target - intensity) * 0.05
	# arp — pentatonic, eighth notes ~240bpm
	_arp_t -= dt
	if _arp_t <= 0:
		_arp_t = 0.25
		var notes := [220.0, 262.0, 294.0, 330.0, 392.0, 440.0, 523.0]
		var n: float = notes[_arp_step % notes.size()]
		_arp_step += 1
		_play_buf(_tone(n, 0.3, "sine", 0.02 + intensity * 0.04, 0.0))
	# bass — pitch steps with intensity
	_bass_t -= dt
	if _bass_t <= 0:
		_bass_t = 1.0
		var bass := [55.0, 65.0, 73.0, 82.0]
		var bi: int = int(intensity * (bass.size() - 0.01))
		_play_buf(_tone(bass[bi], 1.0, "triangle", 0.05 + intensity * 0.05, 0.0))

# ------------------------------------------------------------
# buffer generation
# ------------------------------------------------------------
func _tone(freq: float, dur: float, type: String, vol: float, slide: float) -> AudioStreamWAV:
	var key := "t_%d_%d_%s_%d_%d" % [int(freq), int(dur * 1000), type, int(vol * 1000), int(slide)]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var end_freq: float = max(40.0, freq + slide)
	for i in n:
		var tf: float = float(i) / max(1, n)
		var f: float = freq * pow(end_freq / freq, tf) if freq > 0 else freq
		phase += TAU * f / RATE
		var s := _osc(type, phase)
		# envelope: 5ms attack, exp decay to ~0.001
		var env: float
		var atk := 0.005 * RATE
		if i < atk:
			env = vol * (i / atk)
		else:
			env = vol * pow(0.001 / max(vol, 0.0001), tf)
		var v := int(clamp(s * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	_cache[key] = _wav(data)
	return _cache[key]

func _noise(dur: float, vol: float, filter_freq: float) -> AudioStreamWAV:
	var key := "n_%d_%d_%d" % [int(dur * 1000), int(vol * 1000), int(filter_freq)]
	if _cache.has(key): return _cache[key]
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	var a: float = 1.0 - exp(-TAU * filter_freq / RATE)
	for i in n:
		var x := randf() * 2.0 - 1.0
		y += a * (x - y)
		var env: float = vol * pow(0.001 / max(vol, 0.0001), float(i) / max(1, n))
		var v := int(clamp(y * env, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	_cache[key] = _wav(data)
	return _cache[key]

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _osc(type: String, ph: float) -> float:
	match type:
		"square": return 1.0 if sin(ph) >= 0.0 else -1.0
		"triangle": return asin(sin(ph)) * 2.0 / PI
		"sawtooth": return 2.0 * (fposmod(ph, TAU) / TAU) - 1.0
		_: return sin(ph)

func _play_buf(stream: AudioStreamWAV, delay := 0.0) -> void:
	if not enabled: return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var p := _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	p.stream = stream
	p.play()

func _tone_d(freq: float, dur: float, type: String, vol: float, slide: float, delay: float) -> void:
	_play_buf(_tone(freq, dur, type, vol, slide), delay)

# ------------------------------------------------------------
# SFX (mirrors the SFX table)
# ------------------------------------------------------------
func shoot(w: String) -> void:
	match w:
		"lance": _play_buf(_tone(1200, 0.08, "sawtooth", 0.04, -600))
		"spread": _play_buf(_tone(660, 0.06, "square", 0.05, -200))
		"singularity":
			_play_buf(_tone(80, 0.3, "sine", 0.08, 40)); _play_buf(_noise(0.2, 0.04, 200))
		_: _play_buf(_tone(880, 0.05, "square", 0.04, -400))

func hit() -> void: _play_buf(_tone(220, 0.06, "square", 0.06, -100))
func kill() -> void:
	_play_buf(_tone(660, 0.08, "triangle", 0.07, 200)); _play_buf(_noise(0.06, 0.04, 1200))
func dash() -> void: _play_buf(_noise(0.12, 0.05, 2400))
func damage() -> void:
	_play_buf(_tone(110, 0.2, "sawtooth", 0.1, -50)); _play_buf(_noise(0.15, 0.08, 400))
func rewind() -> void:
	for i in 5: _tone_d(440 + i * 220, 0.06, "sine", 0.06, -100, i * 0.05)
func echo_phase() -> void:
	_play_buf(_tone(523, 0.1, "sine", 0.08, 0)); _tone_d(659, 0.1, "sine", 0.08, 0, 0.08); _tone_d(784, 0.15, "sine", 0.08, 0, 0.16)
func wave_start() -> void:
	_play_buf(_tone(330, 0.08, "triangle", 0.06, 0)); _tone_d(440, 0.1, "triangle", 0.06, 0, 0.1)
func boss_warn() -> void:
	for i in 3: _tone_d(165, 0.15, "sawtooth", 0.08, 0, i * 0.25)
func boss_hit() -> void: _play_buf(_tone(180, 0.06, "square", 0.05, 60))
func boss_shoot() -> void: _play_buf(_tone(150, 0.08, "sawtooth", 0.05, -50))
func boss_kill() -> void:
	_play_buf(_tone(440, 0.15, "triangle", 0.1, 0)); _tone_d(554, 0.15, "triangle", 0.1, 0, 0.1); _tone_d(659, 0.3, "triangle", 0.1, 0, 0.2)
func pickup() -> void:
	_play_buf(_tone(880, 0.05, "sine", 0.06, 0)); _tone_d(1320, 0.05, "sine", 0.06, 0, 0.04)
func weapon_swap() -> void:
	_play_buf(_tone(440, 0.04, "sine", 0.05, 0)); _tone_d(660, 0.05, "sine", 0.06, 0, 0.03)

func start_music(provider: Callable) -> void:
	combo_provider = provider
	music_on = true

func stop_music() -> void:
	music_on = false
