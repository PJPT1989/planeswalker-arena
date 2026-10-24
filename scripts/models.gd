class_name Models
extends RefCounted
## Low-poly models built with MeshKit: the planeswalkers (separate parts so Fighter can swing
## legs and arms), the seven weapons (held in first and third person and lying as pickups),
## health, armour and power-up pickups, the flags, jump pads and portals. Meshes are cached.
## Everything faces -Z; characters stand on y = 0 and are 1.8 m tall.

static var _cache := {}


static func _kit() -> MeshKit:
	return MeshKit.new()


# --- planeswalkers -----------------------------------------------------------------------

## The body parts of a planeswalker in a team colour: {"torso", "head", "arm_l", "arm_r",
## "leg_l", "leg_r", "cape"(may be null)}. Parts are modelled around their own pivot
## (Fighter places the pivots: hips 0.92, neck 1.46, shoulders 1.38 at x = +-0.25*build).
static func walker_parts(id: String, team_col: Color) -> Dictionary:
	var key := "w:%s:%s" % [id, team_col.to_html()]
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary = Data.WALKERS[id]
	var b: float = d.build
	var parts := {}
	parts.torso = _torso(d, b, team_col)
	parts.head = _head(d, b, team_col)
	parts.arm_l = _arm(d, b, team_col, false)
	parts.arm_r = _arm(d, b, team_col, true)
	parts.leg_l = _leg(d, b, team_col)
	parts.leg_r = parts.leg_l
	parts.cape = _cape(d, b, team_col) if d.extra == "cape" or id == "liliana" or id == "teferi" else null
	_cache[key] = parts
	return parts


static func _torso(d: Dictionary, b: float, tc: Color) -> ArrayMesh:
	var k := _kit()
	var main: Color = d.main
	var second: Color = d.second
	var trim: Color = d.trim
	var golem: bool = d.extra == "golem"
	# pelvis to shoulders, a lofted chest (origin at the hips)
	var rows := []
	var prof := [[0.0, 0.17, 0.12], [0.14, 0.16, 0.11], [0.3, 0.2, 0.13], [0.46, 0.25, 0.15], [0.54, 0.22, 0.13]]
	for p in prof:
		var row := PackedVector3Array()
		for j in 10:
			var a := TAU * j / 10.0
			row.append(Vector3(cos(a) * p[1] * b, p[0], sin(a) * p[2] * (0.9 + b * 0.1)))
		rows.append(row)
	if golem:
		k.gloss = true
	k.loft(rows, func(t, a, c, n): return main if t > 0.25 else second)
	k.gloss = false
	# belt and team sash
	k.box(Vector3(0, 0.1, 0), Vector3(0.36 * b, 0.07, 0.25), second.darkened(0.3))
	k.box(Vector3(0, 0.1, -0.13), Vector3(0.08, 0.06, 0.03), trim)
	k.xf = Transform3D(Basis(Vector3.FORWARD, 0.75), Vector3(0, 0.32, 0))
	k.box(Vector3.ZERO, Vector3(0.07, 0.62 * b, 0.27), tc)
	k.xf = Transform3D.IDENTITY
	# shoulder pads
	for s in [-1, 1]:
		var sp := Vector3(s * 0.25 * b, 0.47, 0)
		if golem or d.name == "Gideon" or d.name == "Ajani":
			k.gloss = true
			k.sphere(sp + Vector3(0, 0.02, 0), Vector3(0.12, 0.08, 0.12) * b, trim if not golem else main.lightened(0.1), 8, 4)
			k.gloss = false
		else:
			k.sphere(sp, Vector3(0.09, 0.06, 0.1) * b, main.darkened(0.15), 6, 3)
	# hip skirt or coat tails
	if d.name in ["Liliana", "Teferi", "Sorin", "Jace", "Kaya", "Vraska"]:
		k.taper(Vector3(0, -0.42, 0), Vector2(0.5 * b, 0.36), Vector2(0.34 * b, 0.26), 0.46, main.darkened(0.1))
	# chest details
	match d.extra:
		"golem":
			k.box(Vector3(0, 0.38, -0.14), Vector3(0.2, 0.12, 0.04), d.glow, true)
		"coil":
			k.cyl(Vector3(0.0, 0.2, 0.15), Vector3(0, 0.5, 0.17), 0.06, 0.06, second, 8)
			k.ring(Vector3(0, 0.3, 0.17), Vector3.UP, 0.07, 0.015, d.glow, 8, 3, true)
		_:
			k.box(Vector3(0, 0.38, -0.145), Vector3(0.06, 0.06, 0.02), d.glow, true)
	return k.commit()


