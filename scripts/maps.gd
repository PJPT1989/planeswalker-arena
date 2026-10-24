class_name Maps
extends RefCounted
## The arenas. LIST has each map's name, plane, modes, size hint, sky and light; build_<id>(a)
## adds its geometry, pickups, pads, portals, spawns and flags to an Arena. Deathmatch maps are
## also played as Team Deathmatch; Capture the Flag maps are built as one half with
## `a.mirror` on (red half at -Z, blue gets the same turned half round).

const LIST := [
	{"id": "foundry", "name": "Ghirapur Foundry", "plane": "Kaladesh", "modes": ["ffa", "tdm"], "size": 8,
		"desc": "A brass inventors' foundry: a raised hub, four balconies and a ring of catwalks.",
		"theme": {"sky_top": Color(0.18, 0.4, 0.78), "sky_horizon": Color(0.95, 0.78, 0.55), "sky_ground": Color(0.35, 0.25, 0.18),
			"sun": Color(1.0, 0.9, 0.75), "sun_energy": 1.0, "sun_elev": 52.0, "sun_az": 35.0, "ambient": Color(0.5, 0.46, 0.44), "ambient_energy": 0.7,
			"fog": Color(0.75, 0.62, 0.5), "fog_density": 0.003},
		"views": [[Vector3(0, 22, 38), Vector3(0, 2, 0)], [Vector3(-28, 9, 28), Vector3(10, 3, -10)], [Vector3(26, 7.5, -26), Vector3(-5, 2, 10)]]},
	{"id": "plaza", "name": "Tenth District Plaza", "plane": "Ravnica", "modes": ["ffa", "tdm"], "size": 10,
		"desc": "A guild city square at dusk: a fountain, four rooftops, two bridges and narrow streets.",
		"theme": {"sky_top": Color(0.16, 0.12, 0.3), "sky_horizon": Color(0.85, 0.5, 0.45), "sky_ground": Color(0.15, 0.12, 0.15),
			"sun": Color(1.0, 0.7, 0.55), "sun_energy": 0.8, "sun_elev": 18.0, "sun_az": 120.0, "ambient": Color(0.42, 0.38, 0.5), "ambient_energy": 0.8,
			"fog": Color(0.45, 0.35, 0.45), "fog_density": 0.006, "stars": 0.3},
		"views": [[Vector3(0, 26, 44), Vector3(0, 2, 0)], [Vector3(-30, 10, 30), Vector3(10, 4, -10)], [Vector3(14, 9, -24), Vector3(-10, 3, 10)]]},
	{"id": "cathedral", "name": "Thraben Cathedral", "plane": "Innistrad", "modes": ["ffa", "tdm"], "size": 9,
		"desc": "A roofless cathedral under the moon: the nave, galleries, a choir loft and the crypt below.",
		"theme": {"sky_top": Color(0.03, 0.04, 0.1), "sky_horizon": Color(0.18, 0.2, 0.32), "sky_ground": Color(0.05, 0.05, 0.07),
			"sun": Color(0.6, 0.7, 1.0), "sun_energy": 0.45, "sun_elev": 50.0, "sun_az": -30.0, "ambient": Color(0.3, 0.32, 0.45), "ambient_energy": 0.9,
			"fog": Color(0.12, 0.13, 0.2), "fog_density": 0.012, "stars": 1.0, "sun_disc": 0.0, "moon": Color(0.95, 0.95, 0.85), "moon_dir": Vector3(0.2, 0.5, -1.0)},
		"views": [[Vector3(0, 12, 40), Vector3(0, 1, -20)], [Vector3(-11, 6.5, 30), Vector3(5, 1, -10)], [Vector3(0, -2.2, 41), Vector3(0, -3.5, 18)]]},
	{"id": "skyruins", "name": "Skyclash Ruins", "plane": "Zendikar", "modes": ["ffa", "tdm"], "size": 8,
		"desc": "Floating islands among the hedrons. Bridges, jump pads and a long fall.",
		"theme": {"sky_top": Color(0.2, 0.45, 0.85), "sky_horizon": Color(0.75, 0.85, 0.95), "sky_ground": Color(0.4, 0.5, 0.6),
			"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.1, "sun_elev": 40.0, "sun_az": 60.0, "ambient": Color(0.5, 0.55, 0.65), "ambient_energy": 0.8,
			"fog": Color(0.7, 0.8, 0.9), "fog_density": 0.006},
		"views": [[Vector3(0, 30, 50), Vector3(0, 0, 0)], [Vector3(-30, 12, 10), Vector3(10, 0, -10)], [Vector3(30, 4, 14), Vector3(0, 2, -10)]]},
	{"id": "furnace", "name": "Furnace Core", "plane": "New Phyrexia", "modes": ["ffa", "tdm"], "size": 8,
		"desc": "Oil and porcelain round a burning pit: one bridge across, a ring above and four towers.",
		"theme": {"sky_top": Color(0.08, 0.1, 0.06), "sky_horizon": Color(0.45, 0.4, 0.25), "sky_ground": Color(0.1, 0.08, 0.06),
			"sun": Color(0.9, 0.85, 0.65), "sun_energy": 0.6, "sun_elev": 60.0, "sun_az": 10.0, "ambient": Color(0.38, 0.36, 0.33), "ambient_energy": 0.8,
			"fog": Color(0.3, 0.28, 0.18), "fog_density": 0.01, "sun_disc": 0.3},
		"views": [[Vector3(0, 24, 40), Vector3(0, 0, 0)], [Vector3(-28, 7, 28), Vector3(5, 2, -5)], [Vector3(24, 12, -24), Vector3(-10, 0, 10)]]},
	{"id": "nyx", "name": "Nyx Spires", "plane": "Theros", "modes": ["ctf"], "size": 10,
		"desc": "Two marble towers on a strip of night sky. Snipe from the top, run the long field.",
		"theme": {"sky_top": Color(0.04, 0.03, 0.12), "sky_horizon": Color(0.3, 0.2, 0.5), "sky_ground": Color(0.02, 0.02, 0.06),
			"sun": Color(0.75, 0.75, 1.0), "sun_energy": 0.7, "sun_elev": 45.0, "sun_az": 70.0, "ambient": Color(0.38, 0.36, 0.55), "ambient_energy": 0.9,
			"fog": Color(0.15, 0.1, 0.3), "fog_density": 0.004, "stars": 1.4, "sun_disc": 0.0, "aurora": Vector4(0.6, 0.4, 1.0, 0.8)},
		"views": [[Vector3(30, 24, 0), Vector3(0, 0, -20)], [Vector3(0, 14, -30), Vector3(0, 5, -55)], [Vector3(-10, 4, 10), Vector3(0, 6, -50)]]},
	{"id": "keeps", "name": "Benalish Keeps", "plane": "Dominaria", "modes": ["ctf"], "size": 10,
		"desc": "Two castles across a river valley. Gates, side doors, wall walks and a ruined watchtower.",
		"theme": {"sky_top": Color(0.22, 0.45, 0.85), "sky_horizon": Color(0.8, 0.85, 0.9), "sky_ground": Color(0.35, 0.4, 0.3),
			"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.1, "sun_elev": 45.0, "sun_az": -40.0, "ambient": Color(0.5, 0.55, 0.6), "ambient_energy": 0.75,
			"fog": Color(0.75, 0.82, 0.9), "fog_density": 0.004},
		"views": [[Vector3(28, 20, 10), Vector3(0, 0, -30)], [Vector3(0, 9, -24), Vector3(0, 3, -55)], [Vector3(-26, 6, 6), Vector3(10, 0, -20)]]},
	{"id": "temples", "name": "Orazca Temples", "plane": "Ixalan", "modes": ["ctf"], "size": 10,
		"desc": "Step pyramids in the jungle; the flags sit in the shrines on top. A sunken plaza between.",
		"theme": {"sky_top": Color(0.25, 0.45, 0.7), "sky_horizon": Color(1.0, 0.75, 0.5), "sky_ground": Color(0.3, 0.35, 0.2),
			"sun": Color(1.0, 0.85, 0.6), "sun_energy": 1.1, "sun_elev": 30.0, "sun_az": 100.0, "ambient": Color(0.5, 0.52, 0.42), "ambient_energy": 0.75,
			"fog": Color(0.7, 0.65, 0.5), "fog_density": 0.006},
		"views": [[Vector3(30, 18, 10), Vector3(0, 0, -25)], [Vector3(0, 10, -24), Vector3(0, 9, -46)], [Vector3(-12, 2, 6), Vector3(5, -2, -10)]]},
	{"id": "neon", "name": "Neon Spires", "plane": "Kamigawa", "modes": ["ctf"], "size": 10,
		"desc": "Two neon towers in a night street, sky walks along both sides and portals to the middle.",
		"theme": {"sky_top": Color(0.04, 0.03, 0.1), "sky_horizon": Color(0.45, 0.15, 0.4), "sky_ground": Color(0.05, 0.03, 0.06),
			"sun": Color(0.7, 0.75, 1.0), "sun_energy": 0.5, "sun_elev": 55.0, "sun_az": 30.0, "ambient": Color(0.4, 0.38, 0.55), "ambient_energy": 0.95,
			"fog": Color(0.25, 0.08, 0.25), "fog_density": 0.01, "stars": 0.4, "sun_disc": 0.0},
		"views": [[Vector3(0, 16, 20), Vector3(0, 3, -30)], [Vector3(16, 8, -10), Vector3(0, 3, -50)], [Vector3(-10, 3, -36), Vector3(5, 5, 0)]]},
	{"id": "necropolis", "name": "Necropolis Trench", "plane": "Amonkhet", "modes": ["ctf"], "size": 10,
		"desc": "Two tombs in the desert, a trench between them and obelisks to hide behind.",
		"theme": {"sky_top": Color(0.3, 0.45, 0.75), "sky_horizon": Color(1.0, 0.8, 0.5), "sky_ground": Color(0.5, 0.4, 0.28),
			"sun": Color(1.0, 0.88, 0.65), "sun_energy": 1.25, "sun_elev": 58.0, "sun_az": 160.0, "ambient": Color(0.55, 0.5, 0.42), "ambient_energy": 0.7,
			"fog": Color(0.95, 0.8, 0.6), "fog_density": 0.005},
		"views": [[Vector3(26, 18, 12), Vector3(0, 0, -25)], [Vector3(0, 10, -30), Vector3(0, 4, -55)], [Vector3(0, -1.5, 12), Vector3(0, -2, -20)]]},
]


