extends Node
## Autoload `Game`: settings (graphics quality, sound, mouse, player name and planeswalker),
## fonts, the shared materials and the sound effects, all generated in code.

signal quality_changed
signal settings_changed

enum { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["Low", "Medium", "High"]
const SETTINGS_PATH := "user://settings.cfg"

const TITLE := "Planeswalker Arena"
const TAGLINE := "Every spark burns. Only one shines."

const GOLD := Color(0.98, 0.78, 0.4)
const PALE := Color(0.95, 0.93, 0.88)
const AETHER := Color(0.45, 0.85, 1.0)
const BAD := Color(1.0, 0.42, 0.36)
const GOOD := Color(0.5, 1.0, 0.55)

var quality := MEDIUM
var quality_chosen := false
var muted := false
var music_on := true
var sensitivity := 1.0
var invert := false
var fov := 95.0
var player_name := "Planeswalker"
var walker := "chandra"
var web := false
var testing := false
var font_title: FontVariation
var font_title_bold: FontVariation
var font_body: Font
var font_bold: Font
var mat_world: ShaderMaterial        # arena geometry: vertex colour times a world-space pattern
var mat_solid: StandardMaterial3D    # characters, weapons, props
var mat_glow: ShaderMaterial
var mat_gloss: ShaderMaterial
var mat_fx: StandardMaterial3D       # additive effects (beams, flashes, sparks)
var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _music_bus := 0
var _playlist: Array = []
var _playlist_at := 0
var _track_end := 0
var _music_tween: Tween

const MUSIC_DB := -12.0
const MUSIC_FADE := 1.2


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	web = OS.has_feature("web") or "--web" in args
	testing = "--autotest" in args or "--simtest" in args or "--lineup" in args
	quality = MEDIUM if web else HIGH
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		if cfg.has_section_key("video", "quality"):
			quality = clampi(int(cfg.get_value("video", "quality")), LOW, HIGH)
			quality_chosen = true
		muted = bool(cfg.get_value("audio", "muted", false))
		music_on = bool(cfg.get_value("audio", "music", true))
		sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 1.0)), 0.2, 4.0)
		invert = bool(cfg.get_value("input", "invert", false))
		fov = clampf(float(cfg.get_value("video", "fov", 95.0)), 70.0, 120.0)
		player_name = str(cfg.get_value("player", "name", player_name))
		var w := str(cfg.get_value("player", "walker", walker))
		if Data.WALKERS.has(w):
			walker = w
	for a in args:
		if a.begins_with("--quality="):
			quality = clampi(int(a.get_slice("=", 1)), LOW, HIGH)
			quality_chosen = true
	font_title = _font("res://fonts/Cinzel.ttf", 700)
	font_title_bold = _font("res://fonts/Cinzel.ttf", 900)
	font_body = load("res://fonts/AlegreyaSans-Regular.ttf")
	font_bold = load("res://fonts/AlegreyaSans-Bold.ttf")
	mat_world = ShaderMaterial.new()
	mat_world.shader = load("res://shaders/world.gdshader")
	mat_solid = StandardMaterial3D.new()
	mat_solid.vertex_color_use_as_albedo = true
	mat_solid.roughness = 0.7
	mat_solid.metallic_specular = 0.45
	mat_glow = ShaderMaterial.new()
	mat_glow.shader = load("res://shaders/glow.gdshader")
	mat_gloss = ShaderMaterial.new()
	mat_gloss.shader = load("res://shaders/gloss.gdshader")
	mat_fx = StandardMaterial3D.new()
	mat_fx.vertex_color_use_as_albedo = true
	mat_fx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fx.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_fx.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fx.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_fx.no_depth_test = false
	mat_fx.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_setup_input()
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_sounds()
	AudioServer.set_bus_mute(0, muted)
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus < 0:
		_music_bus = 0
	AudioServer.set_bus_mute(_music_bus, not music_on)
	AudioServer.set_bus_volume_db(_music_bus, MUSIC_DB)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _setup_input() -> void:
	var keys := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "scores": [KEY_TAB], "pause": [KEY_ESCAPE, KEY_F10], "quality": [KEY_L], "mute": [KEY_M],
		"next_weapon": [KEY_E], "prev_weapon": [KEY_Q], "last_weapon": [KEY_R], "zoom": [KEY_Z]}
	for i in 7:
		keys["weapon_%d" % (i + 1)] = [KEY_1 + i]
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for pair in [["fire", MOUSE_BUTTON_LEFT], ["zoom", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0], 0.2)
		var m := InputEventMouseButton.new()
		m.button_index = pair[1]
		InputMap.action_add_event(pair[0], m)


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {"wght": weight}
	return f


## Points the glossy reflections at an arena's sky.
func set_sky(top: Color, horizon: Color, ground: Color) -> void:
	mat_gloss.set_shader_parameter("sky_top", top)
	mat_gloss.set_shader_parameter("sky_horizon", horizon)
	mat_gloss.set_shader_parameter("sky_ground", ground)


