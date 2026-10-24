extends Node
## Main: the screens around a match. The title shows a bot match behind the menu. From there:
## Play (a match against bots: mode, map, how many bots and how good, frag or capture limit and
## time), Multiplayer (open or join a room; the host picks the setup and how many bots fill it),
## Planeswalkers (pick who you play, with a turning model), Options, and How to play. In a match
## Esc (or losing the mouse) pauses. A finished match goes back to the title, or to the room.

var match_node: Match
var demo: Match
var ui_layer: CanvasLayer
var screen: Control
var play := {"mode": "ffa", "map": "foundry", "bots": 5, "skill": 1, "team": -1, "limit": 20, "minutes": 10}
var _pause: Control
var _fps_watch := -1.0
var _fps_frames := 0
var _slow_checked := false
var _preview: Fighter
var _preview_vp: SubViewport


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if "--simtest" in args:
		add_child(preload("res://scripts/simtest.gd").new())
		return
	for a in args:
		if a.begins_with("--mapshots="):
			add_child(preload("res://scripts/shots.gd").new())
			return
	_apply_quality()
	Game.quality_changed.connect(_apply_quality)
	get_tree().root.size_changed.connect(_apply_quality)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	Net.match_start.connect(_on_net_start)
	Net.lobby_changed.connect(func():
		if screen and screen.name == "Lobby":
			show_lobby())
	Net.left.connect(func(_reason: String):
		if match_node and match_node.online:
			_end_match_now()
		elif screen and screen.name == "Lobby":
			show_multiplayer())
	if "--autotest" in args:
		add_child(load("res://scripts/autotest.gd").new())
		return
	if Net.test_flag("host") != "" or Net.test_flag("join") != "":
		add_child(load("res://scripts/nettest.gd").new())
		return
	show_title()
	if Net.invite_code() != "":
		show_multiplayer()


func _apply_quality() -> void:
	# menus and the HUD draw at the window's own resolution; the 3D view at full resolution on
	# High, up to 1080 lines on Medium, up to 720 on Low
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var lines := float(maxi(root.size.y, 1))
	match Game.quality:
		Game.HIGH:
			root.scaling_3d_scale = 1.0
			root.msaa_3d = Viewport.MSAA_4X
		Game.MEDIUM:
			root.scaling_3d_scale = minf(1.0, 1080.0 / lines)
			root.msaa_3d = Viewport.MSAA_2X
		_:
			root.scaling_3d_scale = minf(1.0, 720.0 / lines)
			root.msaa_3d = Viewport.MSAA_DISABLED
	if screen and screen.has_meta("quality_button"):
		var b: Button = screen.get_meta("quality_button")
		if is_instance_valid(b):
			b.text = "Graphics: " + Game.QUALITY_NAMES[Game.quality]


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("quality"):
		Game.cycle_quality()
	elif e.is_action_pressed("mute"):
		Game.toggle_mute()
	elif e.is_action_pressed("pause") and match_node and not match_node.over:
		if _pause:
			_resume()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if match_node == null:
		return
	# losing the mouse (Esc in the browser, alt-tab) pauses
	if _pause == null and not match_node.over and not Game.testing and match_node.me >= 0 \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and match_node.warmup <= 0.0 \
			and DisplayServer.window_is_focused():
		_show_pause()
	# in the browser, drop to Low once if the first match starts slowly
	if Game.web and not Game.quality_chosen and not _slow_checked and Game.quality > Game.LOW and match_node.warmup <= 0.0:
		if _fps_watch < 0.0:
			_fps_watch = 0.0
			_fps_frames = 0
		_fps_watch += dt
		_fps_frames += 1
		if _fps_watch > 5.0:
			_slow_checked = true
			if _fps_frames / _fps_watch < 30.0:
				Game.set_quality(Game.LOW, false)


# --- matches -----------------------------------------------------------------------------