static func _head(d: Dictionary, b: float, tc: Color) -> ArrayMesh:
	var k := _kit()
	var skin: Color = d.skin
	var hc: Color = d.hair_col
	var glow: Color = d.glow
	# neck and head (origin at the neck)
	k.cyl(Vector3(0, 0, 0), Vector3(0, 0.1, 0), 0.06, 0.06, skin.darkened(0.1), 6)
	var hs := Vector3(0.1, 0.13, 0.115)
	var hc0 := Vector3(0, 0.2, 0)
	match d.hair:
		"mane":
			# leonin: muzzle and a big mane
			k.sphere(hc0, hs * 1.1, skin, 8, 5)
			k.box(hc0 + Vector3(0, -0.04, -0.11), Vector3(0.1, 0.07, 0.08), skin.lightened(0.15))
			k.box(hc0 + Vector3(0, -0.01, -0.155), Vector3(0.04, 0.03, 0.02), Color(0.2, 0.12, 0.1))
			k.sphere(hc0 + Vector3(0, 0.0, 0.03), Vector3(0.2, 0.2, 0.17), hc, 9, 5)
			for s in [-1, 1]:
				k.cyl(hc0 + Vector3(s * 0.08, 0.12, 0), hc0 + Vector3(s * 0.1, 0.19, 0), 0.035, 0.0, skin, 4)
		"golem":
			pass
		_:
			k.sphere(hc0, hs, skin, 8, 5)
			k.box(hc0 + Vector3(0, -0.01, -0.105), Vector3(0.03, 0.05, 0.03), skin.darkened(0.05))
	# eyes
	var eye := glow if d.extra == "golem" or d.name in ["Jace", "Sorin", "Nissa", "Karn", "Vraska"] else Color(0.12, 0.1, 0.1)
	for s in [-1, 1]:
		k.box(hc0 + Vector3(s * 0.04, 0.02, -0.112 if d.hair != "mane" else -0.12), Vector3(0.03, 0.018, 0.01), eye, eye != Color(0.12, 0.1, 0.1))
	match d.hair:
		"short":
			k.sphere(hc0 + Vector3(0, 0.05, 0.015), Vector3(0.108, 0.1, 0.115), hc, 8, 4)
		"long":
			k.sphere(hc0 + Vector3(0, 0.05, 0.02), Vector3(0.112, 0.105, 0.12), hc, 8, 4)
			k.taper(hc0 + Vector3(0, -0.28, 0.06), Vector2(0.2, 0.08), Vector2(0.22, 0.12), 0.32, hc)
		"hood":
			k.sphere(hc0 + Vector3(0, 0.04, 0.02), Vector3(0.14, 0.15, 0.15), d.main, 8, 5)
			k.box(hc0 + Vector3(0, 0.13, -0.08), Vector3(0.18, 0.04, 0.08), d.main.darkened(0.1))
			k.box(hc0 + Vector3(0, 0.08, -0.12), Vector3(0.025, 0.025, 0.01), glow, true)
		"bald":
			if d.name == "Teferi":
				k.box(hc0 + Vector3(0, -0.09, -0.07), Vector3(0.12, 0.06, 0.06), hc)
		"flame":
			k.sphere(hc0 + Vector3(0, 0.05, 0.02), Vector3(0.11, 0.1, 0.12), hc.darkened(0.2), 8, 4)
			for i in 6:
				var a := (i - 2.5) * 0.35
				k.cyl(hc0 + Vector3(sin(a) * 0.07, 0.1, 0.02 + cos(a) * 0.04), hc0 + Vector3(sin(a) * 0.12, 0.3 + (i % 2) * 0.05, 0.1), 0.05, 0.0, glow, 5, true)
		"mane":
			pass
		"tendrils":
			for i in 9:
				var a := TAU * i / 9.0
				var root := hc0 + Vector3(cos(a) * 0.09, 0.07, sin(a) * 0.09 + 0.02)
				k.cyl(root, root + Vector3(cos(a) * 0.12, -0.22 + 0.08 * sin(a * 3.0), sin(a) * 0.1 + 0.06), 0.03, 0.012, hc, 5)
		"spikes":
			for i in 7:
				var a := (i - 3) * 0.4
				k.cyl(hc0 + Vector3(sin(a) * 0.06, 0.08, 0.02), hc0 + Vector3(sin(a) * 0.12, 0.26, 0.08), 0.04, 0.0, hc, 4)
		"veil":
			k.sphere(hc0 + Vector3(0, 0.05, 0.02), Vector3(0.115, 0.11, 0.12), hc, 8, 4)
			k.taper(hc0 + Vector3(0, -0.3, 0.05), Vector2(0.22, 0.1), Vector2(0.24, 0.13), 0.34, hc)
			# a thin silver circlet with a veil over the face
			k.ring(hc0 + Vector3(0, 0.07, 0), Vector3.UP, 0.115, 0.01, d.trim, 10, 3)
			k.box(hc0 + Vector3(0, 0.0, -0.118), Vector3(0.17, 0.08, 0.005), Color(0.1, 0.06, 0.12))
	match d.extra:
		"goggles":
			k.ring(hc0 + Vector3(0, 0.1, 0), Vector3.UP, 0.112, 0.014, Color(0.3, 0.2, 0.12), 10, 3)
			for s in [-1, 1]:
				k.cyl(hc0 + Vector3(s * 0.045, 0.12, -0.11), hc0 + Vector3(s * 0.045, 0.12, -0.13), 0.028, 0.028, d.trim, 8)
		"ears":
			for s in [-1, 1]:
				k.cyl(hc0 + Vector3(s * 0.1, 0.02, 0), hc0 + Vector3(s * 0.2, 0.08, 0.03), 0.025, 0.0, d.skin, 4)
		"golem":
			# a heavy silver head with a ridge
			k.gloss = true
			k.box(hc0 + Vector3(0, 0.0, 0), Vector3(0.2, 0.24, 0.22), d.skin)
			k.box(hc0 + Vector3(0, 0.1, -0.02), Vector3(0.06, 0.06, 0.24), d.skin.lightened(0.1))
			k.gloss = false
			for s in [-1, 1]:
				k.box(hc0 + Vector3(s * 0.05, 0.02, -0.112), Vector3(0.05, 0.02, 0.01), d.glow, true)
	if d.name == "Gideon":
		k.ring(hc0 + Vector3(0, 0.0, 0), Vector3.UP, 0.13, 0.012, Color(1, 0.85, 0.45), 10, 3, true, PI)
	if d.name == "Vraska":
		k.ring(hc0 + Vector3(0, 0.09, 0), Vector3.UP, 0.11, 0.014, d.trim, 10, 3)
	return k.commit()


