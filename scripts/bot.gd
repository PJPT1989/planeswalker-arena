class_name Bot
extends RefCounted
## A computer player, run on the host. It picks a goal (a weapon it lacks, health when hurt,
## armour, an enemy it heard, the enemy flag, its own stolen flag, home with a captured flag),
## walks there along the navigation mesh (pads, portals and ledge drops are links in it),
## looks for enemies it can see, picks the weapon that suits the distance, leads moving
## targets with projectiles, strafes and jumps while fighting. Skill (Data.SKILLS) sets how
## well it aims, how quickly it reacts and turns, and how much it dodges.

var m: Match
var f: Fighter
var skill: Dictionary
var role := "attack"            # Capture the Flag: attack, defend or roam
var goal := Vector3.ZERO
var goal_kind := ""
var goal_t := 0.0
var path := PackedVector3Array()
var path_i := 0
var path_t := 0.0
var target := -1
var seen_t := 0.0                # how long the target has been in sight
var lost_t := 9.0
var last_seen := Vector3.ZERO
var think_t := 0.0
var strafe := 1.0
var strafe_t := 0.0
var aim_err := Vector2.ZERO
var aim_err_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var stuck_count := 0
var _unstick := Vector3.ZERO
var _unstick_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(match_node: Match, fighter: Fighter) -> void:
	m = match_node
	f = fighter
	skill = Data.SKILLS[clampi(int(f.info.get("bot", 1)), 0, Data.SKILLS.size() - 1)]
	_rng.seed = hash(f.id * 7919 + int(m.cfg.get("seed", 0)))
	if m.mode == Data.CTF:
		var mates := 0
		for o in m.fighters:
			if o.team == f.team and o.id < f.id:
				mates += 1
		role = ["attack", "defend", "attack", "roam", "attack", "defend"][mates % 6]


func update(dt: float) -> void:
	if not f.alive:
		f.move_in = Vector2.ZERO
		f.fire_in = false
		f.jump_in = false
		path = PackedVector3Array()
		target = -1
		return
	think_t -= dt
	if think_t <= 0.0:
		think_t = 0.12 + _rng.randf() * 0.06
		_look_for_enemies()
		_choose_goal(dt)
	path_t -= dt
	if path_t <= 0.0 or path.is_empty():
		_repath()
	_steer(dt)
	_aim_and_fire(dt)


# --- seeing -------------------------------------------------------------------------------

func _visible(o: Fighter) -> bool:
	var q := PhysicsRayQueryParameters3D.create(f.eye(), o.centre() + Vector3(0, 0.3, 0), 1)
	return m._space.intersect_ray(q).is_empty()


func _look_for_enemies() -> void:
	var best := -1
	var best_score := 1e9
	for o in m.fighters:
		if o == f or not o.alive or (m.teams and o.team == f.team):
			continue
		var d := f.global_position.distance_to(o.global_position)
		if d > 90.0:
			continue
		# roughly in front of it, or very close, or someone who just hit it
		var to := (o.centre() - f.eye()).normalized()
		var facing := to.dot(f.aim_dir())
		if facing < -0.2 and d > 6.0 and f.last_hit_by != o.id:
			continue
		if not _visible(o):
			continue
		var score := d - (25.0 if o.carrying >= 0 else 0.0) - (10.0 if o.id == target else 0.0)
		if score < best_score:
			best_score = score
			best = o.id
	if best != target:
		if best >= 0 and target >= 0 and lost_t < 0.5:
			seen_t = minf(seen_t, float(skill.react) * 0.5)
		elif best >= 0:
			seen_t = 0.0
		target = best if best >= 0 else target
	if best >= 0:
		lost_t = 0.0
		last_seen = m.fighters[best].global_position
	else:
		lost_t += 0.15
		if lost_t > 1.5:
			target = -1


# --- goals --------------------------------------------------------------------------------