func _start_demo() -> void:
	if demo:
		return
	var mp: Dictionary = Maps.LIST[randi() % Maps.LIST.size()]
	var mode: String = mp.modes[randi() % mp.modes.size()]
	demo = Match.new()
	demo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(demo)
	demo.start({"mode": mode, "map": mp.id, "fighters": Net.make_fighters([], 8, 2, mode), "me": -1, "demo": true, "minutes": 30, "limit": 999})


func _stop_demo() -> void:
	if demo:
		demo.queue_free()
		demo = null


## cfg as Match.start takes it. Shared by Play, online matches and the tests.
func start_match(cfg: Dictionary) -> Match:
	_stop_demo()
	_clear_screen()
	_close_pause()
	if match_node:
		match_node.queue_free()
	match_node = Match.new()
	match_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(match_node)
	match_node.start(cfg)
	match_node.finished.connect(_on_match_finished)
	if cfg.get("online", false):
		Net.attach(match_node)
	if not Game.testing:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return match_node


func start_play() -> void:
	var me := {"name": Game.player_name, "walker": Game.walker, "team": int(play.team), "peer": 1}
	var fl := Net.make_fighters([me], int(play.bots), int(play.skill), str(play.mode))
	start_match({"mode": play.mode, "map": play.map, "limit": int(play.limit), "minutes": int(play.minutes),
		"seed": randi() % 1000000, "fighters": fl, "me": 0})


func _on_net_start(cfg: Dictionary) -> void:
	if Net.test_flag("bot") != "":
		cfg.autopilot = true
	if match_node:
		match_node.queue_free()
		match_node = null
	start_match(cfg)


func _on_match_finished(_result: Dictionary) -> void:
	_end_match_now()


func _end_match_now() -> void:
	var was_online := match_node != null and match_node.online
	get_tree().paused = false
	_close_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if match_node:
		match_node.queue_free()
		match_node = null
	if was_online and Net.active():
		Net.back_to_room()
		_start_demo()
		show_lobby()
	else:
		Net.leave()
		show_title()


# --- pause --------------------------------------------------------------------------------

func _show_pause() -> void:
	if _pause or match_node == null:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	match_node.paused = true
	if not match_node.online:
		get_tree().paused = true
	_pause = Control.new()
	_pause.name = "Pause"
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.theme = Ui.theme()
	ui_layer.add_child(_pause)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(420, 0)
	center.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pc.add_child(col)
	var t := Ui.title("Paused" if not match_node.online else "Menu", 38)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(Ui.wrap("%s on %s" % [Data.MODES[match_node.mode].name, match_node.map_def.name], 16, Game.GOLD, 380))
	if match_node.online:
		col.add_child(Ui.wrap("The match goes on while this menu is open.", 15, Color(0.8, 0.77, 0.7), 380))
	col.add_child(Ui.button("Resume", _resume, 18))
	_option_rows(col, 380)
	col.add_child(Ui.button("Leave match", func():
		if match_node.online and Net.is_client():
			Net.leave()
		_end_match_now(), 16))


func _resume() -> void:
	_close_pause()
	if match_node:
		match_node.paused = false
		if not Game.testing:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _close_pause() -> void:
	get_tree().paused = false
	if match_node:
		match_node.paused = false
	if _pause:
		_pause.queue_free()
		_pause = null


# --- screens -----------------------------------------------------------------------------

func _clear_screen() -> void:
	if screen:
		screen.queue_free()
		screen = null
	_preview = null
	_preview_vp = null


func _new_screen(nm: String, dim := 0.55) -> Control:
	_clear_screen()
	screen = Control.new()
	screen.name = nm
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.theme = Ui.theme()
	ui_layer.add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	return screen