static func _arm(d: Dictionary, b: float, tc: Color, right: bool) -> ArrayMesh:
	var k := _kit()
	var sleeve: Color = d.main.darkened(0.08)
	var skin: Color = d.skin
	var hand: Color = skin if d.name != "Gideon" else d.second
	var golem: bool = d.extra == "golem"
	if golem:
		k.gloss = true
	# shoulder (origin) down to the hand at y = -0.62
	k.cyl(Vector3(0, 0.0, 0), Vector3(0, -0.3, 0), 0.07 * b, 0.06 * b, sleeve, 6)
	k.cyl(Vector3(0, -0.3, 0), Vector3(0, -0.54, 0), 0.06 * b, 0.05 * b, sleeve if d.name != "Ajani" else skin, 6)
	k.box(Vector3(0, -0.5, 0), Vector3(0.13 * b, 0.07, 0.13 * b), d.trim.darkened(0.2))
	k.sphere(Vector3(0, -0.6, 0), Vector3(0.055, 0.065, 0.055) * b, hand, 6, 3)
	k.gloss = false
	if right and d.extra == "coil":
		k.ring(Vector3(0, -0.35, 0), Vector3.UP, 0.08, 0.02, d.glow, 8, 3, true)
	if not right:
		k.box(Vector3(0, -0.22, 0), Vector3(0.15 * b, 0.05, 0.15 * b), tc)
	return k.commit()