static func by_id(id: String) -> Dictionary:
	for m in LIST:
		if m.id == id:
			return m
	return LIST[0]


static func for_mode(mode: String) -> Array:
	var out := []
	for m in LIST:
		if mode in m.modes:
			out.append(m)
	return out


# --- helpers -------------------------------------------------------------------------------

## A rectangle of walls x0..x1, z0..z1 from y0 up h, with doorways: [side, centre, width,
## height], side "n" (z0), "s" (z1), "w" (x0), "e" (x1); the centre is along that side.
static func walls_rect(a: Arena, x0: float, z0: float, x1: float, z1: float, y0: float, h: float, col: Color,
		pat := Arena.P_BRICK, th := 0.8, doors := [], sc := 1.0) -> void:
	for side in ["n", "s", "w", "e"]:
		var along_x: bool = side == "n" or side == "s"
		var lo := x0 if along_x else z0
		var hi := x1 if along_x else z1
		var fixed: float = (z0 if side == "n" else z1) if along_x else (x0 if side == "w" else x1)
		var cuts := []
		for d in doors:
			if d[0] == side:
				cuts.append(d)
		cuts.sort_custom(func(p, q): return p[1] < q[1])
		var at := lo
		for d in cuts:
			var d0: float = d[1] - d[2] * 0.5
			var d1: float = d[1] + d[2] * 0.5
			if d0 > at:
				_wall_seg(a, along_x, fixed, at, d0, y0, h, col, pat, th, sc)
			var dh: float = d[3] if d.size() > 3 else 3.4
			var db: float = d[4] if d.size() > 4 else 0.0
			if db > 0.0:
				_wall_seg(a, along_x, fixed, d0, d1, y0, db, col, pat, th, sc)
			if db + dh < h:
				_wall_seg(a, along_x, fixed, d0, d1, y0 + db + dh, h - db - dh, col, pat, th, sc)
			at = d1
		if at < hi:
			_wall_seg(a, along_x, fixed, at, hi, y0, h, col, pat, th, sc)


static func _wall_seg(a: Arena, along_x: bool, fixed: float, s0: float, s1: float, y0: float, h: float, col: Color, pat: int, th: float, sc: float) -> void:
	if along_x:
		a.solid(Vector3((s0 + s1) * 0.5, y0 + h * 0.5, fixed), Vector3(s1 - s0 + th, h, th), col, pat, sc)
	else:
		a.solid(Vector3(fixed, y0 + h * 0.5, (s0 + s1) * 0.5), Vector3(th, h, s1 - s0 + th), col, pat, sc)


## Low battlement teeth along a line (decoration with collision), on top of a wall at height y.
static func crenels(a: Arena, from: Vector3, to: Vector3, col: Color, pat := Arena.P_BRICK, every := 2.0, size := Vector3(0.9, 0.9, 0.6)) -> void:
	var n := maxi(1, int(from.distance_to(to) / every))
	var yaw := atan2(to.x - from.x, to.z - from.z)
	for i in n + 1:
		var p := from.lerp(to, float(i) / n)
		a.solid(p + Vector3(0, size.y * 0.5, 0), Vector3(size.z, size.y, size.x), col, pat, 1.0, yaw)


## Rotates a point a quarter turn k times about the centre.
static func q(p: Vector3, k: int) -> Vector3:
	return Basis(Vector3.UP, k * PI * 0.5) * p


# --- Ghirapur Foundry (Kaladesh) ------------------------------------------------------------

static func build_foundry(a: Arena) -> void:
	var floor_c := Color(0.62, 0.5, 0.38)
	var brass := Color(0.82, 0.62, 0.32)
	var copper := Color(0.72, 0.4, 0.25)
	var wall_c := Color(0.75, 0.62, 0.5)
	var dark := Color(0.32, 0.26, 0.22)
	var aether := Color(0.4, 0.9, 1.0)
	var S := 32.0
	a.kill_y = -20.0
	a.floor_rect(-S, -S, S, S, 0.0, floor_c, Arena.P_TILE, 1.0, 1.5)
	# outer walls with a brass band and aether pipes
	a.wall(-S, -S, S, -S, 0.0, 14.0, wall_c, Arena.P_BRICK)
	a.wall(-S, S, S, S, 0.0, 14.0, wall_c, Arena.P_BRICK)
	a.wall(-S, -S, -S, S, 0.0, 14.0, wall_c, Arena.P_BRICK)
	a.wall(S, -S, S, S, 0.0, 14.0, wall_c, Arena.P_BRICK)
	for k in 4:
		var y := float(k)
		a.custom(q(Vector3(0, 0, -S + 0.45), k), k * PI * 0.5, func(m: MeshKit):
			m.box(Vector3(0, 10.5, 0), Vector3(2.0 * S, 0.5, 0.2), brass)
			m.box(Vector3(0, 1.0, 0), Vector3(2.0 * S, 0.3, 0.15), brass)
			for i in 6:
				var x := -25.0 + i * 10.0
				m.ring(Vector3(x, 10.0, 0.05), Vector3.FORWARD, 2.2, 0.25, brass, 16, 4)
				m.cyl(Vector3(x, 10.0, 0.0), Vector3(x, 10.0, 0.3), 0.6, 0.6, copper, 8)
			m.cyl(Vector3(-S, 2.2, 0.35), Vector3(S, 2.2, 0.35), 0.18, 0.18, aether, 8, true))
	# the hub: a raised platform with two ramps and an aether ring
	a.solid(Vector3(0, 1.5, 0), Vector3(14, 3, 14), dark, Arena.P_BRASS, 1.0)
	a.floor_rect(-7, -7, 7, 7, 3.05, brass, Arena.P_BRASS, 0.1)
	a.ramp(Vector3(0, 0, -17), Vector3(0, 3, -7), 4.0, brass, Arena.P_METAL)
	a.ramp(Vector3(0, 0, 17), Vector3(0, 3, 7), 4.0, brass, Arena.P_METAL)
	a.custom(Vector3(0, 3.1, 0), 0.0, func(m: MeshKit):
		m.ring(Vector3.ZERO, Vector3.UP, 4.5, 0.12, aether, 24, 3, true)
		m.cyl(Vector3(0, -0.05, 0), Vector3(0, 0.05, 0), 1.6, 1.6, copper, 12))
	# balconies in the corners, a catwalk ring along the walls and stairs up
	for k in 4:
		var c := q(Vector3(25, 0, -25), k)
		a.solid(c + Vector3(0, 5.6, 0), Vector3(14, 0.8, 14), brass, Arena.P_METAL)
		a.column(q(Vector3(19, 0, -19), k), 0.6, 5.2, copper, Arena.P_BRASS, 10, dark)
		a.stairs(q(Vector3(24, 0, -3), k), q(Vector3(24, 6, -18), k), 3.2, wall_c, Arena.P_MARBLE)
		# catwalk between this corner and the next (along the wall)
		a.solid(q(Vector3(0, 5.6, -29.5), k), Vector3(36, 0.8, 5) if k % 2 == 0 else Vector3(5, 0.8, 36), brass, Arena.P_METAL, 1.0, 0.0)
		for i in 3:
			a.column(q(Vector3(-10 + i * 10, 0, -27.4), k), 0.35, 5.2, copper, Arena.P_BRASS, 8)
		a.torch(q(Vector3(30, 6, -30), k), aether, k % 2 == 0)
		# railing along the catwalk edge
		a.custom(q(Vector3(0, 6.0, -26.9), k), k * PI * 0.5, func(m: MeshKit):
			m.box(Vector3(0, 0.9, 0), Vector3(36, 0.12, 0.12), brass)
			for i in 10:
				m.box(Vector3(-16.2 + i * 3.6, 0.45, 0), Vector3(0.1, 0.9, 0.1), brass))
	# bridges from the hub up to the east and west catwalks
	a.ramp(Vector3(7, 3, 0), Vector3(27, 6, 0), 3.0, brass, Arena.P_METAL, 0.5)
	a.ramp(Vector3(-7, 3, 0), Vector3(-27, 6, 0), 3.0, brass, Arena.P_METAL, 0.5)
	# cover on the floor: crates and boilers
	for p in [Vector3(14, 0, -10), Vector3(-14, 0, 10), Vector3(-12, 0, -16), Vector3(12, 0, 16)]:
		a.solid(p + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 2.4), copper, Arena.P_WOOD, 1.0, 0.3)
	for p in [Vector3(-18, 0, -6), Vector3(18, 0, 6)]:
		a.column(p, 1.4, 3.0, copper, Arena.P_BRASS, 12, dark)
	# jump pads from the floor to the north and south catwalks
	a.pad(Vector3(0, 0, -22), Vector3(0, 6, -29.5), 2.5)
	a.pad(Vector3(0, 0, 22), Vector3(0, 6, 29.5), 2.5)
	a.light(Vector3(0, 7, 0), Color(1.0, 0.7, 0.4), 2.0, 18.0)
	a.light(Vector3(-16, 4, 16), aether, 1.4, 16.0)
	a.light(Vector3(16, 4, -16), aether, 1.4, 16.0)
	# pickups
	a.weapon("fireball", Vector3(0, 3.15, 0))
	a.weapon("disintegrate", Vector3(25, 6, -25))
	a.weapon("thunder", Vector3(-25, 6, 25))
	a.weapon("lash", Vector3(-25, 6, -25))
	a.weapon("pulse", Vector3(25, 6, 25))
	a.weapon("thunder", Vector3(-24, 0, -8))
	a.weapon("pulse", Vector3(24, 0, 8))
	a.item("elixir", Vector3(-20, 0, 0))
	a.item("aegis", Vector3(20, 0, 0))
	a.item("overload", Vector3(0, 6, -29.5))
	a.item("haste", Vector3(0, 6, 29.5))
	for k in 4:
		a.item("salve", q(Vector3(25, 0, -25), k))
		a.item("salve", q(Vector3(27, 0, -23), k))
		a.item("shard", q(Vector3(0, 6, -27.5), k) + q(Vector3(6, 0, 0), k))
		a.item("shard", q(Vector3(0, 6, -27.5), k) + q(Vector3(-6, 0, 0), k))
	a.item("plate", Vector3(0, 0, -12))
	a.item("plate", Vector3(0, 0, 12))
	for k in 4:
		a.spawn(q(Vector3(22, 0, -12), k), k * PI * 0.5 + PI * 0.5)
		a.spawn(q(Vector3(10, 0, -24), k), k * PI * 0.5)
		a.spawn(q(Vector3(28, 6, -28), k), k * PI * 0.5 + PI * 0.75)