## A centred panel with a title.
func _panel(title: String, width := 900.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(width, 0)
	center.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pc.add_child(col)
	var t := Ui.title(title, 36)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	return col


func _row(sep := 12) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	return r


func _option(items: Array, selected: int, cb: Callable, width := 170.0) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(selected)
	o.custom_minimum_size = Vector2(width, 34)
	o.item_selected.connect(cb)
	return o


func _field(parent: Control, text: String, w := 130.0) -> void:
	var l := Ui.label(text, 17, Game.GOLD, Game.font_bold)
	l.custom_minimum_size = Vector2(w, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _toggle_buttons(parent: Control, items: Array, labels: Array, current: String, cb: Callable, fsize := 15) -> void:
	for i in items.size():
		var it: String = items[i]
		var b := Ui.button(labels[i], func(): cb.call(it), fsize)
		b.toggle_mode = true
		b.button_pressed = it == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Opt_" + it
		parent.add_child(b)


func show_title() -> void:
	_start_demo()
	Game.play_music(["title"])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_new_screen("Title", 0.0)
	var side := ColorRect.new()
	side.color = Color(0.03, 0.025, 0.04, 0.72)
	side.anchor_bottom = 1.0
	side.custom_minimum_size = Vector2(420, 0)
	side.size = Vector2(420, 0)
	screen.add_child(side)
	var col := VBoxContainer.new()
	col.position = Vector2(48, 60)
	col.custom_minimum_size = Vector2(330, 0)
	col.add_theme_constant_override("separation", 11)
	screen.add_child(col)
	col.add_child(Ui.title("Planeswalker", 50))
	col.add_child(Ui.title("Arena", 50))
	col.add_child(Ui.wrap(Game.TAGLINE, 19, Game.GOLD, 330))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	col.add_child(gap)
	col.add_child(Ui.button("Play", show_play, 20))
	col.add_child(Ui.button("Multiplayer", show_multiplayer, 20))
	col.add_child(Ui.button("Planeswalkers", show_walkers, 20))
	col.add_child(Ui.button("Options", show_options, 20))
	col.add_child(Ui.button("How to play", show_help, 20))
	var w: Dictionary = Data.WALKERS[Game.walker]
	col.add_child(Ui.wrap("You play %s as %s." % [w.full, Game.player_name], 15, Color(0.78, 0.75, 0.68), 330))
	col.add_child(Ui.wrap("Twelve planeswalkers, seven weapons, ten arenas across the Multiverse. Free-for-all, team deathmatch and capture the flag, against bots or friends.", 14, Color(0.68, 0.65, 0.6), 330))


func show_play() -> void:
	_new_screen("Play")
	var col := _panel("Play against bots", 900)
	var mr := _row(8)
	col.add_child(mr)
	_field(mr, "Mode", 90)
	_toggle_buttons(mr, Data.MODE_ORDER, Data.MODE_ORDER.map(func(m): return Data.MODES[m].name), play.mode, func(m: String):
		play.mode = m
		var maps := Maps.for_mode(m)
		if not maps.any(func(x): return x.id == play.map):
			play.map = maps[0].id
		play.limit = Data.MODES[m].limit
		play.minutes = Data.MODES[m].minutes
		show_play())
	col.add_child(Ui.wrap(Data.MODES[play.mode].desc, 15, Color(0.82, 0.79, 0.72), 860))
	var maps := Maps.for_mode(play.mode)
	var r2 := _row(8)
	col.add_child(r2)
	_field(r2, "Arena", 90)
	_toggle_buttons(r2, maps.map(func(x): return x.id), maps.map(func(x): return x.name), play.map, func(id: String):
		play.map = id
		show_play(), 13)
	var mp := Maps.by_id(play.map)
	col.add_child(Ui.wrap("%s, %s. %s" % [mp.name, mp.plane, mp.desc], 15, Color(0.82, 0.79, 0.72), 860))
	var r3 := _row()
	col.add_child(r3)
	_field(r3, "Bots", 90)
	var counts := range(1, Data.MAX_FIGHTERS)
	r3.add_child(_option(counts, counts.find(int(play.bots)), func(k: int): play.bots = counts[k], 90))
	_field(r3, "Skill", 70)
	r3.add_child(_option(Data.SKILLS.map(func(s): return s.name), int(play.skill), func(k: int): play.skill = k, 150))
	if Data.MODES[play.mode].teams:
		_field(r3, "Team", 70)
		r3.add_child(_option(["Either", "Red", "Blue"], int(play.team) + 1, func(k: int): play.team = k - 1, 120))
	var r4 := _row()
	col.add_child(r4)
	var limits: Array = Data.MODES[play.mode].limits
	_field(r4, "Captures" if play.mode == Data.CTF else "Frags", 90)
	r4.add_child(_option(limits, maxi(0, limits.find(int(play.limit))), func(k: int): play.limit = limits[k], 90))
	_field(r4, "Minutes", 90)
	r4.add_child(_option(Data.MINUTES, maxi(0, Data.MINUTES.find(int(play.minutes))), func(k: int): play.minutes = Data.MINUTES[k], 90))
	var w: Dictionary = Data.WALKERS[Game.walker]
	col.add_child(Ui.wrap("You play %s. Change it under Planeswalkers." % w.full, 15, Color(0.78, 0.75, 0.68), 860))
	var btns := _row()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	btns.add_child(Ui.button("Back", show_title, 18))
	btns.add_child(Ui.button("Planeswalkers", func(): show_walkers(show_play), 18))
	var go := Ui.button("Start", start_play, 18)
	go.name = "Start"
	btns.add_child(go)


func show_multiplayer() -> void:
	_start_demo()
	if Net.active() and not Net.people.is_empty():
		show_lobby()
		return
	_new_screen("Multiplayer")
	var col := _panel("Multiplayer", 640)
	col.add_child(Ui.wrap("One of you opens a room and shares its code; the others join with it. Up to eight people, and bots fill the arena up to twelve.", 16, Color(0.82, 0.79, 0.72), 600))
	var r := _row()
	col.add_child(r)
	_field(r, "Your name", 120)
	var name_edit := LineEdit.new()
	name_edit.text = Game.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(260, 36)
	name_edit.text_changed.connect(func(t: String): Game.set_player(t, Game.walker))
	r.add_child(name_edit)
	col.add_child(Ui.button("Open a room", func(): Net.host(); show_lobby(), 18))
	var r2 := _row()
	col.add_child(r2)
	var code_edit := LineEdit.new()
	code_edit.placeholder_text = "Room code" if OS.has_feature("web") else "Host's address"
	code_edit.text = Net.invite_code()
	code_edit.custom_minimum_size = Vector2(260, 36)
	r2.add_child(code_edit)
	r2.add_child(Ui.button("Join", func(): Net.join(code_edit.text); show_lobby(), 18))
	var st := Ui.wrap(Net.status, 15, Game.GOLD, 600)
	col.add_child(st)
	Net.status_changed.connect(func(): if is_instance_valid(st): st.text = Net.status)
	col.add_child(Ui.button("Back", func(): Net.leave(); show_title(), 16))


func show_lobby() -> void:
	if not Net.active():
		show_multiplayer()
		return
	_new_screen("Lobby")
	var col := _panel("Room " + Net.code if Net.code != "" else "Room", 920)
	var top := _row()
	col.add_child(top)
	var st := Ui.wrap(Net.status, 15, Game.GOLD, 640)
	top.add_child(st)
	Net.status_changed.connect(func(): if is_instance_valid(st): st.text = Net.status)
	if Net.code != "":
		top.add_child(Ui.button("Copy code", Net.copy_code, 15))
	if Net.people.is_empty():
		col.add_child(Ui.label("Joining...", 18))
		col.add_child(Ui.button("Leave", func(): Net.leave(); show_multiplayer(), 16))
		return
	var host := Net.is_host()
	var s: Dictionary = Net.setup
	var teams: bool = Data.MODES[s.mode].teams
	# the setup: the host changes it, everyone sees it
	var r1 := _row(8)
	col.add_child(r1)
	_field(r1, "Mode", 90)
	if host:
		_toggle_buttons(r1, Data.MODE_ORDER, Data.MODE_ORDER.map(func(m): return Data.MODES[m].name), s.mode, func(m: String): Net.set_setup({"mode": m}))
	else:
		r1.add_child(Ui.label(Data.MODES[s.mode].name, 18))
	var r2 := _row(8)
	col.add_child(r2)
	_field(r2, "Arena", 90)
	var maps := Maps.for_mode(s.mode)
	if host:
		_toggle_buttons(r2, maps.map(func(x): return x.id), maps.map(func(x): return x.name), s.map, func(id: String): Net.set_setup({"map": id}), 13)
	else:
		r2.add_child(Ui.label(Maps.by_id(s.map).name, 18))
	col.add_child(Ui.wrap(Maps.by_id(s.map).desc, 14, Color(0.82, 0.79, 0.72), 880))
	var r3 := _row()
	col.add_child(r3)
	var limits: Array = Data.MODES[s.mode].limits
	if host:
		var counts := range(0, Data.MAX_FIGHTERS)
		_field(r3, "Bots", 70)
		r3.add_child(_option(counts, counts.find(int(s.bots)), func(k: int): Net.set_setup({"bots": counts[k]}), 80))
		_field(r3, "Skill", 60)
		r3.add_child(_option(Data.SKILLS.map(func(x): return x.name), int(s.skill), func(k: int): Net.set_setup({"skill": k}), 140))
		_field(r3, "Limit", 60)
		r3.add_child(_option(limits, maxi(0, limits.find(int(s.limit))), func(k: int): Net.set_setup({"limit": limits[k]}), 80))
		_field(r3, "Minutes", 80)
		r3.add_child(_option(Data.MINUTES, maxi(0, Data.MINUTES.find(int(s.minutes))), func(k: int): Net.set_setup({"minutes": Data.MINUTES[k]}), 80))
	else:
		r3.add_child(Ui.label("%d bots (%s), limit %d, %d minutes" % [int(s.bots), Data.SKILLS[int(s.skill)].name, int(s.limit), int(s.minutes)], 17))
	# the people
	col.add_child(Ui.label("Planeswalkers in the room", 18, Game.GOLD, Game.font_bold))
	for p in Net.people:
		var r := _row()
		col.add_child(r)
		var sw := ColorRect.new()
		sw.color = Data.team_color(int(p.team)) if teams and int(p.team) >= 0 else Color(0.5, 0.5, 0.5)
		sw.custom_minimum_size = Vector2(10, 34)
		r.add_child(sw)
		var mine: bool = int(p.peer) == Net.my_id()
		var l := Ui.label(str(p.name) + (" (you)" if mine else "") + ("  host" if int(p.peer) == 1 else ""), 18, Game.PALE, Game.font_bold)
		l.custom_minimum_size = Vector2(240, 34)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(l)
		if mine:
			var ids: Array = Data.WALKER_ORDER
			r.add_child(_option(ids.map(func(w): return Data.WALKERS[w].full), ids.find(str(p.walker)), func(k: int): Net.pick(ids[k], int(p.team)), 300))
			if teams:
				r.add_child(_option(["Either team", "Red", "Blue"], int(p.team) + 1, func(k: int): Net.pick(str(p.walker), k - 1), 140))
		else:
			var txt: String = Data.WALKERS[str(p.walker)].full
			if teams:
				txt += ", " + (Data.TEAM_NAMES[int(p.team)] if int(p.team) >= 0 else "either team")
			r.add_child(Ui.label(txt, 17))
	var btns := _row()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	btns.add_child(Ui.button("Leave", func(): Net.leave(); show_multiplayer(), 18))
	if host:
		var go := Ui.button("Start", Net.start_match, 18)
		go.disabled = not Net.can_start()
		go.name = "Start"
		btns.add_child(go)
	else:
		col.add_child(Ui.wrap("The host picks the mode and the arena and starts the match.", 15, Color(0.78, 0.75, 0.68), 880))


## The twelve planeswalkers: pick one, see it turn.
func show_walkers(back: Callable = show_title) -> void:
	_new_screen("Walkers", 0.7)
	var col := _panel("Planeswalkers", 1100)
	var body := _row(18)
	col.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for id in Data.WALKER_ORDER:
		var w: Dictionary = Data.WALKERS[id]
		var b := Ui.button(w.name, func():
			Game.set_player(Game.player_name, id)
			if Net.active():
				var mine := Net.me()
				Net.pick(id, int(mine.get("team", -1)))
			show_walkers(back), 16)
		b.toggle_mode = true
		b.button_pressed = id == Game.walker
		b.custom_minimum_size = Vector2(170, 44)
		b.add_theme_color_override("font_color", Color(w.glow).lightened(0.3))
		grid.add_child(b)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var w: Dictionary = Data.WALKERS[Game.walker]
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = Vector2(500, 360)
	holder.stretch = true
	right.add_child(holder)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_preview_vp)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0, 1.25, 4.6)
	cam.rotation.x = -0.06
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.65)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.glow_enabled = true
	cam.environment = env
	_preview_vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.3
	_preview_vp.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, -1.5)
	rim.light_color = Color(w.glow)
	rim.light_energy = 2.0
	rim.omni_range = 6.0
	_preview_vp.add_child(rim)
	var stand := MeshInstance3D.new()
	var k := MeshKit.new()
	k.cyl(Vector3(0, -0.1, 0), Vector3(0, 0, 0), 0.9, 0.9, Color(0.18, 0.16, 0.2), 24)
	k.ring(Vector3(0, 0.01, 0), Vector3.UP, 0.9, 0.04, Color(w.glow), 24, 3, true)
	stand.mesh = k.commit()
	_preview_vp.add_child(stand)
	_preview = Fighter.new()
	_preview.setup(null, 0, {"name": w.name, "walker": Game.walker, "team": -1, "bot": -1})
	_preview.alive = true
	_preview.weapon = "repeater"
	_preview_vp.add_child(_preview)
	right.add_child(Ui.label(w.full, 24, Color(w.glow).lightened(0.25), Game.font_title_bold))
	right.add_child(Ui.label(w.plane, 16, Game.GOLD))
	right.add_child(Ui.wrap(w.blurb, 16, Color(0.85, 0.82, 0.76), 500))
	var btns := _row()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btns)
	btns.add_child(Ui.button("Back", back, 18))