static func _leg(d: Dictionary, b: float, tc: Color) -> ArrayMesh:
	var k := _kit()
	var pants: Color = d.second
	var boot: Color = d.second.darkened(0.45)
	if d.extra == "golem":
		k.gloss = true
		pants = d.main
		boot = d.main.darkened(0.2)
	# hip (origin) to the sole at y = -0.92
	k.cyl(Vector3(0, 0, 0), Vector3(0, -0.46, 0), 0.085 * b, 0.07 * b, pants, 6)
	k.cyl(Vector3(0, -0.46, 0), Vector3(0, -0.8, 0), 0.07 * b, 0.06 * b, boot, 6)
	k.box(Vector3(0, -0.87, -0.05), Vector3(0.12 * b, 0.1, 0.26), boot.darkened(0.1))
	k.gloss = false
	k.box(Vector3(0, -0.5, -0.06), Vector3(0.1, 0.06, 0.03), d.trim.darkened(0.2))
	return k.commit()


static func _cape(d: Dictionary, b: float, tc: Color) -> ArrayMesh:
	var k := _kit()
	var c: Color = d.second if d.name == "Jace" else (d.second if d.name == "Sorin" else d.main.darkened(0.25))
	# hangs from the shoulders (origin at the shoulder line), behind the back
	var rows := []
	for i in 5:
		var t := i / 4.0
		var row := PackedVector3Array()
		for j in 6:
			var u := j / 5.0 - 0.5
			row.append(Vector3(u * (0.45 + t * 0.25) * b, -t * 1.05, 0.15 + t * 0.12 + absf(u) * 0.05))
		rows.append(row)
	k.loft(rows, c, false, false, false)
	# the inside, facing the back
	var inner := []
	for r in rows:
		var row := PackedVector3Array()
		for j in range(r.size() - 1, -1, -1):
			row.append(r[j] + Vector3(0, 0, -0.01))
		inner.append(row)
	k.loft(inner, c.darkened(0.3), false, false, false)
	k.box(Vector3(0, -1.0, 0.28), Vector3(0.6 * b, 0.04, 0.03), tc)
	return k.commit()


# --- weapons ------------------------------------------------------------------------------

