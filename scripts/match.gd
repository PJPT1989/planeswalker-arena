class_name Match
extends Node3D
## One match: the arena, the fighters, projectiles, pickups, flags, the score and the rules.
## The host (or a single-player game, which is a host with nobody connected) decides
## everything that matters: damage, frags, pickups, flags, spawns, the winner. Each computer
## moves its own fighters (its player; on the host also the bots), works out which of its
## shots hit what it sees, and tells the host. The host sends everyone a snapshot twenty times
## a second and an event for everything that happens. Also the first-person view, the camera
## that follows a bot in demos and the title screen, and the local player's controls.

signal finished(result: Dictionary)

const SNAP_EVERY := 0.05
const STATE_EVERY := 0.05
const WARMUP := 3.0

var cfg := {}
var mode := "ffa"
var teams := false
var limit := 20
var map_def := {}
var arena: Arena
var fighters: Array[Fighter] = []
var bots := {}                  # fighter id -> Bot
var me := -1                    # the fighter played on this computer (-1: watching)
var host := true
var online := false
var demo := false               # title screen: bots only, the camera follows one
var headless := false           # simulation test: no camera, no effects
var cam: Camera3D
var fx: Fx
var hud: Hud
var view_model: Node3D
var _vm_weapon: MeshInstance3D
var _vm_hand: MeshInstance3D
var _vm_w := ""
var _vm_kick := 0.0
var _bob := 0.0
var time_left := 600.0
var warmup := WARMUP
var over := false
var winner := {}
var scores := []                # per fighter: {frags, deaths, caps}
var team_score := [0, 0]
var item_state := []            # per arena item: {avail, t, node}
var flags := []                 # per team: {state: home/carried/dropped, carrier, pos, t, node}
var projectiles := {}           # id -> {w, pos, vel, owner, t, node}
var _exploded := {}
var _proj_seq := 0
var feed := []                  # kill feed lines for the HUD: [text, colour, time]
var _snap_t := 0.0
var _state_t := 0.0
var _respawn_wait := {}         # fighter id -> seconds until a bot (or a waiting player) respawns
var _dead_hold := {}
var _hazard_sent := {}
var _pad_cool := {}
var _tele_cool := {}
var _spec := 0
var _spec_t := 0.0
var _over_t := 0.0
var _clock := 0.0
var _beam_snd := 0.0
var _space: PhysicsDirectSpaceState3D
var paused := false
var mouse_look := true
var stats := {"shots": 0, "hits": 0, "stuck": 0, "self": {}, "picked": {}}


func start(c: Dictionary) -> void:
	cfg = c
	mode = str(c.get("mode", "ffa"))
	teams = Data.MODES[mode].teams
	limit = int(c.get("limit", Data.MODES[mode].limit))
	time_left = float(c.get("minutes", Data.MODES[mode].minutes)) * 60.0
	map_def = Maps.by_id(str(c.get("map", "foundry")))
	me = int(c.get("me", -1))
	host = not bool(c.get("guest", false))
	online = bool(c.get("online", false))
	demo = bool(c.get("demo", false))
	headless = bool(c.get("headless", false))
	seed(int(c.get("seed", randi())))
	arena = Arena.new(map_def)
	add_child(arena)
	arena.build()
	arena.apply_quality()
	Game.quality_changed.connect(arena.apply_quality)
	if not headless:
		fx = Fx.new()
		add_child(fx)
		cam = Camera3D.new()
		cam.near = 0.025
		cam.far = 600.0
		cam.fov = Game.fov
		cam.environment = arena.env
		add_child(cam)
		cam.current = true
		fx.cam = cam
		_build_view_model()
	var list: Array = c.fighters
	for i in list.size():
		var f := Fighter.new()
		f.setup(self, i, list[i])
		var peer := int(list[i].get("peer", 1))
		f.local = peer == _my_peer() and (int(list[i].get("bot", -1)) < 0 or host)
		add_child(f)
		f.global_position = Vector3(0, -100 - i * 3, 0)
		f.alive = false
		f.reset_loadout()
		fighters.append(f)
		scores.append({"frags": 0, "deaths": 0, "caps": 0})
		if host and f.is_bot() or i == me and c.get("autopilot", false):
			bots[i] = Bot.new(self, f)
	for i in arena.items.size():
		var it: Dictionary = arena.items[i]
		var node := _item_node(it.kind)
		node.position = it.pos
		add_child(node)
		item_state.append({"avail": true, "t": 0.0, "node": node})
	if mode == Data.CTF:
		for t in 2:
			var base := MeshInstance3D.new()
			base.mesh = Models.flag_base(t)
			base.position = arena.flags[t]
			add_child(base)
			var fl := MeshInstance3D.new()
			fl.mesh = Models.flag(t)
			add_child(fl)
			flags.append({"state": "home", "carrier": -1, "pos": arena.flags[t] + Vector3(0, 0.3, 0), "t": 0.0, "node": fl})
	if me >= 0 and me < fighters.size():
		fighters[me].show_model(false)
	if host:
		for f in fighters:
			_spawn(f)
	if not headless and not demo and me >= 0:
		var layer := CanvasLayer.new()
		add_child(layer)
		hud = Hud.new()
		hud.mt = self
		layer.add_child(hud)
	elif demo or me < 0:
		_spec = randi() % maxi(fighters.size(), 1)


func _my_peer() -> int:
	return Net.my_id() if online else 1


func _item_node(kind: String) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	if kind.begins_with("w:"):
		var w := kind.substr(2)
		mi.mesh = Models.weapon(w)
		mi.scale = Vector3.ONE * 1.6
		mi.position = Vector3(0, 0.8, 0)
		mi.rotation.z = 0.2
	else:
		mi.mesh = Models.item(kind)
		mi.position = Vector3(0, 0.25, 0)
	n.add_child(mi)
	n.set_meta("mesh", mi)
	# a glowing ring on the floor shows where something will come back
	var k := MeshKit.new()
	var col: Color = Data.WEAPONS[kind.substr(2)].color if kind.begins_with("w:") else Data.ITEMS[kind].color
	k.ring(Vector3(0, 0.04, 0), Vector3.UP, 0.75, 0.04, col, 16, 3, true)
	var ring := MeshInstance3D.new()
	ring.mesh = k.commit()
	n.add_child(ring)
	return n


# --- the first-person weapon --------------------------------------------------------------