# --- Tenth District Plaza (Ravnica) ---------------------------------------------------------

static func build_plaza(a: Arena) -> void:
	var cobble := Color(0.42, 0.4, 0.42)
	var stone := Color(0.55, 0.5, 0.52)
	var dark := Color(0.28, 0.25, 0.3)
	var roof := Color(0.36, 0.3, 0.34)
	var lamp := Color(1.0, 0.75, 0.4)
	var guilds := [Color(0.85, 0.15, 0.15), Color(0.2, 0.45, 0.9), Color(0.15, 0.6, 0.3), Color(0.85, 0.7, 0.25), Color(0.5, 0.2, 0.6)]
	var S := 38.0
	a.kill_y = -20.0
	a.floor_rect(-S, -S, S, S, 0.0, cobble, Arena.P_TILE, 1.0, 0.45)
	# tall facades all round, with glowing windows
	for k in 4:
		a.solid(q(Vector3(0, 9, -S - 1.0), k), Vector3(2.0 * S + 4, 18, 2) if k % 2 == 0 else Vector3(2, 18, 2.0 * S + 4), dark, Arena.P_BRICK)
		a.custom(q(Vector3(0, 0, -S + 0.02), k), k * PI * 0.5, func(m: MeshKit):
			for i in 9:
				var x := -32.0 + i * 8.0
				for row in 2:
					m.box(Vector3(x, 4.0 + row * 5.0, 0.0), Vector3(1.6, 2.4, 0.08), lamp.darkened(0.15 + 0.2 * ((i + row) % 2)), true)
					m.box(Vector3(x, 2.6 + row * 5.0, 0.05), Vector3(2.2, 0.25, 0.3), stone)
				m.box(Vector3(x + 4.0, 7.5, 0.1), Vector3(1.4, 6.0, 0.06), guilds[(i + k) % 5])
			m.box(Vector3(0, 0.5, 0.2), Vector3(2.0 * S, 1.0, 0.4), stone))
	# the fountain: a low basin and a statue of a guild founder
	a.column(Vector3(0, 0, 0), 5.0, 0.45, stone, Arena.P_MARBLE, 16)
	a.column(Vector3(0, 0, 0), 1.2, 5.5, Color(0.6, 0.62, 0.66), Arena.P_MARBLE, 10, stone)
	a.custom(Vector3(0, 0.46, 0), 0.0, func(m: MeshKit):
		m.cyl(Vector3(0, 0, 0), Vector3(0, 0.02, 0), 4.3, 4.3, Color(0.3, 0.6, 0.85), 16, true)
		m.sphere(Vector3(0, 6.4, 0), Vector3(0.9, 0.9, 0.9), Color(0.6, 0.62, 0.66), 10, 6)
		m.ring(Vector3(0, 6.4, 0), Vector3.UP, 1.4, 0.12, Color(1.0, 0.8, 0.4), 16, 3, true))
	a.light(Vector3(0, 4, 0), Color(0.5, 0.7, 1.0), 1.5, 12.0)
	# four city blocks with walkable roofs (two are mirrored copies)
	a.mirror = true
	for c in [Vector3(18, 0, -18), Vector3(-18, 0, -18)]:
		a.solid(c + Vector3(0, 3.5, 0), Vector3(14, 7, 14), stone, Arena.P_BRICK)
		a.floor_rect(c.x - 7, c.z - 7, c.x + 7, c.z + 7, 7.02, roof, Arena.P_TILE, 0.1, 0.7)
		a.custom(c, 0.0, func(m: MeshKit):
			for side in 4:
				var b := Basis(Vector3.UP, side * PI * 0.5)
				for i in 3:
					m.box(b * Vector3(-4.0 + i * 4.0, 3.5, 7.02), Vector3(1.4, 2.2, 0.06), lamp.darkened(0.25 + 0.15 * (i % 2)), true)
				m.box(b * Vector3(0, 6.6, 7.1), Vector3(14.4, 0.4, 0.3), dark)
			m.box(Vector3(0, 7.6, 0), Vector3(2.0, 1.2, 2.0), dark))
	# the north bridge (mirror: south) and the stairs in the east street (mirror: west)
	a.solid(Vector3(0, 6.6, -18), Vector3(22.4, 0.8, 3.2), stone, Arena.P_MARBLE)
	a.custom(Vector3(0, 7.0, -18), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			m.box(Vector3(0, 0.55, s * 1.5), Vector3(22, 0.1, 0.1), dark)
			for i in 8:
				m.box(Vector3(-10.5 + i * 3.0, 0.27, s * 1.5), Vector3(0.12, 0.55, 0.12), dark)
		m.box(Vector3(0, -1.0, 0), Vector3(1.0, 1.4, 3.0), stone))
	a.stairs(Vector3(18, 0, 2.5), Vector3(18, 7, -11), 3.4, stone, Arena.P_MARBLE)
	a.pad(Vector3(0, 0, -8.5), Vector3(0, 7, -18), 2.5)
	# lamp posts and market stalls in the streets
	for p in [Vector3(30, 0, -30), Vector3(30, 0, 8), Vector3(-8, 0, -30)]:
		a.torch(p, lamp, p.x > 20.0 and p.z < 0.0)
	for p in [Vector3(30, 0, -12), Vector3(-30, 0, -22)]:
		a.solid(p + Vector3(0, 0.6, 0), Vector3(3.0, 1.2, 1.6), Color(0.45, 0.32, 0.2), Arena.P_WOOD)
		a.custom(p, 0.0, func(m: MeshKit):
			for s in [-1, 1]:
				for t in [-1, 1]:
					m.cyl(Vector3(s * 1.4, 1.2, t * 0.7), Vector3(s * 1.4, 2.6, t * 0.7), 0.06, 0.06, Color(0.4, 0.3, 0.2), 4)
			m.box(Vector3(0, 2.7, 0), Vector3(3.4, 0.08, 2.0), guilds[int(absf(p.z)) % 5]))
	a.mirror = false
	a.light(Vector3(25, 3, -25), lamp, 1.6, 14.0)
	a.light(Vector3(-25, 3, 25), lamp, 1.6, 14.0)
	a.weapon("fireball", Vector3(0, 0.45, 3.5))
	a.weapon("disintegrate", Vector3(-18, 7, -18))
	a.weapon("lash", Vector3(18, 7, 18))
	a.weapon("thunder", Vector3(18, 7, -18))
	a.weapon("pulse", Vector3(-18, 7, 18))
	a.weapon("thunder", Vector3(0, 0, -31))
	a.weapon("pulse", Vector3(0, 0, 31))
	a.weapon("lash", Vector3(-31, 0, 0))
	a.item("elixir", Vector3(33, 0, 0))
	a.item("aegis", Vector3(-33, 0, 30))
	a.item("overload", Vector3(0, 7, -18))
	a.item("haste", Vector3(0, 7, 18))
	for k in 4:
		a.item("salve", q(Vector3(31, 0, -31), k))
		a.item("salve", q(Vector3(10, 0, -31), k))
		a.item("shard", q(Vector3(-7, 7, -18), k) if k % 2 == 0 else q(Vector3(7, 7, -18), k + 1))
	a.item("plate", Vector3(31, 0, 31))
	a.item("plate", Vector3(-31, 0, -31))
	for k in 4:
		a.spawn(q(Vector3(28, 0, -4), k), k * PI * 0.5 - PI * 0.5)
		a.spawn(q(Vector3(6, 0, -28), k), k * PI * 0.5)
		a.spawn(q(Vector3(14, 7, -22), k), k * PI * 0.5 + PI)


# --- Thraben Cathedral (Innistrad) ---------------------------------------------------------

