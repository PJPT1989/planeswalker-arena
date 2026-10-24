class_name Fighter
extends CharacterBody3D
## One planeswalker in the arena: a capsule that runs, jumps and is thrown by pads, the model
## (legs and arms swing as it runs, the right arm aims the weapon), the weapons it carries and
## its health. A fighter is either simulated here (`local`: the player on this computer, or a
## bot on the host), moved by its inputs with Quake-style ground and air acceleration, or a
## puppet that follows the network snapshots of whoever simulates it.

const STEP := 0.55

var mt: Match
var id := 0
var info := {}                 # name, walker, team, peer, bot (skill or -1)
var team := -1
var local := false
var alive := false
var yaw := 0.0
var pitch := 0.0
var health := 100
var armor := 0
var weapons := {}              # weapon -> ammo (-1: needs none)
var weapon := "repeater"
var last_weapon := "blade"
var cool := 0.0                # seconds until the next shot
var raise_t := 0.0             # weapon switch: seconds until it can fire
var powers := {}               # "overload"/"haste" -> seconds left (the host decides)
var carrying := -1             # the team whose flag this fighter carries
var firing := false            # holding fire (the beam shows while it fires)
var beam_on := false
# inputs (local fighters)
var move_in := Vector2.ZERO    # x right, y forward, -1..1
var jump_in := false
var fire_in := false
var zoom := false
# movement state
var launched := 0.0
var air_t := 0.0
var prev_pos := Vector3.ZERO
var land_vel := 0.0
var spawn_t := 0.0             # time since spawning (a short shimmer)
var dead_t := 0.0
var last_hit_by := -1
var pain_t := 0.0
# puppet interpolation: [time, pos, yaw, pitch, vel]
var snaps := []
var net_vel := Vector3.ZERO
# model
var model: Node3D
var _hips: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _cape: Node3D
var _held: MeshInstance3D
var _held_w := ""
var _flag_mi: MeshInstance3D
var _glow_mi: MeshInstance3D
var _phase := 0.0
var _death_spin := 0.0


func setup(m: Match, i: int, d: Dictionary) -> void:
	mt = m
	id = i
	info = d
	team = int(d.get("team", -1))
	name = "Fighter%d" % i
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(47.0)
	floor_snap_length = 0.45
	floor_block_on_wall = false
	floor_constant_speed = true
	wall_min_slide_angle = deg_to_rad(10.0)
	safe_margin = 0.02
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = Data.RADIUS
	cap.height = Data.HEIGHT
	cs.shape = cap
	cs.position.y = Data.HEIGHT * 0.5
	add_child(cs)
	_build_model()


func is_bot() -> bool:
	return int(info.get("bot", -1)) >= 0


func display_name() -> String:
	return str(info.get("name", "?"))


func walker() -> String:
	return str(info.get("walker", "chandra"))


func eye() -> Vector3:
	return global_position + Vector3(0, Data.EYE, 0)


func centre() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


func aim_dir() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func power(p: String) -> bool:
	return float(powers.get(p, 0.0)) > 0.0


# --- loadout ---------------------------------------------------------------------------

## Back to the start loadout (after spawning).
func reset_loadout() -> void:
	weapons = {}
	for w in Data.START_WEAPONS:
		weapons[w] = Data.WEAPONS[w].ammo[0]
	weapon = "repeater"
	last_weapon = "blade"
	cool = 0.0
	raise_t = 0.3


func has_ammo(w: String) -> bool:
	return weapons.has(w) and (int(weapons[w]) < 0 or int(weapons[w]) > 0)


## Picks up a weapon (or its ammo). Returns true if anything changed; switches to it if new
## and better than what is held (like the originals do).
func give_weapon(w: String) -> bool:
	var a: Array = Data.WEAPONS[w].ammo
	var had := weapons.has(w)
	var before := int(weapons.get(w, 0))
	var now := mini(int(a[2]), (before if had else 0) + (int(a[0]) if not had else int(a[1])))
	weapons[w] = now
	if not had and Data.WEAPON_ORDER.find(w) > Data.WEAPON_ORDER.find(weapon) and not firing:
		switch_to(w)
	return not had or now != before


func switch_to(w: String) -> void:
	if w == weapon or not has_ammo(w):
		return
	last_weapon = weapon
	weapon = w
	raise_t = 0.25
	if local and not is_bot():
		Game.play("switch", -8.0)


## The next weapon with ammo, up or down the list.
func cycle(dir: int) -> void:
	var i := Data.WEAPON_ORDER.find(weapon)
	for k in Data.WEAPON_ORDER.size():
		i = posmod(i + dir, Data.WEAPON_ORDER.size())
		if has_ammo(Data.WEAPON_ORDER[i]):
			switch_to(Data.WEAPON_ORDER[i])
			return


## Out of ammo: the best weapon that still has some.
func auto_switch() -> void:
	for i in range(Data.WEAPON_ORDER.size() - 1, -1, -1):
		var w: String = Data.WEAPON_ORDER[i]
		if w != "blade" and has_ammo(w) and w != "disintegrate":
			switch_to(w)
			return
	switch_to("blade")