func _build_view_model() -> void:
	# drawn small and close to the eye (0.15 scale), so it never pokes into walls
	view_model = Node3D.new()
	view_model.scale = Vector3.ONE * 0.15
	cam.add_child(view_model)
	_vm_weapon = MeshInstance3D.new()
	_vm_weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view_model.add_child(_vm_weapon)
	_vm_hand = MeshInstance3D.new()
	_vm_hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view_model.add_child(_vm_hand)


func _update_view_model(dt: float) -> void:
	if view_model == null:
		return
	var f := fighters[me] if me >= 0 else null
	view_model.visible = f != null and f.alive and not (f.zoom and f.weapon == "disintegrate")
	if not view_model.visible:
		return
	if _vm_w != f.weapon:
		_vm_w = f.weapon
		_vm_weapon.mesh = Models.weapon(f.weapon)
		_vm_hand.mesh = Models.view_hand(f.walker())
	var hs := Vector2(f.velocity.x, f.velocity.z).length()
	if f.is_on_floor():
		_bob += dt * hs * 1.1
	_vm_kick = maxf(0.0, _vm_kick - dt * 6.0)
	var raise := f.raise_t / 0.25
	var bob := Vector3(sin(_bob) * 0.012, -absf(cos(_bob)) * 0.01, 0) * clampf(hs / 9.0, 0, 1)
	view_model.position = Vector3(0.042, -0.042 - raise * 0.04, -0.06 + _vm_kick * 0.012) + bob
	view_model.rotation = Vector3(_vm_kick * 0.12 - raise * 0.6, 0.04, 0)


# --- the main loop ------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	_clock += dt
	if warmup > 0.0:
		warmup -= dt
	var frozen := warmup > 0.0 or over
	for id in bots:
		if not frozen:
			bots[id].update(dt)
		else:
			bots[id].f.move_in = Vector2.ZERO
			bots[id].f.fire_in = false
	if me >= 0 and fighters[me].local and not demo:
		_player_input()
	for f in fighters:
		if not f.local:
			continue
		if frozen:
			f.move_in = Vector2.ZERO
			f.jump_in = false
		f.physics_step(dt)
		if f.alive:
			if f.is_on_floor():
				f.set_meta("last_floor", f.global_position)
			_touch_world(f)
			if f.fire_in and not frozen:
				try_fire(f)
			else:
				f.beam_on = false
	_step_projectiles(dt)
	if host:
		_host_tick(dt)
	if online:
		_state_t += dt
		if host:
			if _state_t >= SNAP_EVERY:
				_state_t = 0.0
				Net.broadcast_snapshot(pack_snapshot())
		elif _state_t >= STATE_EVERY:
			_state_t = 0.0
			Net.send_state(pack_state())