func _choose_goal(dt: float) -> void:
	goal_t -= 0.15
	var want := ""
	var at := Vector3.ZERO
	if m.mode == Data.CTF:
		var mine: Dictionary = m.flags[f.team]
		var theirs: Dictionary = m.flags[1 - f.team]
		if f.carrying >= 0:
			want = "home"
			at = m.arena.flags[f.team]
		elif mine.state != "home" and (role != "attack" or f.global_position.distance_to(mine.pos) < 30.0):
			want = "chase"
			at = mine.pos
		elif role == "attack" or (role == "roam" and theirs.state != "home"):
			if theirs.state == "carried":
				# escort the carrier
				want = "escort"
				at = m.fighters[theirs.carrier].global_position
			else:
				want = "flag"
				at = theirs.pos
		elif role == "defend" and f.health > 50 and _has_good_weapon():
			want = "defend"
			at = goal if goal_kind == "defend" and goal_t > 0.0 else _near(m.arena.flags[f.team], 9.0)
	if want == "" or (want in ["flag", "defend", "escort"] and (f.health < 45 or not _has_good_weapon()) and target < 0):
		var item := _best_item()
		if item >= 0:
			want = "item"
			at = m.arena.items[item].pos
		elif want == "":
			if target >= 0:
				want = "fight"
				at = m.fighters[target].global_position
			elif goal_kind == "roam" and goal_t > 0.0 and f.global_position.distance_to(goal) > 3.0:
				return
			else:
				want = "roam"
				at = _roam_point()
	if want != goal_kind or at.distance_to(goal) > 4.0:
		goal_kind = want
		goal = at
		goal_t = 8.0
		path_t = 0.0


func _has_good_weapon() -> bool:
	for w in ["thunder", "pulse", "lash", "fireball", "disintegrate"]:
		if f.has_ammo(w):
			return true
	return false


## The pickup worth walking to: wanted, there, and not too far for what it gives.
func _best_item() -> int:
	var best := -1
	var best_v := 0.0
	for i in m.arena.items.size():
		if not m.item_state[i].avail:
			continue
		var it: Dictionary = m.arena.items[i]
		var kind: String = it.kind
		var v := 0.0
		if kind.begins_with("w:"):
			var w := kind.substr(2)
			if not f.weapons.has(w):
				v = 60.0 + float(Data.WEAPONS[w].bot[2]) * 40.0
			elif int(f.weapons[w]) < int(Data.WEAPONS[w].ammo[1]):
				v = 20.0
		else:
			var d: Dictionary = Data.ITEMS[kind]
			if d.has("health") and f.health < int(d.cap):
				v = float(d.health) * (2.5 if f.health < 50 else 0.8)
			elif d.has("armor") and f.armor < int(d.cap):
				v = float(d.armor) * 0.9 + 6.0
			elif d.has("power"):
				v = 90.0
		if v <= 0.0:
			continue
		var dist: float = f.global_position.distance_to(it.pos)
		v = v / (1.0 + dist / 18.0)
		if v > best_v:
			best_v = v
			best = i
	return best if best_v > 4.0 else -1


func _roam_point() -> Vector3:
	var pts := m.arena.items
	if pts.is_empty() or _rng.randf() < 0.4:
		var s: Dictionary = m.arena.spawns[_rng.randi() % m.arena.spawns.size()]
		return s.pos
	return pts[_rng.randi() % pts.size()].pos


func _near(p: Vector3, r: float) -> Vector3:
	var a := _rng.randf() * TAU
	var map := m.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, p + Vector3(cos(a), 0, sin(a)) * r * _rng.randf_range(0.3, 1.0))


# --- walking ------------------------------------------------------------------------------

func _repath() -> void:
	path_t = 0.9 + _rng.randf() * 0.4
	var map := m.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	var to := goal
	if goal_kind == "fight" and target >= 0:
		to = m.fighters[target].global_position
	path = NavigationServer3D.map_get_path(map, f.global_position, to, true)
	path_i = 1 if path.size() > 1 else 0