# --- movement (local fighters) ------------------------------------------------------------

## Walks up a low ledge (a stair side, a kerb) the way Quake does: lift, move, drop back.
func _step_up(motion: Vector3) -> void:
	if motion.length() < 0.01:
		return
	var t := global_transform
	if test_move(t, Vector3(0, STEP, 0)):
		return
	global_position = t.origin + Vector3(0, STEP, 0)
	move_and_collide(motion)
	var gained := Vector2(global_position.x - t.origin.x, global_position.z - t.origin.z).length()
	if gained < motion.length() * 0.3:
		global_transform = t
		return
	var hit := move_and_collide(Vector3(0, -STEP - 0.1, 0))
	# landing on the corner of the ledge is fine: the next slide settles on top
	if hit == null or hit.get_normal().y < 0.2 or global_position.y < t.origin.y + 0.02:
		global_transform = t
		return
	velocity.x = motion.x / get_physics_process_delta_time()
	velocity.z = motion.z / get_physics_process_delta_time()
	velocity.y = 0.0


func physics_step(dt: float) -> void:
	prev_pos = global_position
	cool = maxf(0.0, cool - dt)
	raise_t = maxf(0.0, raise_t - dt)
	spawn_t += dt
	if not alive:
		return
	var speed := Data.RUN_SPEED * (Data.HASTE_MULT if power("haste") else 1.0)
	var fwd := forward_flat()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var wish := fwd * move_in.y + right * move_in.x
	if wish.length() > 1.0:
		wish = wish.normalized()
	var wish_speed := wish.length() * speed
	if wish_speed > 0.0:
		wish = wish.normalized()
	var v := velocity
	var grounded := is_on_floor() and launched <= 0.0
	launched = maxf(0.0, launched - dt)
	if grounded:
		if air_t > 0.35:
			land_vel = 1.0
			if not is_bot():
				Game.play("land", -10.0)
		air_t = 0.0
		var hs := Vector2(v.x, v.z).length()
		if hs > 0.0:
			var drop := maxf(hs, Data.STOP_SPEED) * Data.FRICTION * dt
			var k := maxf(hs - drop, 0.0) / hs
			v.x *= k
			v.z *= k
		v = _accelerate(v, wish, wish_speed, Data.GROUND_ACCEL, dt)
		if jump_in:
			v.y = Data.JUMP_SPEED
			if local and not is_bot():
				Game.play("jump", -12.0)
			launched = 0.1
		else:
			v.y = minf(v.y, 0.0)
	else:
		air_t += dt
		v = _accelerate(v, wish, wish_speed, Data.AIR_ACCEL, dt)
		v.y -= Data.GRAVITY * dt
	velocity = v
	if launched > 0.0:
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.45
	move_and_slide()
	if grounded and is_on_wall() and wish_speed > 0.0:
		_step_up(wish * maxf(Vector2(v.x, v.z).length(), wish_speed * 0.5) * dt)
	# bumping a ceiling stops the climb
	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0


func _accelerate(v: Vector3, wish: Vector3, wish_speed: float, accel: float, dt: float) -> Vector3:
	if wish_speed <= 0.0:
		return v
	var cur := Vector3(v.x, 0, v.z).dot(wish)
	var add := wish_speed - cur
	if add <= 0.0:
		return v
	var acc := minf(accel * dt * wish_speed, add)
	return v + wish * acc


## Thrown by a jump pad.
func launch(vel: Vector3) -> void:
	velocity = vel
	launched = 0.35
	air_t = 0.0


func teleport(p: Vector3, y: float) -> void:
	global_position = p
	prev_pos = p
	yaw = y
	velocity = forward_flat() * 7.0
	snaps.clear()


## Pushed by an explosion.
func push(impulse: Vector3) -> void:
	velocity += impulse
	if impulse.y > 1.0:
		launched = maxf(launched, 0.15)


# --- puppets --------------------------------------------------------------------------------

func add_snap(t: float, p: Vector3, y: float, pt: float, v: Vector3) -> void:
	snaps.append([t, p, y, pt, v])
	while snaps.size() > 8:
		snaps.pop_front()