func _process(dt: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var frac := Engine.get_physics_interpolation_fraction()
	for f in fighters:
		if not f.local:
			f.puppet_update(now)
		f.animate(dt, frac)
	for i in item_state.size():
		var s: Dictionary = item_state[i]
		var mi: Node3D = s.node.get_meta("mesh")
		mi.visible = s.avail
		mi.rotation.y += dt * 1.5
		mi.position.y = (0.8 if str(arena.items[i].kind).begins_with("w:") else 0.25) + sin(now * 2.0 + i) * 0.08
	for t in flags.size():
		var fl: Dictionary = flags[t]
		var node: MeshInstance3D = fl.node
		node.visible = fl.state != "carried"
		node.position = fl.pos
		node.rotation.y += dt * (0.5 if fl.state == "home" else 1.5)
	for id in projectiles:
		var p: Dictionary = projectiles[id]
		if p.node:
			p.node.position = p.pos
	if headless:
		return
	_update_camera(dt, frac)
	_update_view_model(dt)
	_beam_fx(dt)
	if hud:
		hud.queue_redraw()
	for i in feed.size():
		feed[i][2] += dt
	while feed.size() > 0 and feed[0][2] > 7.0:
		feed.pop_front()


# --- the player's controls -----------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if me < 0 or demo or paused:
		return
	var f := fighters[me]
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := 0.0022 * Game.sensitivity * (0.35 if f.zoom and f.weapon == "disintegrate" else 1.0)
		f.yaw -= e.relative.x * s
		f.pitch = clampf(f.pitch - e.relative.y * s * (-1.0 if Game.invert else 1.0), -1.5, 1.5)
	elif e is InputEventMouseButton and e.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Game.testing:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			f.cycle(1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			f.cycle(-1)
	elif e is InputEventKey and e.pressed and not e.echo:
		for i in 7:
			if e.is_action("weapon_%d" % (i + 1)):
				f.switch_to(Data.WEAPON_ORDER[i])
		if e.is_action("next_weapon"):
			f.cycle(1)
		elif e.is_action("prev_weapon"):
			f.cycle(-1)
		elif e.is_action("last_weapon"):
			f.switch_to(f.last_weapon)


func _player_input() -> void:
	var f := fighters[me]
	if paused or Game.testing and cfg.get("autopilot", false):
		if paused:
			f.move_in = Vector2.ZERO
			f.fire_in = false
			f.jump_in = false
		return
	f.move_in = Vector2(Input.get_axis("left", "right"), Input.get_axis("back", "forward"))
	f.jump_in = Input.is_action_pressed("jump")
	f.fire_in = Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	f.zoom = Input.is_action_pressed("zoom")
	if not f.alive and f.fire_in and f.dead_t > Data.RESPAWN_DELAY and not _dead_hold.get(f.id, false):
		_dead_hold[f.id] = true
		request({"t": "respawn", "f": f.id})


## Places the camera: the player's eyes, or following someone when watching.
func _update_camera(dt: float, frac: float) -> void:
	var target := me if me >= 0 and not demo else _spec
	if demo or me < 0:
		_spec_t += dt
		if _spec_t > 14.0 or not fighters[_spec].alive and fighters[_spec].dead_t > 2.5:
			_spec_t = 0.0
			_spec = _next_alive(_spec)
		target = _spec
	if target < 0 or target >= fighters.size():
		return
	var f := fighters[target]
	var pos := f.prev_pos.lerp(f.global_position, frac) if f.local else f.global_position
	if f.alive and target == me and not demo:
		cam.global_position = pos + Vector3(0, Data.EYE, 0)
		cam.rotation = Vector3(f.pitch, f.yaw, 0)
		var want := Game.fov
		if f.zoom and f.weapon == "disintegrate":
			want = 28.0
		cam.fov = lerpf(cam.fov, want, minf(1.0, dt * 14.0))
		return
	cam.fov = lerpf(cam.fov, Game.fov * 0.85, minf(1.0, dt * 4.0))
	if not f.alive and target == me:
		# dead: look down at where it happened from above
		var at := pos + Vector3(0, 1.0, 0)
		var back := Vector3(sin(f.yaw), 0, cos(f.yaw)) * 4.0
		var want_pos := at + back + Vector3(0, 3.0 + minf(f.dead_t, 2.0), 0)
		cam.global_position = cam.global_position.lerp(want_pos, minf(1.0, dt * 3.0))
		cam.look_at(at, Vector3.UP)
		return
	# following: behind and above, kept out of walls
	var head := pos + Vector3(0, 1.7, 0)
	var dir := f.aim_dir()
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var want := head - flat * 4.5 + Vector3(0, 1.4, 0)
	if _space:
		var q := PhysicsRayQueryParameters3D.create(head, want, 1)
		var hit := _space.intersect_ray(q)
		if hit:
			want = head.lerp(hit.position, 0.85)
	cam.global_position = cam.global_position.lerp(want, minf(1.0, dt * 6.0))
	var look := head + flat * 3.0 + Vector3(0, -0.4, 0)
	if cam.global_position.distance_to(look) > 0.1:
		cam.look_at(look, Vector3.UP)


func _next_alive(from: int) -> int:
	for k in range(1, fighters.size() + 1):
		var i := (from + k) % fighters.size()
		if fighters[i].alive:
			return i
	return from


# --- touching the arena: pads, portals, lava, the void ------------------------------------

func _touch_world(f: Fighter) -> void:
	var p := f.global_position
	var now := _clock
	for i in arena.pads.size():
		var pd: Dictionary = arena.pads[i]
		var d: Vector3 = p - pd.pos
		if Vector2(d.x, d.z).length() < 1.15 and d.y > -0.3 and d.y < 0.7 and now > float(_pad_cool.get(f.id, 0.0)):
			_pad_cool[f.id] = now + 0.5
			f.launch(pd.vel)
			_sound("pad", p)
	for i in arena.teles.size():
		var t: Dictionary = arena.teles[i]
		var d: Vector3 = p - t.pos
		if Vector2(d.x, d.z).length() < 1.0 and d.y > -0.4 and d.y < 2.2 and now > float(_tele_cool.get(f.id, 0.0)):
			_tele_cool[f.id] = now + 0.6
			f.teleport(t.dest + Vector3(0, 0.05, 0), t.yaw)
			_sound("teleport", t.dest)
			if fx:
				fx.flash(t.dest + Vector3(0, 1, 0), Color(0.7, 0.5, 1.0), 1.4, 0.3)
	if _hazard_sent.get(f.id, false):
		return
	var cause := ""
	if p.y < arena.kill_y:
		cause = "void"
	else:
		for hz in arena.hazards:
			if hz.has_point(p + Vector3(0, 0.2, 0)):
				cause = "lava"
	if cause != "":
		_hazard_sent[f.id] = true
		request({"t": "suicide", "f": f.id, "c": cause})


# --- shooting -----------------------------------------------------------------------------

## Fires the held weapon if it is ready: works out hits as this computer sees them and tells
## the host. Returns true if a shot went off.
func try_fire(f: Fighter) -> bool:
	if not f.alive or f.cool > 0.0 or f.raise_t > 0.0:
		return false
	var w := f.weapon
	var wd: Dictionary = Data.WEAPONS[w]
	if not f.has_ammo(w):
		f.beam_on = false
		if f.id == me and not f.is_bot():
			Game.play("empty", -6.0)
		f.auto_switch()
		return false
	if int(f.weapons[w]) > 0:
		f.weapons[w] = int(f.weapons[w]) - 1
	f.cool = float(wd.rate) * (0.75 if f.power("haste") else 1.0)
	var origin := f.eye()
	var dir := f.aim_dir()
	var muzzle := _muzzle(f)
	var hits := []
	var ends := []
	stats.shots += 1
	match str(wd.kind):
		"melee":
			var r := _trace(f, origin, dir, float(wd.range))
			if r.target >= 0:
				hits.append([r.target, int(wd.dmg), false])
			ends.append(r.end)
		"hitscan", "pellets", "beam":
			var n := int(wd.get("pellets", 1))
			for k in n:
				var d := _spread(f, dir, float(wd.get("spread", 0.0)))
				var r := _trace(f, origin, d, float(wd.range))
				if r.target >= 0:
					hits.append([r.target, int(wd.dmg), false])
				ends.append(r.end)
			if wd.kind == "beam":
				f.beam_on = true
				f.set_meta("beam_end", ends[0])
		"rail":
			var r := _trace(f, origin, dir, float(wd.range), true)
			for t in r.targets:
				hits.append([t[0], int(wd.head) if t[1] else int(wd.dmg), t[1]])
			ends.append(r.end)
		"projectile":
			_proj_seq += 1
			var id := f.id * 1000000 + _proj_seq
			var start := origin + dir * 0.6 + (muzzle - origin) * 0.4
			var vel := dir * float(wd.speed)
			_add_projectile(id, w, start, vel, f.id)
			request({"t": "proj", "id": id, "w": w, "o": start, "v": vel, "f": f.id})
			_shot_fx(f, w, muzzle, [])
			return true
	if not hits.is_empty():
		stats.hits += 1
	_shot_fx(f, w, muzzle, ends)
	request({"t": "fire", "f": f.id, "w": w, "o": muzzle, "e": ends, "h": hits})
	return true


func _muzzle(f: Fighter) -> Vector3:
	var dir := f.aim_dir()
	var right := Vector3(-cos(f.yaw), 0, sin(f.yaw)) * -1.0
	return f.eye() + dir * 0.55 + right * 0.16 + Vector3(0, -0.14, 0)


func _spread(f: Fighter, dir: Vector3, s: float) -> Vector3:
	if s <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var a := randf() * TAU
	var r := sqrt(randf()) * s
	return (dir + side * cos(a) * r + up * sin(a) * r).normalized()


## A shot from `origin` along `dir`: what it hits first (or, piercing, every fighter on the
## way to a wall). {target, end, targets: [[id, headshot]]}.
func _trace(f: Fighter, origin: Vector3, dir: Vector3, range: float, pierce := false) -> Dictionary:
	var out := {"target": -1, "end": origin + dir * range, "targets": []}
	if _space == null:
		return out
	var exclude: Array[RID] = [f.get_rid()]
	var from := origin
	var to := origin + dir * range
	for k in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to, 3, exclude)
		var hit := _space.intersect_ray(q)
		if hit.is_empty():
			return out
		var col: Object = hit.collider
		if col is Fighter and (col as Fighter).alive:
			var t := col as Fighter
			var head: bool = hit.position.y - t.global_position.y > Data.HEAD_Y
			if not pierce:
				out.target = t.id
				out.end = hit.position
				return out
			out.targets.append([t.id, head])
			exclude.append(t.get_rid())
			from = hit.position
			continue
		if col is Fighter:
			exclude.append((col as Fighter).get_rid())
			from = hit.position
			continue
		out.end = hit.position
		return out
	return out


## What a shot looks like: tracers, the lightning lash, the disintegrate beam, sparks where
## it lands.
func _shot_fx(f: Fighter, w: String, muzzle: Vector3, ends: Array) -> void:
	var listener := cam.global_position if cam else Vector3.ZERO
	_sound(w, muzzle, -2.0 if f.id == me else -4.0)
	if f.id == me:
		_vm_kick = 1.0 if w != "lash" and w != "repeater" else 0.35
	if fx == null:
		return
	var col: Color = Data.WEAPONS[w].color
	fx.flash(muzzle, col, 0.25, 0.05)
	match w:
		"repeater":
			for e in ends:
				fx.beam(muzzle, e, col, 0.03, 0.06)
				fx.sparks(e, 3, col, 3.0, 0.25, 0.05)
		"thunder":
			for e in ends:
				fx.beam(muzzle, e, Color(0.8, 0.9, 1.0, 0.6), 0.02, 0.08)
				fx.sparks(e, 1, col, 2.5, 0.2, 0.05)
			fx.flash(muzzle, Color(0.85, 0.9, 1.0), 0.6, 0.09)
		"rail", "disintegrate":
			for e in ends:
				fx.beam(muzzle, e, col, 0.14, 0.9)
				fx.beam(muzzle, e, Color(1, 0.9, 1), 0.04, 0.5)
				fx.beam(muzzle, e, col, 0.3, 0.9, 0.12)
				fx.sparks(e, 12, col, 5.0, 0.5, 0.07)
		"blade":
			for e in ends:
				fx.flash(e, col, 0.5, 0.12)
	if listener != Vector3.ZERO and w == "blade":
		pass


## The lightning lash is drawn every frame while its holder fires.
func _beam_fx(dt: float) -> void:
	_beam_snd -= dt
	for f in fighters:
		if f.alive and f.beam_on and f.weapon == "lash":
			var end: Vector3 = f.get_meta("beam_end", f.eye() + f.aim_dir() * 20.0)
			if not f.local:
				end = f.eye() + f.aim_dir() * 24.0
				if _space:
					var r := _trace(f, f.eye(), f.aim_dir(), 24.0)
					end = r.end
			var m := _muzzle(f) if f.id != me else cam.global_position + cam.global_transform.basis * Vector3(0.12, -0.12, -0.6)
			fx.beam(m, end, Color(0.6, 0.75, 1.0), 0.08, 0.035, 0.18)
			fx.beam(m, end, Color(0.9, 0.95, 1.0), 0.03, 0.035, 0.08)
			if randf() < 0.3:
				fx.sparks(end, 2, Color(0.7, 0.85, 1.0), 4.0, 0.2, 0.05)
			if _beam_snd <= 0.0:
				_sound("lash", f.eye(), -6.0)
		elif not f.local:
			pass
	if _beam_snd <= 0.0:
		_beam_snd = 0.1


func _sound(name: String, at: Vector3, vol := 0.0) -> void:
	if headless or cam == null:
		return
	Game.play_at(name, at, cam.global_position, vol)


# --- projectiles --------------------------------------------------------------------------

func _add_projectile(id: int, w: String, pos: Vector3, vel: Vector3, owner: int) -> void:
	if projectiles.has(id) or _exploded.has(id):
		return
	var node: MeshInstance3D = null
	if not headless:
		node = MeshInstance3D.new()
		node.mesh = Models.projectile(w)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = pos
		add_child(node)
	projectiles[id] = {"w": w, "pos": pos, "vel": vel, "owner": owner, "t": 0.0, "node": node}


func _step_projectiles(dt: float) -> void:
	if projectiles.is_empty() or _space == null:
		return
	for id in projectiles.keys():
		var p: Dictionary = projectiles[id]
		p.t += dt
		var from: Vector3 = p.pos
		var to: Vector3 = from + p.vel * dt
		var exclude: Array[RID] = []
		var owner := int(p.owner)
		if owner >= 0 and owner < fighters.size():
			exclude.append(fighters[owner].get_rid())
		for f in fighters:
			if not f.alive:
				exclude.append(f.get_rid())
		var q := PhysicsRayQueryParameters3D.create(from, to, 3, exclude)
		var hit := _space.intersect_ray(q)
		if fx and p.w == "fireball" and randf() < 0.7:
			fx.sparks(from, 1, Color(1.0, 0.55, 0.2), 1.0, 0.35, 0.12, -1.0)
		if hit:
			var direct := -1
			if hit.collider is Fighter:
				direct = (hit.collider as Fighter).id
			var at: Vector3 = hit.position - (p.vel as Vector3).normalized() * 0.15
			if host:
				_explode(id, at, direct)
			else:
				_local_explosion(id, p.w, at, owner)
		elif p.t > 6.0:
			_remove_projectile(id)
		else:
			p.pos = to


func _remove_projectile(id: int) -> void:
	var p: Dictionary = projectiles.get(id, {})
	if p.is_empty():
		return
	if p.node:
		p.node.queue_free()
	projectiles.erase(id)


## Host: a projectile goes off. Damage, then everyone sees it.
func _explode(id: int, at: Vector3, direct: int) -> void:
	var p: Dictionary = projectiles.get(id, {})
	if p.is_empty():
		return
	var w: String = p.w
	var wd: Dictionary = Data.WEAPONS[w]
	var owner := int(p.owner)
	if direct >= 0:
		damage(fighters[direct], owner, int(wd.dmg), w)
	var r: float = wd.radius
	for f in fighters:
		if not f.alive or f.id == direct:
			continue
		var d := f.centre().distance_to(at)
		if d < r + 0.4:
			var q := PhysicsRayQueryParameters3D.create(at, f.centre(), 1)
			if _space.intersect_ray(q).is_empty():
				var dmg := int(float(wd.splash) * clampf(1.0 - d / (r + 0.4), 0.0, 1.0))
				if dmg > 0:
					damage(f, owner, dmg, w)
	_local_explosion(id, w, at, owner)
	host_event({"t": "boom", "id": id, "p": at, "w": w}, true)


## An explosion seen here: the effect, and a push for the fighters this computer moves.
func _local_explosion(id: int, w: String, at: Vector3, owner: int) -> void:
	_remove_projectile(id)
	if _exploded.has(id):
		return
	_exploded[id] = true
	var wd: Dictionary = Data.WEAPONS[w]
	var r: float = wd.radius
	for f in fighters:
		if not f.local or not f.alive:
			continue
		var c := f.centre()
		var d := c.distance_to(at)
		if d < r + 0.6:
			var dir := (c - at).normalized()
			if d < 0.05:
				dir = Vector3.UP
			var k := float(wd.knock) * clampf(1.0 - d / (r + 0.6), 0.0, 1.0)
			if f.id == owner:
				k *= 1.15
			f.push(dir * k + Vector3(0, k * 0.25, 0))
	if fx:
		fx.explosion(at, wd.color, r * (1.0 if w == "fireball" else 0.4))
	_sound("boom" if w == "fireball" else "pop", at, 0.0 if w == "fireball" else -4.0)


# --- rules (host) --------------------------------------------------------------------------

func damage(t: Fighter, attacker: int, dmg: int, w: String, head := false) -> void:
	if not host or not t.alive or over:
		return
	var a: Fighter = fighters[attacker] if attacker >= 0 and attacker < fighters.size() else null
	if a and a != t and teams and a.team == t.team:
		return
	if a and a.power("overload"):
		dmg = int(dmg * Data.OVERLOAD_MULT)
	if a == t:
		dmg = int(dmg * Data.SELF_DAMAGE)
	if t.spawn_t < 0.5 and a != t:
		dmg = dmg / 2
	var save := mini(t.armor, ceili(dmg * Data.ARMOR_ABSORB))
	t.armor -= save
	t.health -= dmg - save
	if a and a != t:
		t.last_hit_by = attacker
		t.set_meta("hit_at", _clock)
	host_event({"t": "dmg", "v": t.id, "a": attacker, "n": dmg, "h": t.health, "ar": t.armor})
	if t.health <= 0:
		_kill(t, attacker, w, head)


func _kill(t: Fighter, killer: int, w: String, head := false) -> void:
	if killer < 0 and t.last_hit_by >= 0:
		pass
	var s: Dictionary = scores[t.id]
	s.deaths += 1
	if killer >= 0 and killer != t.id:
		scores[killer].frags += 1
		if teams:
			team_score[fighters[killer].team] += 1 if mode == Data.TDM else 0
	else:
		stats.self[w] = int(stats.self.get(w, 0)) + 1
		s.frags -= 1
		if teams and mode == Data.TDM:
			team_score[t.team] -= 1
	if t.carrying >= 0:
		_drop_flag(t)
	_respawn_wait[t.id] = randf_range(1.6, 2.6) if t.is_bot() else 6.0
	host_event({"t": "kill", "v": t.id, "k": killer, "w": w, "hd": head})
	_check_win()


func _spawn(f: Fighter) -> void:
	var best := []
	for s in arena.spawns:
		if teams and mode == Data.CTF and int(s.team) >= 0 and int(s.team) != f.team:
			continue
		if mode == Data.CTF and int(s.team) < 0:
			continue
		var near := 1e9
		for o in fighters:
			if o != f and o.alive and (not teams or o.team != f.team):
				near = minf(near, o.global_position.distance_to(s.pos))
		best.append([near + randf() * 6.0, s])
	if best.is_empty():
		for s in arena.spawns:
			best.append([randf(), s])
	best.sort_custom(func(x, y): return x[0] > y[0])
	var pick: Dictionary = best[randi() % mini(3, best.size())][1]
	host_event({"t": "spawn", "f": f.id, "p": pick.pos + Vector3(0, 0.1, 0), "y": float(pick.yaw)})


func _host_tick(dt: float) -> void:
	if over:
		_over_t += dt
		if _over_t > 8.0 and _over_t - dt <= 8.0:
			finished.emit(winner)
		return
	if warmup <= 0.0:
		time_left -= dt
		if time_left <= 0.0:
			time_left = 0.0
			_end_match()
			return
	for id in _respawn_wait.keys():
		_respawn_wait[id] -= dt
		var f := fighters[id]
		if _respawn_wait[id] <= 0.0 and not f.alive:
			_respawn_wait.erase(id)
			_spawn(f)
	for f in fighters:
		if not f.alive:
			continue
		for p in f.powers.keys():
			f.powers[p] = float(f.powers[p]) - dt
			if f.powers[p] <= 0.0:
				f.powers.erase(p)
		if f.health > 100:
			f.set_meta("decay", float(f.get_meta("decay", 0.0)) + dt)
			if f.get_meta("decay") >= 1.0:
				f.set_meta("decay", 0.0)
				f.health -= 1
	# pickups
	for i in item_state.size():
		var s: Dictionary = item_state[i]
		if not s.avail:
			s.t -= dt
			if s.t <= 0.0:
				s.avail = true
			continue
		var it: Dictionary = arena.items[i]
		for f in fighters:
			if not f.alive:
				continue
			var d: Vector3 = f.global_position - it.pos
			if Vector2(d.x, d.z).length() < 1.25 and d.y > -0.8 and d.y < 1.6 and _wants(f, it.kind):
				_take_item(i, f)
				break
	if mode == Data.CTF:
		_flag_tick(dt)


## Whether a fighter would pick this up now (full health ignores salves, and so on).
func _wants(f: Fighter, kind: String) -> bool:
	if kind.begins_with("w:"):
		var w := kind.substr(2)
		if not f.local:
			return true   # the owner sorts out ammo; a full one just gets nothing
		var a: Array = Data.WEAPONS[w].ammo
		return not f.weapons.has(w) or int(f.weapons[w]) < int(a[2])
	var d: Dictionary = Data.ITEMS[kind]
	if d.has("health"):
		return f.health < int(d.cap)
	if d.has("armor"):
		return f.armor < int(d.cap)
	return true


func _take_item(i: int, f: Fighter) -> void:
	var kind: String = arena.items[i].kind
	var s: Dictionary = item_state[i]
	stats.picked[i] = int(stats.picked.get(i, 0)) + 1
	s.avail = false
	s.t = Data.WEAPON_RESPAWN if kind.begins_with("w:") else float(Data.ITEMS[kind].respawn)
	if not kind.begins_with("w:"):
		var d: Dictionary = Data.ITEMS[kind]
		if d.has("health"):
			f.health = mini(int(d.cap), f.health + int(d.health))
		if d.has("armor"):
			f.armor = mini(int(d.cap), f.armor + int(d.armor))
		if d.has("power"):
			f.powers[d.power] = float(d.time)
	host_event({"t": "pick", "i": i, "f": f.id, "h": f.health, "ar": f.armor})


func _flag_tick(dt: float) -> void:
	for t in 2:
		var fl: Dictionary = flags[t]
		if fl.state == "carried":
			var c := fighters[fl.carrier]
			fl.pos = c.global_position + Vector3(0, 0.2, 0)
			# a capture: the carrier reaches its own flag while that one is at home
			var own: Dictionary = flags[c.team]
			if own.state == "home" and c.global_position.distance_to(arena.flags[c.team]) < 2.2:
				fl.state = "home"
				fl.carrier = -1
				fl.pos = arena.flags[t] + Vector3(0, 0.3, 0)
				c.carrying = -1
				scores[c.id].caps += 1
				team_score[c.team] += 1
				host_event({"t": "flag", "k": "capture", "team": t, "f": c.id})
				_check_win()
			continue
		if fl.state == "dropped":
			fl.t -= dt
			if fl.t <= 0.0:
				_return_flag(t, -1)
				continue
		for f in fighters:
			if not f.alive or f.global_position.distance_to(fl.pos) > 1.6:
				continue
			if f.team != t:
				fl.state = "carried"
				fl.carrier = f.id
				f.carrying = t
				host_event({"t": "flag", "k": "take", "team": t, "f": f.id})
				break
			elif fl.state == "dropped":
				_return_flag(t, f.id)
				break


func _drop_flag(f: Fighter) -> void:
	var t := f.carrying
	f.carrying = -1
	var fl: Dictionary = flags[t]
	var p := f.global_position
	var void_fall := p.y < arena.kill_y + 2.0
	for hz in arena.hazards:
		if hz.has_point(p + Vector3(0, 0.2, 0)):
			void_fall = true
	if void_fall:
		_return_flag(t, -1)
		return
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1, 0), p + Vector3(0, -30, 0), 1)
	var hit := _space.intersect_ray(q) if _space else {}
	fl.state = "dropped"
	fl.carrier = -1
	fl.t = Data.FLAG_RETURN
	fl.pos = (hit.position if hit else p) + Vector3(0, 0.1, 0)
	host_event({"t": "flag", "k": "drop", "team": t, "f": f.id})