static func build_cathedral(a: Arena) -> void:
	var floor_c := Color(0.42, 0.42, 0.46)
	var wall_c := Color(0.5, 0.48, 0.5)
	var dark := Color(0.24, 0.22, 0.26)
	var wood := Color(0.36, 0.24, 0.16)
	var candle := Color(1.0, 0.7, 0.35)
	var glass := [Color(0.25, 0.4, 0.95), Color(0.85, 0.2, 0.25), Color(0.9, 0.75, 0.3), Color(0.3, 0.75, 0.5)]
	a.kill_y = -20.0
	# the nave floor, with two stairwells down to the crypt
	a.floor_rect(-14, -44, -8, 44, 0.0, floor_c, Arena.P_TILE)
	a.floor_rect(8, -44, 14, 44, 0.0, floor_c, Arena.P_TILE)
	a.floor_rect(-4, -44, 4, 44, 0.0, floor_c, Arena.P_MARBLE)
	for x in [-8.0, 4.0]:
		a.floor_rect(x, -44, x + 4, 16, 0.0, floor_c, Arena.P_TILE)
		a.floor_rect(x, 28, x + 4, 44, 0.0, floor_c, Arena.P_TILE)
	walls_rect(a, -14, -44, 14, 44, 0.0, 16.0, wall_c, Arena.P_BRICK, 1.2)
	# the crypt below
	a.floor_rect(-8.4, 13.6, 8.4, 42.4, -4.0, dark, Arena.P_TILE, 1.0)
	a.solid(Vector3(-8.6, -2.5, 28), Vector3(0.8, 3.0, 29), dark, Arena.P_BRICK)
	a.solid(Vector3(8.6, -2.5, 28), Vector3(0.8, 3.0, 29), dark, Arena.P_BRICK)
	a.solid(Vector3(0, -2.5, 13.4), Vector3(18, 3.0, 0.8), dark, Arena.P_BRICK)
	a.solid(Vector3(0, -2.5, 42.6), Vector3(18, 3.0, 0.8), dark, Arena.P_BRICK)
	a.stairs(Vector3(-6, -4, 27.8), Vector3(-6, 0, 16.2), 3.6, floor_c, Arena.P_MARBLE)
	a.stairs(Vector3(6, -4, 27.8), Vector3(6, 0, 16.2), 3.6, floor_c, Arena.P_MARBLE)
	for z in [20.0, 34.0]:
		for x in [-2.5, 2.5]:
			a.solid(Vector3(x, -3.5, z + (2.0 if x > 0 else 0.0)), Vector3(1.4, 1.0, 2.6), Color(0.45, 0.43, 0.42), Arena.P_MARBLE)
	a.torch(Vector3(0, -4, 31), candle)
	a.torch(Vector3(-6.5, -4, 39), candle, false)
	a.torch(Vector3(6.5, -4, 39), candle, false)
	# colonnades and the galleries above the aisles
	for x in [-8.0, 8.0]:
		for i in 13:
			var z := -36.0 + i * 6.0
			a.column(Vector3(x, 0, z), 0.55, 4.2, wall_c, Arena.P_MARBLE, 10, dark)
		a.solid(Vector3(x * 1.375, 4.6, -4), Vector3(6, 0.8, 80), floor_c, Arena.P_TILE)
		a.custom(Vector3(x, 5.0, -4), 0.0, func(m: MeshKit):
			m.box(Vector3(0, 0.95, 0), Vector3(0.12, 0.1, 80), dark)
			for i in 20:
				m.box(Vector3(0, 0.47, -39.0 + i * 4.1), Vector3(0.1, 0.95, 0.1), dark)
			for i in 12:
				m.cyl(Vector3(0, 0.0, -33.0 + i * 6.0), Vector3(0, 9.0, -33.0 + i * 6.0), 0.3, 0.25, wall_c, 6))
	a.stairs(Vector3(-11, 0, 43.2), Vector3(-11, 5, 36.2), 4.0, floor_c, Arena.P_MARBLE)
	a.stairs(Vector3(11, 0, 43.2), Vector3(11, 5, 36.2), 4.0, floor_c, Arena.P_MARBLE)
	# the altar, the choir loft above it and a pad up to the loft
	a.stairs(Vector3(0, 0, -30), Vector3(0, 1.5, -34), 16.0, floor_c, Arena.P_MARBLE)
	a.floor_rect(-8, -44, 8, -34, 1.5, floor_c, Arena.P_MARBLE, 1.5)
	a.solid(Vector3(0, 2.05, -41), Vector3(3.4, 1.1, 1.4), Color(0.75, 0.72, 0.66), Arena.P_MARBLE)
	a.floor_rect(-8, -44, 8, -40, 5.0, wood, Arena.P_WOOD, 0.8)
	a.pad(Vector3(0, 0, -24), Vector3(0, 5, -42), 2.5)
	# pews
	for i in 7:
		var z := -26.0 + i * 3.4
		for x in [-4.3, 4.3]:
			a.solid(Vector3(x, 0.45, z), Vector3(4.6, 0.9, 0.7), wood, Arena.P_WOOD)
	# stained glass and the rose window
	a.custom(Vector3.ZERO, 0.0, func(m: MeshKit):
		for side in [-1, 1]:
			for i in 7:
				var z := -36.0 + i * 12.0
				m.box(Vector3(side * 13.38, 10.5, z), Vector3(0.05, 5.5, 2.4), glass[(i + (1 if side > 0 else 0)) % 4], true)
				m.box(Vector3(side * 13.36, 10.5, z), Vector3(0.06, 5.7, 0.12), dark)
				m.cyl(Vector3(side * 13.38, 13.25, z - 1.2), Vector3(side * 13.38, 13.25, z + 1.2), 0.05, 0.05, dark, 4)
		m.ring(Vector3(0, 11.0, -43.38), Vector3.FORWARD, 3.0, 0.25, dark, 20, 4)
		for i in 8:
			var ang := TAU * i / 8.0
			m.box(Vector3(cos(ang) * 1.6, 11.0 + sin(ang) * 1.6, -43.36), Vector3(1.2, 1.2, 0.05), glass[i % 4], true)
		m.box(Vector3(0, 11.0, -43.37), Vector3(1.6, 1.6, 0.05), Color(1, 0.95, 0.8), true)
		# roof beams against the night sky
		for i in 12:
			var z := -40.0 + i * 7.3
			m.box(Vector3(0, 15.6, z), Vector3(28, 0.6, 0.6), wood.darkened(0.3)))
	for p in [Vector3(-3, 1.5, -42), Vector3(3, 1.5, -42), Vector3(-11, 0, -10), Vector3(11, 0, 10), Vector3(-11, 5, -24), Vector3(11, 5, 24)]:
		a.torch(p, candle, p.y < 1.0 or p.x < 0.0)
	a.light(Vector3(0, 6, 0), Color(0.55, 0.6, 1.0), 1.2, 22.0)
	a.weapon("fireball", Vector3(0, 1.5, -37))
	a.weapon("disintegrate", Vector3(0, 5, -42.3))
	a.weapon("lash", Vector3(-11, 5, -8))
	a.weapon("thunder", Vector3(11, 5, 8))
	a.weapon("pulse", Vector3(0, 0, 32))
	a.weapon("thunder", Vector3(-11, 0, 24))
	a.weapon("pulse", Vector3(11, 0, -28))
	a.item("elixir", Vector3(0, -4, 27))
	a.item("overload", Vector3(0, -4, 39.5))
	a.item("aegis", Vector3(-11, 5, -40))
	a.item("plate", Vector3(11, 5, -40))
	for p in [Vector3(-11, 0, -36), Vector3(11, 0, 36), Vector3(-11, 0, 0), Vector3(11, 0, -4), Vector3(0, 0, -16), Vector3(0, 0, 12)]:
		a.item("salve", p)
	for p in [Vector3(-11, 5, 20), Vector3(11, 5, -20), Vector3(-5, 5, -42), Vector3(5, 5, -42), Vector3(-6, -4, 36), Vector3(6, -4, 36)]:
		a.item("shard", p)
	for p in [[Vector3(-11, 0, -30), 0.0], [Vector3(11, 0, -16), 0.0], [Vector3(0, 0, 40), 0.0], [Vector3(-11, 0, 30), PI],
			[Vector3(11, 0, 26), PI], [Vector3(0, 0, -20), PI], [Vector3(-11, 5, 0), PI], [Vector3(11, 5, -6), 0.0],
			[Vector3(0, -4, 20), PI], [Vector3(0, 1.5, -36), PI], [Vector3(-11, 5, 30), 0.0], [Vector3(11, 5, 30), 0.0]]:
		a.spawn(p[0], p[1])


# --- Skyclash Ruins (Zendikar) --------------------------------------------------------------