func set_quality(q: int, save := true) -> void:
	quality = clampi(q, LOW, HIGH)
	if save:
		quality_chosen = true
		save_settings()
	quality_changed.emit()


func cycle_quality() -> void:
	set_quality((quality + 1) % 3)


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	save_settings()


func toggle_music() -> void:
	music_on = not music_on
	AudioServer.set_bus_mute(_music_bus, not music_on)
	save_settings()


func set_player(n: String, w: String) -> void:
	n = n.strip_edges().substr(0, 16)
	player_name = n if n != "" else "Planeswalker"
	if Data.WALKERS.has(w):
		walker = w
	save_settings()


func save_settings() -> void:
	settings_changed.emit()
	if testing:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	if quality_chosen:
		cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("input", "invert", invert)
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "walker", walker)
	cfg.save(SETTINGS_PATH)


# --- sound ---------------------------------------------------------------------------

func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not sounds.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 45:
		return
	_last_played[name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = sounds[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## A sound from a point in the arena: quieter with distance from the listener.
func play_at(name: String, pos: Vector3, listener: Vector3, vol_db := 0.0) -> void:
	var d := pos.distance_to(listener)
	if d > 70.0:
		return
	play(name, vol_db - d * 0.35, 1.0)


# --- music -----------------------------------------------------------------------------
# Tracks are music/<name>.ogg, made by tools/gen_music.py.

func play_music(tracks: Array) -> void:
	if tracks == _playlist or "--simtest" in OS.get_cmdline_user_args():
		return
	var ok := []
	for t in tracks:
		if ResourceLoader.exists("res://music/%s.ogg" % t):
			ok.append(t)
	if ok.is_empty():
		return
	_playlist = tracks
	_playlist = ok
	_playlist_at = 0
	if _music.playing:
		_fade(-50.0, MUSIC_FADE * 0.6).tween_callback(_start_track)
	else:
		_start_track()


func _start_track() -> void:
	var stream: AudioStreamOggVorbis = load("res://music/%s.ogg" % _playlist[_playlist_at])
	stream.loop = _playlist.size() == 1
	_track_end = Time.get_ticks_msec() + int(stream.get_length() * 1000.0)
	AudioServer.set_bus_volume_db(_music_bus, -50.0)
	_music.stream = stream
	_music.play()
	_fade(MUSIC_DB, MUSIC_FADE)


func _fade(db: float, time: float) -> Tween:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_method(func(v: float): AudioServer.set_bus_volume_db(_music_bus, v),
			AudioServer.get_bus_volume_db(_music_bus), db, time)
	return _music_tween


func _process(_delta: float) -> void:
	if _playlist.size() > 1 and Time.get_ticks_msec() > _track_end:
		_playlist_at = (_playlist_at + 1) % _playlist.size()
		_start_track()


func make_wav(dur: float, gen: Callable, rate := 22050, curve := 1.6) -> AudioStreamWAV:
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var p := float(i) / n
		var env := pow(1.0 - p, curve) * minf(1.0, i / 40.0)
		var v: float = gen.call(float(i) / rate, p) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


func _noise(cut: float) -> Callable:
	var st := [0.0]
	return func(_t: float, _p: float) -> float:
		st[0] += (randf() * 2.0 - 1.0 - st[0]) * cut
		return st[0] / sqrt(cut) * 0.5


func _build_sounds() -> void:
	if "--simtest" in OS.get_cmdline_user_args():
		return
	var n := [_noise(0.6), _noise(0.05), _noise(0.3), _noise(0.9), _noise(0.02), _noise(0.15), _noise(0.4), _noise(0.7)]
	sounds["blade"] = make_wav(0.22, func(t, p): return n[0].call(t, p) * 0.35 + sin(TAU * (900.0 - 500.0 * p) * t) * 0.25)
	sounds["repeater"] = make_wav(0.09, func(t, p): return n[3].call(t, p) * 0.35 + signf(sin(TAU * (1500.0 - 700.0 * p) * t)) * 0.12)
	sounds["thunder"] = make_wav(0.55, func(t, p): return n[1].call(t, p) * 1.7 + sin(TAU * (120.0 - 60.0 * p) * t) * 0.5, 22050, 2.2)
	sounds["pulse"] = make_wav(0.16, func(t, p): return sin(TAU * (1100.0 - 600.0 * p) * t) * 0.3 + sin(TAU * (2200.0 - 1200.0 * p) * t) * 0.1)
	sounds["lash"] = make_wav(0.12, func(t, p): return (n[3].call(t, p) * 0.4 + sin(TAU * 95.0 * t) * 0.25) * (0.6 + 0.4 * sin(TAU * 60.0 * t)), 22050, 0.3)
	sounds["fireball"] = make_wav(0.5, func(t, p): return n[2].call(t, p) * 0.7 * (1.0 - p) + sin(TAU * (220.0 - 120.0 * p) * t) * 0.15)
	sounds["disintegrate"] = make_wav(0.9, func(t, p): return sin(TAU * (1800.0 - 1500.0 * sqrt(p)) * t) * 0.3 + n[0].call(t, p) * 0.25 + sin(TAU * 70.0 * t) * 0.3, 22050, 1.3)
	sounds["boom"] = make_wav(1.0, func(t, p): return n[4].call(t, p) * 2.2 + sin(TAU * (70.0 - 40.0 * p) * t) * 0.6, 22050, 2.0)
	sounds["pop"] = make_wav(0.25, func(t, p): return n[5].call(t, p) * 0.8 + sin(TAU * (500.0 - 300.0 * p) * t) * 0.2)
	sounds["hit"] = make_wav(0.12, func(t, _p): return sin(TAU * 1400.0 * t) * 0.35 + sin(TAU * 2100.0 * t) * 0.12)
	sounds["pain"] = make_wav(0.25, func(t, p): return n[6].call(t, p) * 0.5 + sin(TAU * (260.0 - 90.0 * p) * t + sin(TAU * 7.0 * t) * 2.0) * 0.3)
	sounds["death"] = make_wav(0.8, func(t, p): return n[5].call(t, p) * 0.6 + sin(TAU * (300.0 - 220.0 * p) * t) * 0.35, 22050, 1.2)
	sounds["frag"] = make_wav(0.5, func(t, p): return sin(TAU * (660.0 if p < 0.4 else 990.0) * t) * 0.25)
	sounds["jump"] = make_wav(0.12, func(t, p): return n[6].call(t, p) * 0.2 * (1.0 - p))
	sounds["land"] = make_wav(0.1, func(t, p): return n[1].call(t, p) * 0.5)
	sounds["pad"] = make_wav(0.6, func(t, p): return sin(TAU * (200.0 + 700.0 * p) * t) * 0.3 + n[2].call(t, p) * 0.2)
	sounds["teleport"] = make_wav(0.7, func(t, p): return sin(TAU * (1200.0 - 900.0 * p) * t + sin(TAU * 13.0 * t) * 3.0) * 0.25)
	sounds["health"] = make_wav(0.4, func(t, p): return sin(TAU * (523.3 if p < 0.5 else 784.0) * t) * 0.25)
	sounds["armor"] = make_wav(0.35, func(t, p): return sin(TAU * 330.0 * t) * 0.2 + n[7].call(t, p) * 0.15 + sin(TAU * 990.0 * t) * 0.1)
	sounds["weapon"] = make_wav(0.3, func(t, p): return signf(sin(TAU * (440.0 if p < 0.5 else 660.0) * t)) * 0.12 + n[5].call(t, p) * 0.2)
	sounds["power"] = make_wav(1.2, func(t, p): return (sin(TAU * 220.0 * t) + sin(TAU * 330.0 * t) * 0.6 + sin(TAU * 440.0 * (1.0 + p * 0.5) * t) * 0.4) * 0.2, 22050, 1.0)
	sounds["flag_taken"] = make_wav(0.9, func(t, p): return (sin(TAU * [523.3, 659.3, 784.0][mini(int(p * 3.0), 2)] * t)) * 0.28, 22050, 0.8)
	sounds["flag_capture"] = make_wav(1.6, func(t, p): return (sin(TAU * [392.0, 523.3, 659.3, 784.0, 1046.5][mini(int(p * 5.0), 4)] * t) * 0.3 + sin(TAU * 196.0 * t) * 0.1), 22050, 0.9)
	sounds["flag_return"] = make_wav(0.7, func(t, p): return sin(TAU * (784.0 if p < 0.5 else 523.3) * t) * 0.25)
	sounds["switch"] = make_wav(0.08, func(t, _p): return sin(TAU * 900.0 * t) * 0.2)
	sounds["click"] = make_wav(0.05, func(t, _p): return sin(TAU * 1200.0 * t) * 0.25)
	sounds["empty"] = make_wav(0.06, func(t, _p): return signf(sin(TAU * 300.0 * t)) * 0.1)
	sounds["respawn"] = make_wav(0.6, func(t, p): return sin(TAU * (300.0 + 500.0 * p) * t) * 0.22)
	sounds["win"] = make_wav(2.0, func(t, p): return (sin(TAU * [392.0, 523.3, 659.3, 784.0][mini(int(p * 5.0), 3)] * t) * 0.3 + sin(TAU * 196.0 * t) * 0.1))
	sounds["lose"] = make_wav(2.0, func(t, p): return (sin(TAU * [220.0, 207.7, 196.0, 146.8][mini(int(p * 4.0), 3)] * t) * 0.3))
	sounds["beep"] = make_wav(0.18, func(t, _p): return sin(TAU * 880.0 * t) * 0.25)