func _return_flag(t: int, by: int) -> void:
	var fl: Dictionary = flags[t]
	fl.state = "home"
	fl.carrier = -1
	fl.pos = arena.flags[t] + Vector3(0, 0.3, 0)
	host_event({"t": "flag", "k": "return", "team": t, "f": by})


func _check_win() -> void:
	if over:
		return
	if teams:
		for t in 2:
			if team_score[t] >= limit:
				_end_match()
				return
	else:
		for s in scores:
			if s.frags >= limit:
				_end_match()
				return


func _end_match() -> void:
	var res := {"t": "over", "team": -1, "f": -1}
	if teams:
		if team_score[0] != team_score[1]:
			res.team = 0 if team_score[0] > team_score[1] else 1
	else:
		var best := -1
		var tie := false
		for i in scores.size():
			if best < 0 or scores[i].frags > scores[best].frags:
				best = i
				tie = false
			elif scores[i].frags == scores[best].frags:
				tie = true
		res.f = best if not tie else -1
	host_event(res)


# --- events --------------------------------------------------------------------------------

## Host: something happened. It happens here, and on every guest. `skip_self` events are
## already shown here.
func host_event(e: Dictionary, skip_self := false, except_peer := 0) -> void:
	if not skip_self:
		_apply(e)
	if online:
		Net.broadcast_event(e, except_peer)