static func build_skyruins(a: Arena) -> void:
	var grass := Color(0.36, 0.52, 0.28)
	var rock := Color(0.5, 0.42, 0.34)
	var ruin := Color(0.72, 0.68, 0.6)
	var hed := Color(0.62, 0.56, 0.46)
	var glow := Color(1.0, 0.75, 0.35)
	a.kill_y = -26.0
	# the central island
	a.solid(Vector3(0, -2, 0), Vector3(26, 4, 26), grass, Arena.P_ROCK, 1.2)
	a.custom(Vector3(0, -4, 0), 0.0, func(m: MeshKit):
		m.rock(Vector3(0, -5, 0), Vector3(14, 8, 14), rock, 3)
		m.rock(Vector3(5, -9, 4), Vector3(6, 7, 6), rock.darkened(0.1), 4))
	a.mirror = true
	# ruined walls and arches on the hub
	a.solid(Vector3(-8, 1.0, -8.5), Vector3(6, 2.0, 0.8), ruin, Arena.P_BRICK)
	a.solid(Vector3(8.5, 1.4, -4), Vector3(0.8, 2.8, 5), ruin, Arena.P_BRICK)
	a.column(Vector3(-10, 0, -2), 0.6, 4.0, ruin, Arena.P_MARBLE, 8)
	a.column(Vector3(-4, 0, -10.5), 0.6, 5.0, ruin, Arena.P_MARBLE, 8)
	# north island (mirror: south), high
	a.solid(Vector3(0, 2, -34), Vector3(16, 4, 14), grass, Arena.P_ROCK, 1.2)
	a.custom(Vector3(0, 0, -34), 0.0, func(m: MeshKit):
		m.rock(Vector3(0, -3, 0), Vector3(8, 6, 7), rock, 11))
	a.ramp(Vector3(0, 0, -12.6), Vector3(0, 4, -27.4), 3.6, ruin, Arena.P_MARBLE, 0.6)
	a.solid(Vector3(-5, 5.5, -38), Vector3(0.8, 3, 4), ruin, Arena.P_BRICK)
	a.column(Vector3(5, 4, -39), 0.6, 4.0, ruin, Arena.P_MARBLE, 8)
	# east island (mirror: west), low
	a.solid(Vector3(34, -5, 0), Vector3(14, 4, 16), grass, Arena.P_ROCK, 1.2)
	a.custom(Vector3(34, -7, 0), 0.0, func(m: MeshKit):
		m.rock(Vector3(0, -3, 0), Vector3(7, 6, 8), rock, 12))
	a.ramp(Vector3(12.6, 0, 0), Vector3(27.4, -3, 0), 3.6, ruin, Arena.P_MARBLE, 0.6)
	a.solid(Vector3(37, -2, -4), Vector3(2, 2, 2), ruin, Arena.P_BRICK, 1.0, 0.4)
	# a small rock to the north-east (mirror: south-west)
	a.solid(Vector3(24, 0, -24), Vector3(7, 2, 7), grass, Arena.P_ROCK, 1.2)
	a.custom(Vector3(24, -1, -24), 0.0, func(m: MeshKit):
		m.rock(Vector3(0, -2, 0), Vector3(3.5, 4, 3.5), rock, 13))
	# pads round the ring: N -> E, E -> S (mirror: S -> W, W -> N), hub -> NE rock -> N
	a.pad(Vector3(6, 4, -34), Vector3(31, -3, -5), 3.0)
	a.pad(Vector3(31, -3, 6), Vector3(5, 4, 32), 3.0)
	a.pad(Vector3(9, 0, -9), Vector3(23, 1, -23), 2.5)
	a.pad(Vector3(21.5, 1, -26), Vector3(3, 4, -33), 2.5)
	for p in [Vector3(-18, 9, -20), Vector3(20, 6, 12), Vector3(-36, 4, -18), Vector3(0, 14, -46), Vector3(40, 8, 20), Vector3(-12, -8, -24)]:
		a.hedron(p, randf_range(2.0, 4.0) if false else 3.0 + absf(p.x) * 0.02, hed, glow, 0.15)
	a.mirror = false
	a.light(Vector3(0, 4, 0), glow, 1.2, 14.0)
	a.weapon("fireball", Vector3(0, 0, 0))
	a.weapon("disintegrate", Vector3(0, 4, -37))
	a.weapon("lash", Vector3(0, 4, 37))
	a.weapon("thunder", Vector3(36, -3, 3))
	a.weapon("pulse", Vector3(-36, -3, -3))
	a.weapon("thunder", Vector3(-6, 0, 6))
	a.weapon("pulse", Vector3(6, 0, -6))
	a.item("overload", Vector3(24.5, 1, -23.5))
	a.item("haste", Vector3(-24.5, 1, 23.5))
	a.item("elixir", Vector3(38, -3, -5))
	a.item("aegis", Vector3(-38, -3, 5))
	for p in [Vector3(0, 0, -10), Vector3(0, 0, 10), Vector3(-10, 0, 0), Vector3(10, 0, 0), Vector3(-5, 4, -30), Vector3(5, 4, 30)]:
		a.item("salve", p)
	for p in [Vector3(0, 2, -20), Vector3(0, 2, 20), Vector3(20, -1.5, 0), Vector3(-20, -1.5, 0)]:
		a.item("shard", p)
	a.item("plate", Vector3(0, 4, -31))
	a.item("plate", Vector3(0, 4, 31))
	for p in [[Vector3(-6, 0, -6), 0.8], [Vector3(6, 0, 6), -2.3], [Vector3(-3, 4, -38), 3.1], [Vector3(3, 4, 38), 0.0],
			[Vector3(38, -3, 4), 1.6], [Vector3(-38, -3, -4), -1.6], [Vector3(24, 1, -25), 2.4], [Vector3(-24, 1, 25), -0.8],
			[Vector3(6, 0, -10), 0.0], [Vector3(-6, 0, 10), PI], [Vector3(31, -3, -6), 1.6], [Vector3(-31, -3, 6), -1.6]]:
		a.spawn(p[0], p[1])


# --- Furnace Core (New Phyrexia) ------------------------------------------------------------

static func build_furnace(a: Arena) -> void:
	var metal := Color(0.36, 0.36, 0.38)
	var oil := Color(0.16, 0.15, 0.16)
	var porcelain := Color(0.86, 0.84, 0.8)
	var red := Color(1.0, 0.25, 0.12)
	var vein := Color(0.9, 0.15, 0.1)
	var S := 32.0
	a.kill_y = -8.0
	# the floor round the furnace pit (16 x 16 in the middle)
	a.floor_rect(-S, -S, S, -8, 0.0, metal, Arena.P_OIL, 1.0)
	a.floor_rect(-S, 8, S, S, 0.0, metal, Arena.P_OIL, 1.0)
	a.floor_rect(-S, -8, -8, 8, 0.0, metal, Arena.P_OIL, 1.0)
	a.floor_rect(8, -8, S, 8, 0.0, metal, Arena.P_OIL, 1.0)
	for k in 4:
		a.solid(q(Vector3(0, -3.5, -8.4), k), Vector3(17.6, 5, 0.8) if k % 2 == 0 else Vector3(0.8, 5, 17.6), oil, Arena.P_METAL)
	a.lava(-8, -8, 8, 8, -2.5, red)
	# the bridge over the fire
	a.floor_rect(-1.3, -8, 1.3, 8, 0.0, porcelain, Arena.P_METAL, 0.6)
	a.light(Vector3(0, -1, 0), red, 3.0, 16.0)
	a.light(Vector3(0, 9, 0), Color(1.0, 0.5, 0.3), 1.5, 20.0)
	walls_rect(a, -S, -S, S, S, 0.0, 16.0, oil, Arena.P_OIL, 1.0)
	for k in 4:
		# the upper ring walkway, a ramp up to it, columns
		a.solid(q(Vector3(0, 4.6, -26), k), Vector3(60, 0.8, 8) if k % 2 == 0 else Vector3(8, 0.8, 60), metal, Arena.P_METAL)
		a.ramp(q(Vector3(0, 0, -11.5), k), q(Vector3(0, 5, -22.2), k), 4.0, porcelain, Arena.P_METAL, 0.6)
		for i in 4:
			a.column(q(Vector3(-15.0 + i * 10.0, 0, -22.6), k), 0.45, 4.2, porcelain, Arena.P_MARBLE, 8)
		# a tower platform in each corner, reached by a pad from the ring
		a.solid(q(Vector3(26, 9.6, -26), k), Vector3(8, 0.8, 8), porcelain, Arena.P_METAL)
		a.column(q(Vector3(23, 5, -23), k), 0.4, 4.2, oil, Arena.P_OIL, 8)
		a.pad(q(Vector3(26, 5, -14), k), q(Vector3(26, 10, -26), k), 2.0)
		# Phyrexian ribs on the walls and red veins
		a.custom(q(Vector3(0, 0, -S + 0.5), k), k * PI * 0.5, func(m: MeshKit):
			for i in 7:
				var x := -27.0 + i * 9.0
				for j in 6:
					var t0 := float(j) / 6.0
					var t1 := float(j + 1) / 6.0
					m.cyl(Vector3(x + sin(t0 * PI) * 1.2, t0 * 15.0, 0.4 + sin(t0 * PI) * 0.9),
						Vector3(x + sin(t1 * PI) * 1.2, t1 * 15.0, 0.4 + sin(t1 * PI) * 0.9), 0.32 - t0 * 0.15, 0.32 - t1 * 0.15, porcelain, 6)
			m.cyl(Vector3(-S, 1.5, 0.2), Vector3(S, 1.5, 0.2), 0.12, 0.12, vein, 6, true)
			m.cyl(Vector3(-S, 12.0, 0.2), Vector3(S, 12.0, 0.2), 0.12, 0.12, vein, 6, true))
		a.custom(q(Vector3(26, 10, -26), k), 0.0, func(m: MeshKit):
			m.ring(Vector3(0, 0.05, 0), Vector3.UP, 3.4, 0.08, vein, 12, 3, true))
	# portals: west floor -> north-east tower, east floor -> south-west tower
	a.tele(Vector3(-30, 0, 0), PI * 0.5, Vector3(24, 10, -24), PI * 0.75, Color(0.9, 0.2, 0.2))
	a.tele(Vector3(30, 0, 0), -PI * 0.5, Vector3(-24, 10, 24), -PI * 0.25, Color(0.9, 0.2, 0.2))
	for p in [Vector3(-20, 0, -20), Vector3(20, 0, 20)]:
		a.solid(p + Vector3(0, 1.2, 0), Vector3(3, 2.4, 3), oil, Arena.P_OIL, 1.0, 0.785)
	a.light(Vector3(-20, 3, 20), vein, 1.4, 14.0)
	a.light(Vector3(20, 3, -20), vein, 1.4, 14.0)
	a.weapon("fireball", Vector3(0, 0, 0))
	a.weapon("disintegrate", Vector3(26, 10, -26))
	a.weapon("lash", Vector3(-26, 10, 26))
	a.weapon("thunder", Vector3(0, 5, -27))
	a.weapon("pulse", Vector3(0, 5, 27))
	a.weapon("thunder", Vector3(-20, 0, 0))
	a.weapon("pulse", Vector3(20, 0, 0))
	a.item("elixir", Vector3(-26, 10, -26))
	a.item("aegis", Vector3(26, 10, 26))
	a.item("overload", Vector3(-27, 0, -27))
	a.item("haste", Vector3(27, 0, 27))
	for k in 4:
		a.item("salve", q(Vector3(14, 0, -27), k))
		a.item("shard", q(Vector3(-14, 5, -27), k))
		a.item("shard", q(Vector3(-10, 5, -27), k))
	a.item("plate", Vector3(27, 5, 0))
	a.item("plate", Vector3(-27, 5, 0))
	for k in 4:
		a.spawn(q(Vector3(14, 0, -18), k), k * PI * 0.5 + PI)
		a.spawn(q(Vector3(-26, 0, -14), k), k * PI * 0.5 - PI * 0.5)
		a.spawn(q(Vector3(10, 5, -26), k), k * PI * 0.5 + PI * 0.5)


# --- Nyx Spires (Theros), Capture the Flag ---------------------------------------------------