func _physics_process(dt: float) -> void:
	if _preview and is_instance_valid(_preview):
		_preview.rotation.y += dt * 0.6
		_preview.animate(dt, 1.0)


## Rows of settings, shared by Options and the pause menu.
func _option_rows(col: VBoxContainer, width: float) -> void:
	var r1 := _row()
	col.add_child(r1)
	_field(r1, "Mouse", 110)
	var sens := HSlider.new()
	sens.min_value = 0.2
	sens.max_value = 3.0
	sens.step = 0.05
	sens.value = Game.sensitivity
	sens.custom_minimum_size = Vector2(width - 180, 30)
	var sl := Ui.label("%.2f" % Game.sensitivity, 16)
	sens.value_changed.connect(func(v: float):
		Game.sensitivity = v
		sl.text = "%.2f" % v
		Game.save_settings())
	r1.add_child(sens)
	r1.add_child(sl)
	var r2 := _row()
	col.add_child(r2)
	_field(r2, "Field of view", 110)
	var fov := HSlider.new()
	fov.min_value = 70
	fov.max_value = 120
	fov.step = 1
	fov.value = Game.fov
	fov.custom_minimum_size = Vector2(width - 180, 30)
	var fl := Ui.label(str(int(Game.fov)), 16)
	fov.value_changed.connect(func(v: float):
		Game.fov = v
		fl.text = str(int(v))
		Game.save_settings())
	r2.add_child(fov)
	r2.add_child(fl)
	var r3 := _row(8)
	col.add_child(r3)
	var inv := Ui.button("Invert mouse: " + ("on" if Game.invert else "off"), func(): pass, 15)
	inv.pressed.connect(func():
		Game.invert = not Game.invert
		inv.text = "Invert mouse: " + ("on" if Game.invert else "off")
		Game.save_settings())
	inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_child(inv)
	var qb := Ui.button("Graphics: " + Game.QUALITY_NAMES[Game.quality], func(): pass, 15)
	qb.pressed.connect(func():
		Game.cycle_quality()
		qb.text = "Graphics: " + Game.QUALITY_NAMES[Game.quality])
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_child(qb)
	var r4 := _row(8)
	col.add_child(r4)
	var sb := Ui.button("Sound: " + ("off" if Game.muted else "on"), func(): pass, 15)
	sb.pressed.connect(func():
		Game.toggle_mute()
		sb.text = "Sound: " + ("off" if Game.muted else "on"))
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r4.add_child(sb)
	var mb := Ui.button("Music: " + ("on" if Game.music_on else "off"), func(): pass, 15)
	mb.pressed.connect(func():
		Game.toggle_music()
		mb.text = "Music: " + ("on" if Game.music_on else "off"))
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r4.add_child(mb)