## A fighter's owner asks the host for something (a shot, a respawn).
func request(e: Dictionary) -> void:
	if host:
		_on_request(e, 1)
	else:
		Net.send_request(e)


func net_request(e: Dictionary, peer: int) -> void:
	if not host:
		return
	var fid := int(e.get("f", -1))
	if fid < 0 or fid >= fighters.size() or int(fighters[fid].info.get("peer", 1)) != peer:
		return
	_on_request(e, peer)


func net_event(e: Dictionary) -> void:
	if not host:
		_apply(e)


func _on_request(e: Dictionary, peer: int) -> void:
	var f := fighters[int(e.f)]
	match str(e.t):
		"fire":
			if not f.alive:
				return
			for h in e.h:
				var t := int(h[0])
				if t >= 0 and t < fighters.size():
					damage(fighters[t], f.id, int(h[1]), str(e.w), bool(h[2]))
			host_event({"t": "fx", "f": f.id, "w": e.w, "o": e.o, "e": e.e}, true, peer)
			if peer != 1:
				_apply({"t": "fx", "f": f.id, "w": e.w, "o": e.o, "e": e.e})
		"proj":
			if not f.alive:
				return
			if peer != 1:
				_add_projectile(int(e.id), str(e.w), e.o, e.v, f.id)
				_apply_shot_sound(f, str(e.w), e.o)
			host_event({"t": "proj", "id": e.id, "w": e.w, "o": e.o, "v": e.v, "f": f.id}, true, peer)
		"respawn":
			if not f.alive and not over:
				_respawn_wait[f.id] = 0.0
		"suicide":
			if f.alive and headless and OS.get_cmdline_user_args().has("--why"):
				print("FALL ", f.display_name(), " from ", f.get_meta("last_floor", Vector3.ZERO), " pad ", _clock - float(_pad_cool.get(f.id, -9.0)) + 0.5, " hit_by ", f.last_hit_by, " goal ", bots[f.id].goal_kind if bots.has(f.id) else "")
			if f.alive:
				# knocked off by someone in the last few seconds: their frag
				var killer := f.last_hit_by if _clock - float(f.get_meta("hit_at", -99.0)) < 4.0 else -1
				f.health = 0
				_kill(f, killer, str(e.c), false)