## A weapon, grip at the origin, muzzle towards -Z. `muzzle` (from weapon_muzzle) is where shots start.
static func weapon(w: String) -> ArrayMesh:
	var key := "wp:" + w
	if _cache.has(key):
		return _cache[key]
	var k := _kit()
	var c: Color = Data.WEAPONS[w].color
	var brass := Color(0.78, 0.6, 0.3)
	var dark := Color(0.16, 0.14, 0.16)
	var wood := Color(0.42, 0.26, 0.14)
	var silver := Color(0.75, 0.77, 0.82)
	match w:
		"blade":
			k.cyl(Vector3(0, -0.06, 0.04), Vector3(0, 0.02, -0.02), 0.025, 0.025, wood, 6)
			k.box(Vector3(0, 0.03, -0.04), Vector3(0.16, 0.03, 0.04), brass)
			k.box(Vector3(0, 0.05, -0.38), Vector3(0.045, 0.012, 0.66), c, true)
			k.cyl(Vector3(0, 0.05, -0.71), Vector3(0, 0.05, -0.8), 0.022, 0.0, c, 4, true)
		"repeater":
			k.box(Vector3(0, -0.05, 0.02), Vector3(0.06, 0.14, 0.07), wood)
			k.box(Vector3(0, 0.03, -0.1), Vector3(0.09, 0.08, 0.3), dark)
			k.cyl(Vector3(0, 0.04, -0.25), Vector3(0, 0.04, -0.5), 0.022, 0.018, brass, 8)
			for i in 3:
				k.ring(Vector3(0, 0.04, -0.3 - i * 0.07), Vector3.FORWARD, 0.032, 0.008, brass.lightened(0.2), 8, 3)
			k.sphere(Vector3(0, 0.1, -0.08), Vector3(0.035, 0.035, 0.05), c, 6, 4, true)
		"thunder":
			k.box(Vector3(0, -0.06, 0.06), Vector3(0.07, 0.16, 0.1), wood)
			k.box(Vector3(0, 0.03, -0.1), Vector3(0.14, 0.1, 0.34), dark)
			for s in [-1, 1]:
				k.cyl(Vector3(s * 0.035, 0.04, -0.2), Vector3(s * 0.035, 0.04, -0.58), 0.032, 0.036, silver, 8)
			k.box(Vector3(0, 0.1, -0.15), Vector3(0.05, 0.05, 0.18), c, true)
			k.box(Vector3(0, 0.03, -0.42), Vector3(0.16, 0.04, 0.05), brass)
		"pulse":
			k.box(Vector3(0, -0.05, 0.03), Vector3(0.06, 0.14, 0.08), dark)
			k.cyl(Vector3(0, 0.04, 0.05), Vector3(0, 0.04, -0.5), 0.05, 0.035, brass, 8)
			for i in 4:
				k.ring(Vector3(0, 0.04, -0.08 - i * 0.1), Vector3.FORWARD, 0.06 - i * 0.004, 0.012, c, 10, 3, true)
			k.sphere(Vector3(0, 0.04, -0.52), Vector3(0.03, 0.03, 0.03), c, 6, 4, true)
		"lash":
			k.box(Vector3(0, -0.06, 0.04), Vector3(0.06, 0.14, 0.08), dark)
			k.cyl(Vector3(0, 0.04, 0.08), Vector3(0, 0.04, -0.52), 0.03, 0.03, dark.lightened(0.2), 8)
			for i in 7:
				k.ring(Vector3(0, 0.04, -0.05 - i * 0.065), Vector3.FORWARD, 0.045, 0.012, Color(0.85, 0.5, 0.25), 8, 3)
			k.cyl(Vector3(0, 0.04, -0.52), Vector3(0, 0.04, -0.6), 0.03, 0.0, c, 6, true)
			k.box(Vector3(0, 0.1, -0.02), Vector3(0.03, 0.04, 0.12), c, true)
		"fireball":
			k.box(Vector3(0, -0.07, 0.08), Vector3(0.07, 0.16, 0.1), wood)
			k.cyl(Vector3(0, 0.05, 0.22), Vector3(0, 0.05, -0.55), 0.075, 0.085, Color(0.45, 0.12, 0.08), 10)
			k.ring(Vector3(0, 0.05, -0.55), Vector3.FORWARD, 0.085, 0.02, brass, 10, 3)
			k.ring(Vector3(0, 0.05, 0.0), Vector3.FORWARD, 0.08, 0.018, brass, 10, 3)
			k.cyl(Vector3(0, 0.05, -0.5), Vector3(0, 0.05, -0.56), 0.06, 0.06, c, 10, true)
			k.sphere(Vector3(0, 0.15, -0.15), Vector3(0.04, 0.05, 0.04), c, 6, 4, true)
		"disintegrate":
			k.box(Vector3(0, -0.06, 0.12), Vector3(0.06, 0.15, 0.24), wood)
			k.box(Vector3(0, 0.03, -0.12), Vector3(0.08, 0.09, 0.4), dark)
			k.cyl(Vector3(0, 0.03, -0.3), Vector3(0, 0.03, -0.85), 0.025, 0.02, silver, 8)
			k.cyl(Vector3(0, 0.11, 0.0), Vector3(0, 0.11, -0.25), 0.03, 0.03, dark.lightened(0.15), 8)
			k.cyl(Vector3(0, 0.11, -0.25), Vector3(0, 0.11, -0.26), 0.03, 0.03, c, 8, true)
			k.sphere(Vector3(0, 0.03, -0.18), Vector3(0.04, 0.04, 0.07), c, 6, 4, true)
			for i in 3:
				k.ring(Vector3(0, 0.03, -0.55 - i * 0.1), Vector3.FORWARD, 0.03, 0.008, c, 8, 3, true)
	var m := k.commit()
	_cache[key] = m
	return m


static func weapon_muzzle(w: String) -> Vector3:
	match w:
		"blade": return Vector3(0, 0.05, -0.7)
		"repeater": return Vector3(0, 0.04, -0.5)
		"thunder": return Vector3(0, 0.04, -0.58)
		"pulse": return Vector3(0, 0.04, -0.52)
		"lash": return Vector3(0, 0.04, -0.6)
		"fireball": return Vector3(0, 0.05, -0.56)
	return Vector3(0, 0.03, -0.85)


## A sleeve and hand for the first-person view, in the planeswalker's colours.
static func view_hand(id: String) -> ArrayMesh:
	var key := "hand:" + id
	if _cache.has(key):
		return _cache[key]
	var d: Dictionary = Data.WALKERS[id]
	var k := _kit()
	k.cyl(Vector3(0.02, -0.08, 0.5), Vector3(0, -0.03, 0.06), 0.06, 0.05, d.main, 7)
	k.box(Vector3(0, -0.035, 0.08), Vector3(0.11, 0.06, 0.06), d.trim.darkened(0.2))
	k.sphere(Vector3(0, -0.02, 0.0), Vector3(0.05, 0.045, 0.06), d.skin if d.name != "Gideon" else d.second, 6, 3)
	var m := k.commit()
	_cache[key] = m
	return m