func _steer(dt: float) -> void:
	var p := f.global_position
	var want := Vector3.ZERO
	if not path.is_empty():
		while path_i < path.size() - 1:
			var d := path[path_i] - p
			if Vector2(d.x, d.z).length() < 0.7 and absf(d.y) < 2.5:
				path_i += 1
			else:
				break
		var nxt := path[mini(path_i, path.size() - 1)]
		want = nxt - p
		want.y = 0.0
		if want.length() < 0.5 and path_i >= path.size() - 1:
			want = Vector3.ZERO
	# flying from a pad: hands off, let it land
	var flying := f.launched > 0.0 or not f.is_on_floor()
	var fighting := target >= 0 and lost_t < 0.3
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = _rng.randf_range(0.4, 1.3)
		strafe = -strafe if _rng.randf() < 0.75 else strafe
	var move := want.normalized() if want.length() > 0.1 else Vector3.ZERO
	if fighting:
		var t := m.fighters[target]
		var to := t.global_position - p
		to.y = 0
		var side := Vector3(-to.z, 0, to.x).normalized() * strafe
		var dist := to.length()
		var keep := Vector3.ZERO
		var pref: Array = Data.WEAPONS[f.weapon].bot
		if dist < float(pref[0]) + 2.0:
			keep = -to.normalized()
		elif dist > float(pref[1]) * 0.8 and goal_kind == "fight":
			keep = to.normalized()
		var dodge := float(skill.dodge)
		if goal_kind in ["home", "flag", "item", "chase"]:
			move = (move * 1.0 + side * dodge * 0.5).normalized() if move != Vector3.ZERO else side
		else:
			move = (move * (1.0 - dodge * 0.6) + side * dodge + keep * 0.6)
			if move.length() > 0.05:
				move = move.normalized()
		# hop now and then while fighting
		f.jump_in = _rng.randf() < 0.015 * dodge and f.is_on_floor() and _safe(p, Vector3(f.velocity.x, 0, f.velocity.z) + move * 0.1)
	else:
		f.jump_in = false
	# never step off a ledge into the void or the fire (unless the path says to)
	var dropping := path_i < path.size() and path[path_i].y < p.y - 1.0 and want.length() > 0.1
	if move.length() > 0.1 and f.is_on_floor() and not dropping:
		if not _safe(p, move):
			var path_dir := want.normalized() if want.length() > 0.1 else Vector3.ZERO
			if path_dir != Vector3.ZERO and _safe(p, path_dir):
				move = path_dir
			else:
				move = Vector3.ZERO
			strafe = -strafe
	# stuck: not moving while it wants to
	if move.length() > 0.1 and f.is_on_floor():
		if p.distance_to(last_pos) < 0.04 * 60.0 * dt:
			stuck_t += dt
		else:
			stuck_t = maxf(0.0, stuck_t - dt * 2.0)
	last_pos = p
	if stuck_t > 0.6:
		f.jump_in = true
	if stuck_t > 1.6:
		stuck_t = 0.0
		stuck_count += 1
		m.stats.stuck += 1
		if m.headless and OS.get_cmdline_user_args().has("--why"):
			print("STUCK ", f.display_name(), " at ", p.snapped(Vector3.ONE * 0.1), " goal ", goal_kind, " next ", path[path_i] if path_i < path.size() else Vector3.ZERO)
		path_t = 0.0
		goal_t = 0.0
		goal_kind = ""
		# back off sideways for a moment, then try again
		var w := want.normalized() if want.length() > 0.1 else Vector3.FORWARD
		_unstick = (Vector3(-w.z, 0, w.x) * (1.0 if _rng.randf() < 0.5 else -1.0) - w * 0.5).normalized()
		_unstick_t = 0.5
	if _unstick_t > 0.0:
		_unstick_t -= dt
		move = _unstick
		f.jump_in = false
	# in the air (a pad, a jump, a blast) it keeps its hands off: steering could miss the landing
	if flying:
		move = Vector3.ZERO
	# world direction to the fighter's own right/forward input
	var fwd := f.forward_flat()
	var right := Vector3(-fwd.z, 0, fwd.x)
	f.move_in = Vector2(move.dot(right), move.dot(fwd))
	# not looking at anyone: face where it walks
	if not fighting and want.length() > 0.3:
		var yaw_want := atan2(-want.x, -want.z)
		f.yaw = _turn(f.yaw, yaw_want, float(skill.turn) * 0.7 * dt)
		f.pitch = lerpf(f.pitch, 0.0, minf(1.0, dt * 3.0))