static func build_nyx(a: Arena) -> void:
	var marble := Color(0.78, 0.76, 0.84)
	var night := Color(0.2, 0.2, 0.38)
	var gold := Color(0.95, 0.75, 0.35)
	var star := Color(0.7, 0.75, 1.0)
	a.kill_y = -25.0
	a.mirror = true
	# a long floating strip of night-marble, with a tower at each end
	a.solid(Vector3(0, -1.5, -31), Vector3(24, 3, 62), night, Arena.P_MARBLE, 1.4)
	a.strip(Vector3(12.05, 0.02, -62), Vector3(12.05, 0.02, 0), 0.15, star)
	a.strip(Vector3(-12.05, 0.02, -62), Vector3(-12.05, 0.02, 0), 0.15, star)
	a.custom(Vector3(0, -3, -31), 0.0, func(m: MeshKit):
		m.rock(Vector3(0, -3, -10), Vector3(9, 5, 18), Color(0.16, 0.15, 0.3), 21)
		m.rock(Vector3(2, -2, 18), Vector3(7, 4, 10), Color(0.18, 0.16, 0.32), 22))
	walls_rect(a, -6, -58, 6, -46, 0.0, 12.0, marble, Arena.P_MARBLE, 0.8, [["s", 0.0, 4.0, 4.0], ["w", -50.0, 3.0], ["e", -50.0, 3.0]])
	a.floor_rect(-5.6, -57.6, 5.6, -52, 12.0, marble, Arena.P_MARBLE, 0.6)
	crenels(a, Vector3(-5.8, 12, -45.8), Vector3(5.8, 12, -45.8), marble, Arena.P_MARBLE, 2.3)
	crenels(a, Vector3(-6.2, 12, -57.8), Vector3(-6.2, 12, -46.2), marble, Arena.P_MARBLE, 2.3)
	crenels(a, Vector3(6.2, 12, -57.8), Vector3(6.2, 12, -46.2), marble, Arena.P_MARBLE, 2.3)
	a.pad(Vector3(-3.6, 0, -49.5), Vector3(-2.5, 12, -55), 3.0)
	a.custom(Vector3(0, 0, -52), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			for t in [-1, 1]:
				m.cyl(Vector3(s * 6.4, 0, -52 + 52 + t * 6.4), Vector3(s * 6.4, 13.5, t * 6.4), 0.5, 0.42, marble, 10)
				m.sphere(Vector3(s * 6.4, 13.8, t * 6.4), Vector3(0.6, 0.6, 0.6), gold, 8, 4, true)
		m.box(Vector3(0, 11.6, 6.45), Vector3(12.8, 0.3, 0.2), gold)
		m.box(Vector3(0, 4.3, 6.45), Vector3(4.6, 0.3, 0.25), gold)
		m.ring(Vector3(0, 8.0, 6.45), Vector3.FORWARD, 1.6, 0.12, gold, 16, 3, true))
	# the field: a mound in the middle, low walls, a side ledge reached by a pad
	a.ramp(Vector3(0, 0, -12), Vector3(0, 2, -5), 7.0, marble, Arena.P_MARBLE, 0.8)
	a.floor_rect(-5, -5, 5, 0, 2.0, marble, Arena.P_MARBLE, 2.0)
	a.solid(Vector3(-7, 0.8, -22), Vector3(4, 1.6, 0.8), marble, Arena.P_MARBLE)
	a.solid(Vector3(7, 0.8, -28), Vector3(4, 1.6, 0.8), marble, Arena.P_MARBLE)
	a.column(Vector3(-9, 0, -36), 0.7, 3.2, marble, Arena.P_MARBLE, 10, gold)
	a.column(Vector3(9, 0, -36), 0.7, 3.2, marble, Arena.P_MARBLE, 10, gold)
	a.solid(Vector3(19, 1.5, -30), Vector3(6, 3, 6), night, Arena.P_MARBLE)
	a.pad(Vector3(10.5, 0, -30), Vector3(19, 3, -30), 2.0)
	a.ramp(Vector3(16, 3, -26.8), Vector3(10.6, 0, -18), 2.4, marble, Arena.P_MARBLE, 0.5)
	for p in [Vector3(-26, 6, -40), Vector3(24, -6, -12), Vector3(-30, -4, -10), Vector3(0, 22, -70), Vector3(30, 10, -55)]:
		a.hedron(p, 3.0, Color(0.22, 0.2, 0.36), star, 0.12)
	a.light(Vector3(0, 6, -50), gold, 1.6, 14.0)
	a.weapon("disintegrate", Vector3(0, 12, -56))
	a.weapon("fireball", Vector3(0, 0, -40))
	a.weapon("lash", Vector3(8, 0, -22))
	a.weapon("pulse", Vector3(-8, 0, -28))
	a.weapon("thunder", Vector3(19, 3, -30))
	a.item("plate", Vector3(4, 0, -56))
	a.item("salve", Vector3(-4, 0, -56))
	a.item("salve", Vector3(-9, 0, -50))
	a.item("shard", Vector3(-3, 0, -20))
	a.item("shard", Vector3(3, 0, -14))
	a.flag(0, Vector3(0, 0, -55))
	for p in [Vector3(-3, 0, -49), Vector3(3, 0, -49), Vector3(-9, 0, -44), Vector3(9, 0, -44), Vector3(-3, 12, -54), Vector3(0, 0, -42)]:
		a.spawn(p, 0.0, 0)
	a.mirror = false
	a.item("elixir", Vector3(0, 2, 0))


# --- Benalish Keeps (Dominaria), Capture the Flag ------------------------------------------

static func build_keeps(a: Arena) -> void:
	var grass := Color(0.38, 0.52, 0.26)
	var stone := Color(0.66, 0.62, 0.55)
	var dark := Color(0.4, 0.37, 0.33)
	var water := Color(0.25, 0.45, 0.6)
	var wood := Color(0.45, 0.3, 0.18)
	var cliff := Color(0.48, 0.44, 0.38)
	a.kill_y = -20.0
	a.mirror = true
	a.floor_rect(-30, -70, 30, -6, 0.0, grass, Arena.P_ROCK, 2.0, 1.5)
	a.floor_rect(-30, -3, 30, 0, -1.2, water.darkened(0.3), Arena.P_ROCK, 1.0)
	a.ramp(Vector3(0, -1.2, -3), Vector3(0, 0, -6), 60.0, Color(0.45, 0.42, 0.32), Arena.P_ROCK, 1.0)
	a.deco(Vector3(0, -1.1, -1.5), Vector3(60, 0.02, 3.0), water, true)
	a.floor_rect(12, -8, 18, 0, 0.3, wood, Arena.P_WOOD, 0.6)
	a.custom(Vector3(15, 0.3, -4), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			m.box(Vector3(s * 2.9, 0.6, 0), Vector3(0.15, 0.12, 8), wood.darkened(0.2))
			for i in 5:
				m.box(Vector3(s * 2.9, 0.3, -3.6 + i * 1.8), Vector3(0.15, 0.6, 0.15), wood.darkened(0.2)))
	# cliffs round the valley
	a.solid(Vector3(31.5, 5, -35), Vector3(3, 10, 72), cliff, Arena.P_ROCK, 1.5)
	a.solid(Vector3(0, 5, -71.5), Vector3(66, 10, 3), cliff, Arena.P_ROCK, 1.5)
	# the keep: thick walls, a gate, side doors, a wall walk with stairs up
	walls_rect(a, -20, -66, 20, -40, 0.0, 8.0, stone, Arena.P_BRICK, 2.0, [["s", 0.0, 6.0, 5.0], ["w", -50.0, 4.0], ["e", -50.0, 4.0]])
	crenels(a, Vector3(-20.5, 8, -39.3), Vector3(20.5, 8, -39.3), stone, Arena.P_BRICK, 2.0, Vector3(1.0, 1.0, 0.6))
	crenels(a, Vector3(-20.7, 8, -65), Vector3(-20.7, 8, -41), stone, Arena.P_BRICK, 2.4, Vector3(1.0, 1.0, 0.6))
	crenels(a, Vector3(20.7, 8, -65), Vector3(20.7, 8, -41), stone, Arena.P_BRICK, 2.4, Vector3(1.0, 1.0, 0.6))
	a.stairs(Vector3(-15, 0, -53), Vector3(-15, 8, -41.05), 2.6, stone, Arena.P_MARBLE)
	a.stairs(Vector3(15, 0, -53), Vector3(15, 8, -41.05), 2.6, stone, Arena.P_MARBLE)
	a.solid(Vector3(0, 6, -60), Vector3(14, 12, 9), dark, Arena.P_BRICK)
	crenels(a, Vector3(-7, 12, -55.3), Vector3(7, 12, -55.3), dark, Arena.P_BRICK, 2.0)
	a.custom(Vector3(0, 0, -55.4), 0.0, func(m: MeshKit):
		m.box(Vector3(0, 6.0, 0), Vector3(3.0, 4.0, 0.08), Color(0.9, 0.9, 0.85))
		m.box(Vector3(0, 6.6, 0.02), Vector3(1.6, 1.6, 0.06), Color(0.85, 0.7, 0.3), true)
		m.box(Vector3(0, 2.0, 0.01), Vector3(4.0, 4.0, 0.05), wood.darkened(0.3)))
	for x in [-10.0, 10.0]:
		a.torch(Vector3(x, 0, -56), Color(1.0, 0.7, 0.35), x < 0.0)
	# a ruined watchtower in the field with a pad to its top
	walls_rect(a, -21, -25, -15, -19, 0.0, 6.0, stone, Arena.P_BRICK, 0.6, [["s", -18.0, 2.4], ["e", -22.0, 2.4]])
	a.floor_rect(-20.7, -24.7, -15.3, -19.3, 6.0, wood, Arena.P_WOOD, 0.4)
	crenels(a, Vector3(-21, 6, -18.9), Vector3(-15, 6, -18.9), stone, Arena.P_BRICK, 1.5, Vector3(0.7, 0.8, 0.5))
	a.pad(Vector3(-18, 0, -17), Vector3(-18, 6, -22.5), 2.5)
	# trees and rocks
	for p in [Vector3(-8, 0, -30), Vector3(10, 0, -18), Vector3(24, 0, -26), Vector3(-25, 0, -10), Vector3(-26, 0, -48), Vector3(25, 0, -60)]:
		a.column(p, 0.45, 3.6, wood, Arena.P_WOOD, 6)
		a.custom(p, 0.0, func(m: MeshKit):
			m.sphere(Vector3(0, 4.6, 0), Vector3(2.4, 2.0, 2.4), Color(0.22, 0.42, 0.18), 8, 5)
			m.sphere(Vector3(0.8, 5.8, 0.4), Vector3(1.5, 1.3, 1.5), Color(0.28, 0.5, 0.22), 7, 4))
	for p in [Vector3(4, 0, -24), Vector3(-12, 0, -10), Vector3(20, 0, -10)]:
		a.solid(p + Vector3(0, 0.7, 0), Vector3(2.6, 1.4, 2.0), cliff, Arena.P_ROCK, 1.0, p.x * 0.3)
	a.weapon("fireball", Vector3(0, 8, -40))
	a.weapon("disintegrate", Vector3(-18, 6, -22))
	a.weapon("thunder", Vector3(25, 0, -50))
	a.weapon("lash", Vector3(-25, 0, -32))
	a.weapon("pulse", Vector3(12, 0, -28))
	a.item("plate", Vector3(-10, 0, -47))
	a.item("salve", Vector3(10, 0, -47))
	a.item("salve", Vector3(-25, 0, -56))
	a.item("shard", Vector3(15, 0.3, -6))
	a.item("shard", Vector3(15, 0.3, -2))
	a.flag(0, Vector3(0, 0, -51))
	for p in [Vector3(-8, 0, -46), Vector3(8, 0, -46), Vector3(-12, 0, -52), Vector3(12, 0, -52), Vector3(-10, 8, -40), Vector3(10, 8, -40)]:
		a.spawn(p, 0.0, 0)
	a.mirror = false
	a.item("elixir", Vector3(0, -1.2, 0))