func _apply_shot_sound(f: Fighter, w: String, at: Vector3) -> void:
	_sound(w, at, -4.0)


func _apply(e: Dictionary) -> void:
	match str(e.t):
		"fx":
			var f := fighters[int(e.f)]
			if not f.local:
				_shot_fx(f, str(e.w), e.o, e.e)
		"proj":
			var f := fighters[int(e.f)]
			if not f.local:
				_add_projectile(int(e.id), str(e.w), e.o, e.v, f.id)
				_sound(str(e.w), e.o, -4.0)
		"boom":
			_local_explosion(int(e.id), str(e.w), e.p, -1)
		"dmg":
			var v := fighters[int(e.v)]
			v.health = int(e.h)
			v.armor = int(e.ar)
			v.pain_t = 0.4
			if int(e.a) == me and int(e.v) != me:
				Game.play("hit", -6.0)
				if hud:
					hud.hit_mark = 0.25
			if int(e.v) == me and hud:
				hud.on_hurt(int(e.a), int(e.n))
			if fx:
				fx.sparks(v.centre(), 4, Color(0.8, 0.1, 0.1), 3.0, 0.4, 0.07)
		"kill":
			_on_kill(e)
		"spawn":
			var f := fighters[int(e.f)]
			f.alive = true
			f.health = Data.START_HEALTH
			f.armor = 0
			f.powers = {}
			f.carrying = -1
			f.dead_t = 0.0
			f.spawn_t = 0.0
			f.last_hit_by = -1
			f.model.visible = f.id != me or demo
			f.model.position = Vector3.ZERO
			_hazard_sent.erase(f.id)
			_dead_hold.erase(f.id)
			f.global_position = e.p
			f.prev_pos = e.p
			f.yaw = float(e.y)
			f.snaps.clear()
			if f.local:
				f.velocity = Vector3.ZERO
				f.pitch = 0.0
				f.reset_loadout()
			if fx:
				fx.flash(f.global_position + Vector3(0, 1, 0), Color(1, 0.9, 0.6), 1.2, 0.35)
			if f.id == me:
				Game.play("respawn", -6.0)
		"pick":
			var i := int(e.i)
			var s: Dictionary = item_state[i]
			s.avail = false
			var f := fighters[int(e.f)]
			f.health = int(e.h)
			f.armor = int(e.ar)
			var kind: String = arena.items[i].kind
			if kind.begins_with("w:") and f.local:
				f.give_weapon(kind.substr(2))
			elif Data.ITEMS.has(kind) and Data.ITEMS[kind].has("power"):
				f.powers[Data.ITEMS[kind].power] = float(Data.ITEMS[kind].time)
			var snd := "weapon" if kind.begins_with("w:") else ("power" if Data.ITEMS[kind].has("power") else ("health" if Data.ITEMS[kind].has("health") else "armor"))
			if f.id == me:
				Game.play(snd, -3.0)
				if hud:
					hud.pickup_msg(kind)
			else:
				_sound(snd, f.global_position, -8.0)
		"flag":
			_on_flag(e)
		"over":
			over = true
			winner = e
			_over_t = 0.0
			if hud:
				hud.show_results()
			var won := false
			if me >= 0:
				won = int(e.f) == me if not teams else int(e.team) == fighters[me].team
			if not demo and not headless:
				Game.play("win" if won else "lose", -2.0)
			if not host:
				_over_t = 0.0
				get_tree().create_timer(8.0).timeout.connect(func(): finished.emit(winner))