# --- pickups and props ---------------------------------------------------------------------

static func item(kind: String) -> ArrayMesh:
	var key := "it:" + kind
	if _cache.has(key):
		return _cache[key]
	var k := _kit()
	var d: Dictionary = Data.ITEMS[kind]
	var c: Color = d.color
	match kind:
		"salve":
			k.cyl(Vector3(0, 0, 0), Vector3(0, 0.3, 0), 0.13, 0.13, Color(0.9, 0.88, 0.8), 8)
			k.cyl(Vector3(0, 0.05, 0), Vector3(0, 0.27, 0), 0.135, 0.135, c, 8, true)
			k.cyl(Vector3(0, 0.3, 0), Vector3(0, 0.36, 0), 0.08, 0.08, Color(0.5, 0.35, 0.2), 8)
		"elixir":
			k.sphere(Vector3(0, 0.3, 0), Vector3(0.28, 0.28, 0.28), c, 10, 6, true)
			k.cyl(Vector3(0, 0.55, 0), Vector3(0, 0.75, 0), 0.08, 0.06, Color(0.85, 0.85, 0.9), 8)
			k.ring(Vector3(0, 0.3, 0), Vector3.UP, 0.3, 0.03, Color(0.95, 0.85, 0.4), 16, 4)
		"shard":
			k.cyl(Vector3(0, 0.0, 0), Vector3(0, 0.18, 0), 0.0, 0.1, c, 4, true)
			k.cyl(Vector3(0, 0.18, 0), Vector3(0, 0.36, 0), 0.1, 0.0, c, 4, true)
		"plate", "aegis":
			var s := 1.0 if kind == "plate" else 1.3
			var pts := [Vector3(-0.3, 0.55, 0), Vector3(0.3, 0.55, 0), Vector3(0.28, 0.2, 0), Vector3(0, -0.05, 0), Vector3(-0.28, 0.2, 0)]
			var front := []
			for p in pts:
				front.append(p * s + Vector3(0, 0.15, 0))
			k.gloss = true
			for i in 3:
				k.tri(front[0] + Vector3(0, 0, -0.04), front[i + 1] + Vector3(0, 0, -0.04), front[i + 2 if i + 2 < 5 else 0] + Vector3(0, 0, -0.04), c)
				k.tri(front[0] + Vector3(0, 0, 0.04), front[i + 2 if i + 2 < 5 else 0] + Vector3(0, 0, 0.04), front[i + 1] + Vector3(0, 0, 0.04), c.darkened(0.2))
			for i in 5:
				var a: Vector3 = front[i]
				var bb: Vector3 = front[(i + 1) % 5]
				k.quad(a + Vector3(0, 0, -0.04), a + Vector3(0, 0, 0.04), bb + Vector3(0, 0, 0.04), bb + Vector3(0, 0, -0.04), c.darkened(0.3))
			k.gloss = false
			k.box(Vector3(0, 0.45 * s + 0.15, -0.05), Vector3(0.1, 0.1, 0.02), Color(1, 1, 0.9), true)
		"overload":
			k.sphere(Vector3(0, 0.45, 0), Vector3(0.3, 0.3, 0.3), c, 10, 6, true)
			for i in 3:
				k.ring(Vector3(0, 0.45, 0), Vector3(sin(i * 2.1), cos(i * 2.1), 0.3).normalized(), 0.42, 0.025, Color(1, 0.8, 1), 16, 3, true)
		"haste":
			k.sphere(Vector3(0, 0.45, 0), Vector3(0.28, 0.28, 0.28), c, 10, 6, true)
			for i in 4:
				var a := TAU * i / 4.0
				k.cyl(Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Vector3(cos(a + 0.6) * 0.5, 0.6, sin(a + 0.6) * 0.5), 0.04, 0.0, Color(1, 0.8, 0.4), 4, true)
	var m := k.commit()
	_cache[key] = m
	return m