## Puppets show where they were 100 ms ago, between two snapshots (extrapolated a little if late).
func puppet_update(now: float) -> void:
	if snaps.is_empty():
		return
	var t := now - 0.1
	var a: Array = snaps[0]
	var b: Array = snaps[snaps.size() - 1]
	for i in range(snaps.size() - 1):
		if snaps[i][0] <= t and snaps[i + 1][0] >= t:
			a = snaps[i]
			b = snaps[i + 1]
			break
	var pos: Vector3
	var y: float
	var pt: float
	if t >= b[0]:
		var late := minf(t - float(b[0]), 0.25)
		pos = b[1] + b[4] * late
		y = b[2]
		pt = b[3]
	elif t <= a[0]:
		pos = a[1]
		y = a[2]
		pt = a[3]
	else:
		var f: float = (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
		pos = (a[1] as Vector3).lerp(b[1], f)
		y = lerp_angle(float(a[2]), float(b[2]), f)
		pt = lerpf(float(a[3]), float(b[3]), f)
	prev_pos = global_position
	global_position = pos
	yaw = y
	pitch = pt
	net_vel = b[4]


# --- model ----------------------------------------------------------------------------------

func _build_model() -> void:
	var tc := Data.team_color(team) if team >= 0 else Color(Data.WALKERS[walker()].trim)
	var parts := Models.walker_parts(walker(), tc)
	var b: float = Data.WALKERS[walker()].build
	model = Node3D.new()
	add_child(model)
	_hips = _pivot(model, Vector3(0, 0.92, 0), parts.torso)
	_head = _pivot(_hips, Vector3(0, 0.54, 0), parts.head)
	_arm_l = _pivot(_hips, Vector3(-0.27 * b, 0.47, 0), parts.arm_l)
	_arm_r = _pivot(_hips, Vector3(0.27 * b, 0.47, 0), parts.arm_r)
	_leg_l = _pivot(model, Vector3(-0.1 * b, 0.92, 0), parts.leg_l)
	_leg_r = _pivot(model, Vector3(0.1 * b, 0.92, 0), parts.leg_r)
	if parts.cape:
		_cape = _pivot(_hips, Vector3(0, 0.5, 0), parts.cape)
	_held = MeshInstance3D.new()
	_held.position = Vector3(0, -0.6, -0.02)
	_held.rotation.x = -PI * 0.5
	_arm_r.add_child(_held)
	_flag_mi = MeshInstance3D.new()
	_flag_mi.position = Vector3(0.1, -0.3, 0.3)
	_flag_mi.rotation = Vector3(0.25, 0, 0.15)
	_flag_mi.visible = false
	_hips.add_child(_flag_mi)
	var k := MeshKit.new()
	k.sphere(Vector3(0, 1.0, 0), Vector3(0.65, 1.05, 0.65), Color(1, 1, 1, 0.25), 10, 6)
	_glow_mi = MeshInstance3D.new()
	_glow_mi.mesh = k.commit(null, [Game.mat_fx, Game.mat_fx, Game.mat_fx])
	_glow_mi.visible = false
	_glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_glow_mi)


func _pivot(parent: Node3D, at: Vector3, mesh: Mesh) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	n.add_child(mi)
	return n


## Hides the model (first person) or shows it.
func show_model(on: bool) -> void:
	model.visible = on


## Animates the model; `frac` is how far between two physics steps this frame is.
func animate(dt: float, frac: float) -> void:
	if local:
		model.global_position = prev_pos.lerp(global_position, frac)
	else:
		model.position = Vector3.ZERO
	if _held_w != weapon:
		_held_w = weapon
		_held.mesh = Models.weapon(weapon)
	_flag_mi.visible = carrying >= 0
	if carrying >= 0:
		_flag_mi.mesh = Models.flag(carrying)
	var pw := power("overload") or power("haste")
	_glow_mi.visible = pw or (alive and spawn_t < 1.0)
	if _glow_mi.visible:
		var gc := Data.ITEMS.overload.color if power("overload") else (Data.ITEMS.haste.color if power("haste") else Color(1, 1, 1))
		_glow_mi.material_override = _glow_mat(gc)
	if not alive:
		dead_t += dt
		_death_spin = minf(1.0, _death_spin + dt * 2.5)
		model.rotation.x = -_death_spin * PI * 0.5
		model.position.y = -minf(maxf(dead_t - 2.0, 0.0) * 0.4, 1.0)
		model.visible = dead_t < 4.5 and model.visible
		return
	_death_spin = 0.0
	model.rotation.x = 0.0
	model.rotation.y = yaw
	var vel := velocity if local else net_vel
	var hs := Vector2(vel.x, vel.z).length()
	var on_ground := is_on_floor() if local else absf(vel.y) < 1.5
	_phase += dt * hs * 1.15
	var swing := clampf(hs / Data.RUN_SPEED, 0.0, 1.0) * 0.75 if on_ground else 0.0
	# which way the legs move relative to facing: running backwards swings them the other way
	var fwd := forward_flat()
	var along := signf(Vector3(vel.x, 0, vel.z).dot(fwd)) if hs > 0.5 else 1.0
	var s := sin(_phase) * swing * along
	_leg_l.rotation.x = s
	_leg_r.rotation.x = -s
	if not on_ground:
		_leg_l.rotation.x = 0.5
		_leg_r.rotation.x = -0.2
	_arm_l.rotation.x = -s * 0.8
	_arm_r.rotation.x = PI * 0.5 + pitch * 0.9 - (0.15 if cool > 0.05 else 0.0)
	_arm_r.rotation.z = 0.12
	_head.rotation.x = pitch * 0.5
	_hips.rotation.x = -pitch * 0.12
	if _cape:
		_cape.rotation.x = -0.1 - swing * 0.45 - (0.4 if not on_ground else 0.0)


static var _glow_mats := {}


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _glow_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(c.r, c.g, c.b, 0.22)
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_glow_mats[key] = m
	return _glow_mats[key]