## True if a step that way has floor under it (not the void, not lava).
func _safe(p: Vector3, dir: Vector3) -> bool:
	var reach := 1.4 + Vector2(f.velocity.x, f.velocity.z).length() * 0.12
	var at := p + dir.normalized() * reach + Vector3(0, 2.0, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3(0, -30.0, 0), 1)
	var hit := m._space.intersect_ray(q)
	if hit.is_empty():
		return false
	for hz in m.arena.hazards:
		if hz.has_point(hit.position + Vector3(0, 0.3, 0)):
			return false
	return true


func _turn(from: float, to: float, max_step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -max_step, max_step)


# --- fighting -----------------------------------------------------------------------------

func _aim_and_fire(dt: float) -> void:
	f.fire_in = false
	if target < 0 or lost_t > 0.3:
		f.beam_on = false
		return
	var t := m.fighters[target]
	if not t.alive:
		target = -1
		return
	seen_t += dt
	var dist := f.eye().distance_to(t.centre())
	_pick_weapon(dist)
	var wd: Dictionary = Data.WEAPONS[f.weapon]
	var aim_at := t.centre() + Vector3(0, 0.25, 0)
	var tv := t.velocity if t.local else t.net_vel
	if wd.kind == "projectile":
		var tt := dist / float(wd.speed)
		aim_at += tv * tt * float(skill.lead)
		if f.weapon == "fireball" and t.global_position.y <= f.global_position.y + 0.5:
			aim_at.y = t.global_position.y + 0.15
	elif f.weapon == "disintegrate" and skill.aim < 0.05:
		aim_at = t.global_position + Vector3(0, 1.55, 0)
	aim_err_t -= dt
	if aim_err_t <= 0.0:
		aim_err_t = _rng.randf_range(0.2, 0.5)
		var e := float(skill.aim) * (1.0 + clampf(tv.length() / 9.0, 0.0, 1.0))
		aim_err = Vector2(_rng.randfn(0.0, e), _rng.randfn(0.0, e * 0.6))
	var d := aim_at - f.eye()
	var yaw_want := atan2(-d.x, -d.z) + aim_err.x
	var pitch_want := atan2(d.y, Vector2(d.x, d.z).length()) + aim_err.y
	var turn := float(skill.turn) * dt
	f.yaw = _turn(f.yaw, yaw_want, turn)
	f.pitch = clampf(f.pitch + clampf(pitch_want - f.pitch, -turn, turn), -1.4, 1.4)
	if seen_t < float(skill.react):
		return
	var off := absf(wrapf(yaw_want - aim_err.x - f.yaw, -PI, PI)) + absf(pitch_want - aim_err.y - f.pitch) * 0.7
	var tol := 0.09 if wd.kind != "pellets" else 0.16
	if wd.kind == "projectile" and wd.radius > 2.0:
		tol = 0.13
	if dist > float(wd.get("range", 200.0)) + 1.0:
		return
	# never fire a fireball into its own face
	if f.weapon == "fireball" and dist < 3.0:
		return
	if off < tol + 1.2 / maxf(dist, 1.0) * 0.5:
		f.fire_in = true


func _pick_weapon(dist: float) -> void:
	if f.raise_t > 0.0 or f.cool > 0.2:
		return
	var best := f.weapon
	var best_v := -1.0
	for w in Data.WEAPON_ORDER:
		if not f.has_ammo(w):
			continue
		var b: Array = Data.WEAPONS[w].bot
		var v := float(b[2])
		if dist < float(b[0]) or dist > float(b[1]):
			v *= 0.25
		if w == f.weapon:
			v += 0.08
		if v > best_v:
			best_v = v
			best = w
	if best != f.weapon:
		f.switch_to(best)