## A team banner on a pole (team -1: neutral).
static func flag(team: int) -> ArrayMesh:
	var key := "flag:%d" % team
	if _cache.has(key):
		return _cache[key]
	var k := _kit()
	var c := Data.team_color(team)
	k.cyl(Vector3(0, 0, 0), Vector3(0, 2.2, 0), 0.04, 0.035, Color(0.8, 0.65, 0.35), 6)
	k.sphere(Vector3(0, 2.25, 0), Vector3(0.08, 0.08, 0.08), Color(1, 0.85, 0.4), 6, 4, true)
	var rows := []
	for i in 6:
		var t := i / 5.0
		var row := PackedVector3Array()
		for j in 2:
			row.append(Vector3(0.04 + t * 0.9, 2.1 - j * 0.75 - t * 0.08, sin(t * 4.0) * 0.08))
		rows.append(row)
	k.loft(rows, c, false, false, false)
	var back := []
	for r in rows:
		back.append(PackedVector3Array([r[1] + Vector3(0, 0, 0.01), r[0] + Vector3(0, 0, 0.01)]))
	k.loft(back, c.darkened(0.3), false, false, false)
	k.box(Vector3(0.45, 1.75, 0.0), Vector3(0.22, 0.22, 0.2), c.lightened(0.4), true)
	var m := k.commit()
	_cache[key] = m
	return m


## The stand a flag rests on at its base.
static func flag_base(team: int) -> ArrayMesh:
	var k := _kit()
	var c := Data.team_color(team)
	k.cyl(Vector3(0, 0, 0), Vector3(0, 0.15, 0), 1.3, 1.2, Color(0.25, 0.23, 0.26), 12)
	k.ring(Vector3(0, 0.16, 0), Vector3.UP, 1.05, 0.06, c, 16, 3, true)
	k.cyl(Vector3(0, 0.15, 0), Vector3(0, 0.3, 0), 0.5, 0.4, Color(0.4, 0.36, 0.3), 8)
	return k.commit()


static func jump_pad() -> ArrayMesh:
	if _cache.has("pad"):
		return _cache.pad
	var k := _kit()
	k.cyl(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 1.25, 1.15, Color(0.3, 0.28, 0.25), 12)
	k.cyl(Vector3(0, 0.12, 0), Vector3(0, 0.14, 0), 0.95, 0.95, Color(0.45, 0.95, 1.0), 12, true)
	k.ring(Vector3(0, 0.15, 0), Vector3.UP, 1.1, 0.05, Color(0.95, 0.75, 0.35), 16, 3)
	_cache.pad = k.commit()
	return _cache.pad


## A standing portal ring; the glowing disc is a separate mesh (portal_disc) so it can pulse.
static func portal() -> ArrayMesh:
	if _cache.has("portal"):
		return _cache.portal
	var k := _kit()
	k.ring(Vector3(0, 1.3, 0), Vector3.FORWARD, 1.2, 0.12, Color(0.75, 0.6, 0.35), 20, 5)
	k.box(Vector3(0, 0.05, 0), Vector3(2.8, 0.1, 0.8), Color(0.3, 0.27, 0.25))
	for s in [-1, 1]:
		k.sphere(Vector3(s * 1.2, 1.3, 0), Vector3(0.16, 0.16, 0.16), Color(0.8, 0.5, 1.0), 6, 4, true)
	_cache.portal = k.commit()
	return _cache.portal


static func portal_disc(col: Color) -> ArrayMesh:
	var k := _kit()
	for i in 20:
		var a0 := TAU * i / 20.0
		var a1 := TAU * (i + 1) / 20.0
		var c := Vector3(0, 1.3, 0)
		k.tri(c, c + Vector3(cos(a0), sin(a0), 0) * 1.1, c + Vector3(cos(a1), sin(a1), 0) * 1.1, col)
		k.tri(c, c + Vector3(cos(a1), sin(a1), 0) * 1.1, c + Vector3(cos(a0), sin(a0), 0) * 1.1, col)
	return k.commit(null, [Game.mat_fx, Game.mat_fx, Game.mat_fx])


## A projectile in flight.
static func projectile(w: String) -> ArrayMesh:
	var key := "pr:" + w
	if _cache.has(key):
		return _cache[key]
	var k := _kit()
	var c: Color = Data.WEAPONS[w].color
	if w == "fireball":
		k.sphere(Vector3.ZERO, Vector3(0.22, 0.22, 0.3), c, 8, 5, true)
		k.sphere(Vector3.ZERO, Vector3(0.12, 0.12, 0.14), Color(1, 0.95, 0.7), 6, 4, true)
	else:
		k.sphere(Vector3.ZERO, Vector3(0.12, 0.12, 0.12), c, 6, 4, true)
	var m := k.commit()
	_cache[key] = m
	return m