func _on_kill(e: Dictionary) -> void:
	var v := fighters[int(e.v)]
	var k := int(e.k)
	v.alive = false
	v.health = mini(v.health, 0)
	v.dead_t = 0.0
	v.beam_on = false
	v.carrying = -1
	v.model.visible = true if v.id != me else false
	if v.id == me:
		v.model.visible = false
	if not host:
		scores[v.id].deaths += 0
	var w := str(e.w)
	var text := ""
	var col := Game.PALE
	if k >= 0 and k != v.id:
		var how: String = Data.WEAPONS[w].name if Data.WEAPONS.has(w) else w
		text = "%s  [%s]  %s" % [fighters[k].display_name(), how, v.display_name()]
		col = Data.team_color(fighters[k].team) if teams else Game.PALE
		if bool(e.get("hd", false)):
			text += "  (headshot)"
	else:
		var why := {"lava": "fell into the fire", "void": "fell into the void"}
		text = "%s %s" % [v.display_name(), why.get(w, "blew up")]
		col = Color(0.8, 0.75, 0.7)
	feed.append([text, col, 0.0])
	while feed.size() > 6:
		feed.pop_front()
	_sound("death", v.centre(), -2.0)
	if fx:
		fx.sparks(v.centre(), 14, Color(0.7, 0.08, 0.08), 4.0, 0.7, 0.09)
	if k == me and v.id != me:
		Game.play("frag", -4.0)
		if hud:
			hud.center_msg("You fragged %s" % v.display_name(), Game.GOLD)
	if v.id == me and hud:
		if k >= 0 and k != me:
			hud.center_msg("Fragged by %s" % fighters[k].display_name(), Game.BAD)
		else:
			hud.center_msg("You died", Game.BAD)


func _on_flag(e: Dictionary) -> void:
	var t := int(e.team)
	var f := int(e.f)
	var fl: Dictionary = flags[t]
	var who := fighters[f].display_name() if f >= 0 else ""
	var msg := ""
	match str(e.k):
		"take":
			fl.state = "carried"
			fl.carrier = f
			fighters[f].carrying = t
			msg = "%s took the %s flag!" % [who, Data.TEAM_NAMES[t]]
			if not headless:
				Game.play("flag_taken", -2.0)
		"drop":
			fl.state = "dropped"
			fighters[f].carrying = -1
			msg = "%s dropped the %s flag" % [who, Data.TEAM_NAMES[t]]
		"return":
			fl.state = "home"
			fl.pos = arena.flags[t] + Vector3(0, 0.3, 0)
			msg = "The %s flag is back home" % Data.TEAM_NAMES[t]
			if not headless:
				Game.play("flag_return", -3.0)
		"capture":
			fl.state = "home"
			fl.pos = arena.flags[t] + Vector3(0, 0.3, 0)
			fighters[f].carrying = -1
			msg = "%s captured the %s flag!" % [who, Data.TEAM_NAMES[t]]
			if not headless:
				Game.play("flag_capture", -1.0)
	if not host and str(e.k) == "capture":
		pass
	feed.append([msg, Data.team_color(t), 0.0])
	if hud:
		hud.center_msg(msg, Data.team_color(t))