func show_options() -> void:
	_new_screen("Options")
	var col := _panel("Options", 560)
	var r := _row()
	col.add_child(r)
	_field(r, "Your name", 110)
	var name_edit := LineEdit.new()
	name_edit.text = Game.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(300, 36)
	name_edit.text_changed.connect(func(t: String): Game.set_player(t, Game.walker))
	r.add_child(name_edit)
	_option_rows(col, 520)
	col.add_child(Ui.wrap("L changes the graphics and M the sound at any time.", 14, Color(0.75, 0.72, 0.66), 520))
	col.add_child(Ui.button("Back", show_title, 18))


func show_help() -> void:
	_new_screen("Help", 0.7)
	var col := _panel("How to play", 960)
	var txt := """[b]Moving.[/b] WASD or the arrows run, Space jumps, the mouse looks. You keep your speed in the air, so jump down stairs and off ledges. Pads throw you across the arena and portals carry you to their twin. Lava and the void kill.
[b]Shooting.[/b] Left click fires, the wheel or 1-7 or E and Q change weapon, R takes the last one again. Right click (or Z) zooms the Disintegrate. Spellblade and Spark Repeater come with every life; the rest lie in the arena: Thunderclap (close, many pellets), Aether Pulse (fast bolts), Lightning Lash (a beam), Fireball (blast that throws people, also you) and Disintegrate (one beam through everyone, deadly to the head).
[b]Pickups.[/b] Salves heal 25 up to 100, the Elixir of Life 100 up to 200. Shards, Ward Plate and the Aegis give armour, which takes two thirds of every hit. Overload triples your damage and Haste makes you a third faster for 30 seconds. Health above 100 slowly fades.
[b]Modes.[/b] Free-for-all: everyone for themselves, first to the frag limit. Team Deathmatch: Red against Blue, every frag counts for the team. Capture the Flag: touch the enemy banner to take it and bring it to your own while yours is at home. Touching your dropped banner sends it home.
[b]Bots.[/b] Common, Uncommon, Rare and Mythic: better aim, quicker reactions, more dodging.
[b]Keys.[/b] Tab: scores. Esc: menu. L: graphics. M: sound. Click to come back after dying."""
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(920, 0)
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 16)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.text = txt
	col.add_child(rt)
	col.add_child(Ui.button("Back", show_title, 18))