# --- Orazca Temples (Ixalan), Capture the Flag ----------------------------------------------

static func build_temples(a: Arena) -> void:
	var jungle := Color(0.3, 0.46, 0.24)
	var stone := Color(0.72, 0.62, 0.45)
	var gold := Color(0.95, 0.75, 0.3)
	var moss := Color(0.45, 0.5, 0.32)
	var wood := Color(0.4, 0.28, 0.16)
	a.kill_y = -20.0
	a.mirror = true
	a.floor_rect(-34, -66, 34, -12, 0.0, jungle, Arena.P_ROCK, 3.5, 1.4)
	a.floor_rect(-34, -12, -14, 0, 0.0, jungle, Arena.P_ROCK, 3.5, 1.4)
	a.floor_rect(14, -12, 34, 0, 0.0, jungle, Arena.P_ROCK, 3.5, 1.4)
	# the sunken plaza (cenote) in the middle
	a.floor_rect(-14, -12, 14, 0, -3.0, moss, Arena.P_TILE, 1.0, 1.2)
	a.ramp(Vector3(0, -3, -6), Vector3(0, 0, -12.1), 6.0, stone, Arena.P_MARBLE, 0.6)
	a.deco(Vector3(-7, -2.95, -2), Vector3(5, 0.04, 3), Color(0.2, 0.55, 0.6), true)
	a.column(Vector3(-10, -3, -8), 0.7, 5.0, stone, Arena.P_MARBLE, 8, moss)
	a.column(Vector3(10, -3, -4), 0.7, 3.0, stone, Arena.P_MARBLE, 8, moss)
	# the high bridge over the cenote between two plinths
	a.solid(Vector3(0, 1.5, -18), Vector3(6, 3, 6), stone, Arena.P_BRICK)
	a.stairs(Vector3(8.5, 0, -18), Vector3(3, 3, -18), 3.0, stone, Arena.P_MARBLE)
	a.floor_rect(-1.6, -15, 1.6, 0, 3.0, wood, Arena.P_WOOD, 0.5)
	# the step pyramid: three tiers, stairs on the front and on both sides, a shrine on top
	a.solid(Vector3(0, 1.5, -46), Vector3(26, 3, 22), stone, Arena.P_BRICK, 1.2)
	a.solid(Vector3(0, 4.5, -46), Vector3(18, 3, 14), stone.darkened(0.08), Arena.P_BRICK, 1.2)
	a.solid(Vector3(0, 7.5, -46), Vector3(10, 3, 6), stone.darkened(0.15), Arena.P_BRICK, 1.2)
	a.stairs(Vector3(0, 0, -30), Vector3(0, 9, -43), 5.0, stone.lightened(0.1), Arena.P_MARBLE)
	a.stairs(Vector3(18, 0, -46), Vector3(5, 9, -46), 3.0, stone.lightened(0.1), Arena.P_MARBLE)
	a.stairs(Vector3(-18, 0, -46), Vector3(-5, 9, -46), 3.0, stone.lightened(0.1), Arena.P_MARBLE)
	a.custom(Vector3(0, 9, -46), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			for t in [-1, 1]:
				m.cyl(Vector3(s * 4.2, 0, t * 2.4), Vector3(s * 4.2, 3.4, t * 2.4), 0.35, 0.3, stone, 6)
		m.box(Vector3(0, 3.7, 0), Vector3(10, 0.6, 6), stone.darkened(0.1))
		m.box(Vector3(0, 4.2, 0), Vector3(6, 0.5, 3.6), gold)
		m.sphere(Vector3(0, 5.0, 0), Vector3(0.8, 0.8, 0.8), gold, 8, 5, true))
	# jungle on the sides: big trees and a golden idol
	for p in [Vector3(-26, 0, -26), Vector3(26, 0, -20), Vector3(-24, 0, -8), Vector3(28, 0, -40), Vector3(-28, 0, -58), Vector3(22, 0, -6)]:
		a.column(p, 0.7, 7.0, wood, Arena.P_WOOD, 7)
		a.custom(p, 0.0, func(m: MeshKit):
			for i in 5:
				var ang := TAU * i / 5.0
				m.box(Vector3(cos(ang) * 2.2, 7.2, sin(ang) * 2.2), Vector3(4.6, 0.25, 1.4), Color(0.2, 0.45, 0.18), false, -ang)
			m.sphere(Vector3(0, 7.4, 0), Vector3(1.4, 1.0, 1.4), Color(0.25, 0.5, 0.2), 7, 4))
	a.solid(Vector3(24, 1.2, -32), Vector3(3, 2.4, 3), stone, Arena.P_BRICK)
	a.custom(Vector3(24, 2.4, -32), 0.0, func(m: MeshKit):
		m.sphere(Vector3(0, 1.4, 0), Vector3(0.9, 1.3, 0.9), gold, 8, 5)
		m.box(Vector3(0, 2.4, -0.4), Vector3(0.9, 0.7, 1.2), gold))
	a.solid(Vector3(-20, 1.0, -36), Vector3(4, 2, 2.5), moss, Arena.P_ROCK, 1.0, 0.4)
	a.light(Vector3(0, 12, -46), gold, 1.4, 14.0)
	a.weapon("fireball", Vector3(-6, -3, -8))
	a.weapon("lash", Vector3(0, 3, -18))
	a.weapon("thunder", Vector3(26, 0, -30))
	a.weapon("pulse", Vector3(11, 3, -37))
	a.weapon("disintegrate", Vector3(0, 6, -51))
	a.item("plate", Vector3(-6, 6, -51))
	a.item("salve", Vector3(-16, 0, -54))
	a.item("salve", Vector3(16, 0, -54))
	a.item("shard", Vector3(-26, 0, -14))
	a.item("shard", Vector3(26, 0, -10))
	a.flag(0, Vector3(0, 9, -46))
	for p in [Vector3(-16, 0, -58), Vector3(16, 0, -58), Vector3(-20, 0, -42), Vector3(20, 0, -42), Vector3(-8, 3, -55), Vector3(8, 3, -55)]:
		a.spawn(p, 0.0, 0)
	a.mirror = false
	a.weapon("disintegrate", Vector3(0, 3, 0))
	a.item("elixir", Vector3(8, -3, 0))
	a.item("aegis", Vector3(-8, -3, 0))


# --- Neon Spires (Kamigawa), Capture the Flag -----------------------------------------------