# --- snapshots ------------------------------------------------------------------------------

## Host: the match in a few hundred bytes.
func pack_snapshot() -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_float(time_left)
	b.put_u8(1 if over else 0)
	b.put_16(team_score[0])
	b.put_16(team_score[1])
	b.put_float(warmup)
	b.put_u8(fighters.size())
	for f in fighters:
		var fl := (1 if f.alive else 0) | (2 if f.beam_on else 0) | (4 if f.is_on_floor() else 0)
		b.put_u8(fl)
		_put_vec(b, f.global_position)
		_put_vec(b, f.velocity if f.local else f.net_vel)
		b.put_float(f.yaw)
		b.put_float(f.pitch)
		b.put_u8(Data.WEAPON_ORDER.find(f.weapon))
		b.put_16(f.health)
		b.put_16(f.armor)
		b.put_u8(int(clampf(float(f.powers.get("overload", 0.0)), 0, 255)))
		b.put_u8(int(clampf(float(f.powers.get("haste", 0.0)), 0, 255)))
		b.put_8(f.carrying)
		b.put_16(scores[f.id].frags)
		b.put_16(scores[f.id].deaths)
		b.put_16(scores[f.id].caps)
	b.put_u16(item_state.size())
	for i in range(0, item_state.size(), 8):
		var bits := 0
		for k in 8:
			if i + k < item_state.size() and item_state[i + k].avail:
				bits |= 1 << k
		b.put_u8(bits)
	b.put_u8(flags.size())
	for fl in flags:
		b.put_u8(["home", "carried", "dropped"].find(fl.state))
		b.put_8(fl.carrier)
		_put_vec(b, fl.pos)
	return b.data_array


func apply_snapshot(data: PackedByteArray) -> void:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var now := Time.get_ticks_msec() * 0.001
	time_left = b.get_float()
	b.get_u8()
	team_score[0] = b.get_16()
	team_score[1] = b.get_16()
	warmup = b.get_float()
	var n := b.get_u8()
	for i in mini(n, fighters.size()):
		var f := fighters[i]
		var fl := b.get_u8()
		var pos := _get_vec(b)
		var vel := _get_vec(b)
		var y := b.get_float()
		var pt := b.get_float()
		var wi := b.get_u8()
		f.health = b.get_16()
		f.armor = b.get_16()
		var ov := b.get_u8()
		var ha := b.get_u8()
		f.powers = {}
		if ov > 0:
			f.powers.overload = float(ov)
		if ha > 0:
			f.powers.haste = float(ha)
		f.carrying = b.get_8()
		scores[i].frags = b.get_16()
		scores[i].deaths = b.get_16()
		scores[i].caps = b.get_16()
		if f.local:
			continue
		f.beam_on = fl & 2 != 0
		if wi < Data.WEAPON_ORDER.size():
			f.weapon = Data.WEAPON_ORDER[wi]
		if f.alive:
			f.add_snap(now, pos, y, pt, vel)
	var ni := b.get_u16()
	for i in range(0, ni, 8):
		var bits := b.get_u8()
		for k in 8:
			if i + k < item_state.size():
				item_state[i + k].avail = bits & (1 << k) != 0
	var nf := b.get_u8()
	for t in mini(nf, flags.size()):
		flags[t].state = ["home", "carried", "dropped"][b.get_u8()]
		flags[t].carrier = b.get_8()
		flags[t].pos = _get_vec(b)


## A guest: where its own fighters are.
func pack_state() -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	for f in fighters:
		if not f.local:
			continue
		b.put_u8(f.id)
		b.put_u8((1 if f.beam_on else 0) | (2 if f.alive else 0))
		_put_vec(b, f.global_position)
		_put_vec(b, f.velocity)
		b.put_float(f.yaw)
		b.put_float(f.pitch)
		b.put_u8(Data.WEAPON_ORDER.find(f.weapon))
	return b.data_array


## Host: a guest's fighter moved.
func net_state(peer: int, data: PackedByteArray) -> void:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var now := Time.get_ticks_msec() * 0.001
	while b.get_position() < data.size():
		var id := b.get_u8()
		var fl := b.get_u8()
		var pos := _get_vec(b)
		var vel := _get_vec(b)
		var y := b.get_float()
		var pt := b.get_float()
		var wi := b.get_u8()
		if id >= fighters.size():
			return
		var f := fighters[id]
		if int(f.info.get("peer", 1)) != peer or f.local:
			continue
		f.beam_on = fl & 1 != 0
		if wi < Data.WEAPON_ORDER.size():
			f.weapon = Data.WEAPON_ORDER[wi]
		if f.alive:
			f.add_snap(now, pos, y, pt, vel)


## Host: someone left; their fighter becomes a bot so the teams stay even.
func peer_left(peer: int) -> void:
	for f in fighters:
		if int(f.info.get("peer", 1)) == peer and not f.is_bot():
			f.info.peer = 1
			f.info.bot = 1
			f.info.name = str(f.info.name) + " (bot)"
			f.local = true
			f.snaps.clear()
			bots[f.id] = Bot.new(self, f)
			if f.alive:
				f.velocity = Vector3.ZERO


static func _put_vec(b: StreamPeerBuffer, v: Vector3) -> void:
	b.put_float(v.x)
	b.put_float(v.y)
	b.put_float(v.z)


static func _get_vec(b: StreamPeerBuffer) -> Vector3:
	return Vector3(b.get_float(), b.get_float(), b.get_float())


# --- for the HUD and menus ----------------------------------------------------------------

## The standings, best first: [{id, name, team, frags, deaths, caps}].
func standings() -> Array:
	var out := []
	for f in fighters:
		var s: Dictionary = scores[f.id]
		out.append({"id": f.id, "name": f.display_name(), "team": f.team, "frags": s.frags, "deaths": s.deaths, "caps": s.caps, "bot": f.is_bot(), "walker": f.walker()})
	out.sort_custom(func(a, b): return a.frags * 10 + a.caps * 50 > b.frags * 10 + b.caps * 50 if a.frags * 10 + a.caps * 50 != b.frags * 10 + b.caps * 50 else a.deaths < b.deaths)
	return out