static func build_neon(a: Arena) -> void:
	var asphalt := Color(0.2, 0.2, 0.24)
	var concrete := Color(0.45, 0.45, 0.5)
	var steel := Color(0.32, 0.34, 0.4)
	var pink := Color(1.0, 0.25, 0.65)
	var cyan := Color(0.2, 0.9, 1.0)
	var paper := Color(1.0, 0.85, 0.6)
	a.kill_y = -20.0
	a.mirror = true
	a.floor_rect(-24, -64, 24, 0, 0.0, asphalt, Arena.P_TILE, 1.0, 1.0)
	a.solid(Vector3(25, 8, -32), Vector3(2, 16, 66), concrete, Arena.P_METAL)
	a.solid(Vector3(0, 8, -65), Vector3(52, 16, 2), concrete, Arena.P_METAL)
	# the base: two storeys, a mezzanine at the back, a ramp and a pad up, doors to the sky walks
	walls_rect(a, -12, -62, 12, -44, 0.0, 10.0, concrete, Arena.P_METAL, 0.8,
		[["s", 0.0, 5.0], ["w", -59.0, 3.0], ["e", -59.0, 3.0], ["w", -55.0, 3.0, 3.4, 5.0], ["e", -55.0, 3.0, 3.4, 5.0]])
	a.floor_rect(-11.6, -61.6, 11.6, -52, 5.0, steel, Arena.P_METAL, 0.6)
	a.floor_rect(-12, -62, 12, -44, 10.6, concrete, Arena.P_METAL, 0.6)
	a.ramp(Vector3(-9.6, 0, -44.9), Vector3(-9.6, 5, -52.2), 3.2, steel, Arena.P_METAL, 0.5)
	a.pad(Vector3(6, 0, -48), Vector3(6, 5, -56), 2.0)
	a.custom(Vector3(0, 0, -43.55), 0.0, func(m: MeshKit):
		m.box(Vector3(0, 6.5, 0), Vector3(8, 2.2, 0.1), Color(0.1, 0.1, 0.12))
		m.box(Vector3(0, 6.5, 0.05), Vector3(7.4, 0.25, 0.06), pink, true)
		m.box(Vector3(-2.4, 6.5, 0.05), Vector3(0.25, 1.6, 0.06), cyan, true)
		m.box(Vector3(2.4, 6.5, 0.05), Vector3(0.25, 1.6, 0.06), cyan, true)
		m.box(Vector3(0, 3.6, 0.04), Vector3(5.4, 0.15, 0.06), cyan, true))
	# sky walks along both sides at 5 m, landings with stairs, bridges to the centre deck
	for s in [-1.0, 1.0]:
		a.floor_rect(s * 12.4, -58, s * 19, 0, 5.0, steel, Arena.P_METAL, 0.6)
		a.floor_rect(s * 19, -36, s * 22.4, -32, 5.0, steel, Arena.P_METAL, 0.6)
		a.stairs(Vector3(s * 20.7, 0, -24), Vector3(s * 20.7, 5, -32), 3.4, concrete, Arena.P_MARBLE)
		a.strip(Vector3(s * 12.45, 5.03, -58), Vector3(s * 12.45, 5.03, 0), 0.12, cyan if s < 0 else pink)
		for z in [-48.0, -36.0, -24.0, -12.0]:
			a.column(Vector3(s * 15.7, 0, z), 0.35, 4.4, steel, Arena.P_METAL, 8)
	a.floor_rect(-6, -6, 6, 0, 5.0, steel, Arena.P_METAL, 0.6)
	a.floor_rect(6, -3, 12.4, 0, 5.0, steel, Arena.P_METAL, 0.6)
	a.floor_rect(-12.4, -3, -6, 0, 5.0, steel, Arena.P_METAL, 0.6)
	a.column(Vector3(-4.5, 0, -4.5), 0.5, 4.4, steel, Arena.P_METAL, 8)
	a.column(Vector3(4.5, 0, -4.5), 0.5, 4.4, steel, Arena.P_METAL, 8)
	a.custom(Vector3(0, 5, 0), 0.0, func(m: MeshKit):
		m.box(Vector3(0, 0.04, -5.9), Vector3(12, 0.06, 0.15), pink, true))
	# a portal in the base straight to the centre deck
	a.tele(Vector3(-8, 0, -60.5), 0.0, Vector3(-3, 5, -3), 0.0, cyan)
	# lanterns, signs and cover in the street
	for p in [Vector3(-6, 0, -30), Vector3(7, 0, -20), Vector3(0, 0, -36)]:
		a.solid(p + Vector3(0, 0.9, 0), Vector3(2.4, 1.8, 1.2), steel, Arena.P_METAL, 1.0, p.x * 0.2)
	a.custom(Vector3(0, 0, 0), 0.0, func(m: MeshKit):
		for z in [-40.0, -28.0, -16.0]:
			for s in [-1, 1]:
				m.cyl(Vector3(s * 23.6, 7.0, z), Vector3(s * 23.6, 8.2, z), 0.35, 0.35, paper, 8, true)
				m.box(Vector3(s * 23.9, 11.0, z + 3.0), Vector3(0.1, 4.0, 1.4), pink if (int(z) / 12) % 2 == 0 else cyan, true))
	a.light(Vector3(0, 4, -50), cyan, 1.4, 14.0)
	a.light(Vector3(16, 7, -24), pink, 1.4, 14.0)
	a.weapon("fireball", Vector3(0, 5, -3))
	a.weapon("disintegrate", Vector3(0, 5, -58))
	a.weapon("thunder", Vector3(10, 0, -24))
	a.weapon("lash", Vector3(16, 5, -40))
	a.weapon("pulse", Vector3(-10, 0, -34))
	a.item("plate", Vector3(8, 5, -60))
	a.item("salve", Vector3(-6, 0, -50))
	a.item("salve", Vector3(-16, 5, -20))
	a.item("shard", Vector3(20.7, 5, -34))
	a.item("shard", Vector3(-16, 5, -48))
	a.flag(0, Vector3(0, 0, -57))
	for p in [Vector3(-6, 0, -47), Vector3(6, 0, -52), Vector3(-4, 5, -58), Vector3(4, 5, -58), Vector3(-16, 0, -52), Vector3(16, 0, -52)]:
		a.spawn(p, 0.0, 0)
	a.mirror = false
	a.item("elixir", Vector3(0, 0, 0))


# --- Necropolis Trench (Amonkhet), Capture the Flag -----------------------------------------

static func build_necropolis(a: Arena) -> void:
	var sand := Color(0.85, 0.7, 0.45)
	var lime := Color(0.86, 0.8, 0.66)
	var blue := Color(0.15, 0.3, 0.65)
	var gold := Color(0.95, 0.75, 0.3)
	var shade := Color(0.6, 0.48, 0.32)
	a.kill_y = -20.0
	a.mirror = true
	a.floor_rect(-30, -62, -4, 0, 0.0, sand, Arena.P_ROCK, 4.0, 2.0)
	a.floor_rect(4, -62, 30, 0, 0.0, sand, Arena.P_ROCK, 4.0, 2.0)
	a.floor_rect(-4, -62, 4, -34, 0.0, sand, Arena.P_ROCK, 4.0, 2.0)
	# the trench down the middle, with a ramp at each end and two bridges over it
	a.floor_rect(-4, -34, 4, 0, -3.5, shade, Arena.P_TILE, 1.0, 1.4)
	a.ramp(Vector3(0, -3.5, -28), Vector3(0, 0, -34.1), 8.0, lime, Arena.P_MARBLE, 0.6)
	a.floor_rect(-4.2, -20, 4.2, -16, 0.0, lime, Arena.P_MARBLE, 0.6)
	a.custom(Vector3(0, -3.5, -10), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			for i in 4:
				m.box(Vector3(s * 3.95, 1.6, -14 + i * 7.0), Vector3(0.1, 1.4, 1.0), blue, false)
				m.box(Vector3(s * 3.92, 1.6, -14 + i * 7.0), Vector3(0.1, 0.5, 0.5), gold, true))
	a.solid(Vector3(31.5, 6, -31), Vector3(3, 12, 64), lime, Arena.P_BRICK)
	a.solid(Vector3(0, 6, -63.5), Vector3(60, 12, 3), lime, Arena.P_BRICK)
	# the tomb: flag inside, a roof to snipe from, stairs up the west side
	walls_rect(a, -10, -60, 10, -46, 0.0, 8.0, lime, Arena.P_BRICK, 1.2, [["s", 0.0, 4.0, 3.6], ["w", -53.0, 3.0], ["e", -53.0, 3.0]])
	a.floor_rect(-10.6, -60.6, 10.6, -45.4, 8.0, lime, Arena.P_TILE, 0.6)
	a.stairs(Vector3(-12.0, 0, -45.6), Vector3(-12.0, 8, -58), 2.8, lime, Arena.P_MARBLE)
	a.floor_rect(-13.4, -61, -10.6, -58, 8.0, lime, Arena.P_TILE, 0.6)
	crenels(a, Vector3(-10, 8, -45.6), Vector3(10, 8, -45.6), gold, Arena.P_BRICK, 2.5, Vector3(0.6, 0.6, 0.4))
	a.custom(Vector3(0, 0, -45.3), 0.0, func(m: MeshKit):
		for s in [-1, 1]:
			m.cyl(Vector3(s * 3.0, 0, 0.4), Vector3(s * 3.0, 6.5, 0.4), 0.55, 0.5, lime, 8)
			m.box(Vector3(s * 3.0, 6.7, 0.4), Vector3(1.4, 0.4, 1.4), gold)
		m.box(Vector3(0, 5.6, 0.05), Vector3(4.6, 0.6, 0.1), blue)
		m.box(Vector3(0, 6.6, 0.05), Vector3(1.2, 1.2, 0.1), gold, true))
	for x in [-6.0, 6.0]:
		a.solid(Vector3(x, 0.6, -57), Vector3(1.6, 1.2, 3.0), blue, Arena.P_MARBLE)
	a.torch(Vector3(-8, 0, -48), Color(1.0, 0.65, 0.3))
	# monuments and mesas on the sand
	a.solid(Vector3(16, 1.0, -4), Vector3(5, 2, 5), lime, Arena.P_BRICK)
	a.custom(Vector3(16, 2, -4), 0.0, func(m: MeshKit):
		m.taper(Vector3.ZERO, Vector2(1.6, 1.6), Vector2(0.3, 0.3), 12.0, lime)
		m.cyl(Vector3(0, 12, 0), Vector3(0, 13, 0), 0.25, 0.0, gold, 4, true))
	a.solid(Vector3(-18, 1.5, -26), Vector3(8, 3, 6), shade, Arena.P_ROCK, 1.2)
	a.ramp(Vector3(-18, 0, -18.5), Vector3(-18, 3, -23), 4.0, sand, Arena.P_ROCK, 0.6)
	a.solid(Vector3(20, 0.8, -30), Vector3(3, 1.6, 2), shade, Arena.P_ROCK, 1.0, 0.5)
	a.solid(Vector3(8, 0.8, -26), Vector3(2.5, 1.6, 2.5), shade, Arena.P_ROCK, 1.0, 0.2)
	a.light(Vector3(0, 4, -52), Color(1.0, 0.7, 0.4), 1.4, 12.0)
	a.weapon("fireball", Vector3(0, -3.5, -9))
	a.weapon("disintegrate", Vector3(0, 8, -52))
	a.weapon("thunder", Vector3(16, 2, -4))
	a.weapon("lash", Vector3(-18, 3, -27))
	a.weapon("pulse", Vector3(7, 0, -42))
	a.item("plate", Vector3(-6, 0, -50))
	a.item("salve", Vector3(6, 0, -50))
	a.item("salve", Vector3(-22, 0, -40))
	a.item("shard", Vector3(0, 0, -18))
	a.item("shard", Vector3(22, 0, -18))
	a.flag(0, Vector3(0, 0, -55))
	for p in [Vector3(-5, 0, -49), Vector3(5, 0, -49), Vector3(-16, 0, -50), Vector3(16, 0, -50), Vector3(-6, 8, -56), Vector3(6, 8, -56)]:
		a.spawn(p, 0.0, 0)
	a.mirror = false
	a.item("elixir", Vector3(0, -3.5, 0))
