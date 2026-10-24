class_name Arena
extends Node3D
## One arena, built in code from a map script in maps.gd: solid boxes, ramps, stairs and
## columns (each with collision and a mesh drawn with the world shader), decoration, lights,
## jump pads, portals, pickups, spawn points, flag bases, deadly lava and a fall line, the
## sky and the navigation mesh the bots walk on (baked here, with links for pads, portals and
## the ledges a bot can drop from). Capture the Flag maps build one half with `mirror` on,
## which adds everything a second time turned half round the centre with the teams swapped.

const P_PLAIN := 0
const P_TILE := 1
const P_BRICK := 2
const P_METAL := 3
const P_ROCK := 4
const P_WOOD := 5
const P_BRASS := 6
const P_MARBLE := 7
const P_OIL := 8
const CHUNK := 20.0

var def: Dictionary
var spawns := []          # {pos, yaw, team}
var items := []           # {kind, pos}; kind is an Data.ITEMS key or "w:<weapon>"
var pads := []            # {pos, vel, target}
var teles := []           # {pos, dest, yaw}
var flags := [Vector3.ZERO, Vector3.ZERO]
var kill_y := -40.0
var hazards: Array[AABB] = []
var env: Environment
var sun: DirectionalLight3D
var mirror := false
var nav_region: NavigationRegion3D
var spinners: Array[Node3D] = []
var portal_discs: Array[MeshInstance3D] = []
var omni: Array[OmniLight3D] = []
var _kits := {}
var _body: StaticBody3D
var _boxes := []          # {xf: Transform3D, h: Vector3 half size} of every solid, for ledge links
var _links := 0


func _init(d: Dictionary) -> void:
	def = d
	name = "Arena"


## Builds everything. Called once the arena is in the tree (the nav bake reads the colliders).
func build() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	Callable(Maps, "build_" + str(def.id)).call(self)
	mirror = false
	_commit_meshes()
	_build_env()
	_bake_nav()


# --- mirroring -----------------------------------------------------------------------------

func _mp(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, -p.z)


# --- solids --------------------------------------------------------------------------------

## A box with collision, centre `c`, full size `s`, turned `yaw` about Y.
func solid(c: Vector3, s: Vector3, col: Color, pat := P_TILE, sc := 1.0, yaw := 0.0) -> void:
	_solid(c, s, Basis(Vector3.UP, yaw), col, pat, sc)
	if mirror:
		_solid(_mp(c), s, Basis(Vector3.UP, yaw + PI), col, pat, sc)


## A floor slab given by its top surface rectangle (x0,z0)-(x1,z1) at height y, `th` thick.
func floor_rect(x0: float, z0: float, x1: float, z1: float, y: float, col: Color, pat := P_TILE, th := 1.0, sc := 1.0) -> void:
	solid(Vector3((x0 + x1) * 0.5, y - th * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), th, absf(z1 - z0)), col, pat, sc)


## A wall from (x0,z0) to (x1,z1) along one axis, from y0 up h metres, `th` thick.
func wall(x0: float, z0: float, x1: float, z1: float, y0: float, h: float, col: Color, pat := P_BRICK, th := 0.8, sc := 1.0) -> void:
	var a := Vector3(x0, 0, z0)
	var b := Vector3(x1, 0, z1)
	var len := a.distance_to(b)
	var yaw := atan2(b.x - a.x, b.z - a.z)
	solid((a + b) * 0.5 + Vector3(0, y0 + h * 0.5, 0), Vector3(th, h, len + th), col, pat, sc, yaw)


func _solid(c: Vector3, s: Vector3, bs: Basis, col: Color, pat: int, sc: float, collide := true, visible := true) -> void:
	if visible:
		# big boxes are cut into pieces so each piece gets its own nearby lights
		var nx := maxi(1, ceili(s.x / CHUNK))
		var nz := maxi(1, ceili(s.z / CHUNK))
		for i in nx:
			for j in nz:
				var ps := Vector3(s.x / nx, s.y, s.z / nz)
				var pc := c + bs * Vector3(-s.x * 0.5 + ps.x * (i + 0.5), 0, -s.z * 0.5 + ps.z * (j + 0.5))
				var k := _kit_at(pc)
				k.pat = pat
				k.scale = sc
				k.obox(pc, ps, bs, col)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s
		cs.shape = sh
		cs.transform = Transform3D(bs, c)
		_body.add_child(cs)
		_boxes.append({"xf": Transform3D(bs, c), "h": s * 0.5})


## A sloped walkway whose top surface runs from `a` (low end, centre of the edge) to `b`.
func ramp(a: Vector3, b: Vector3, w: float, col: Color, pat := P_TILE, th := 0.6, sc := 1.0) -> void:
	_ramp(a, b, w, col, pat, th, sc, true)
	if mirror:
		_ramp(_mp(a), _mp(b), w, col, pat, th, sc, true)


func _ramp(a: Vector3, b: Vector3, w: float, col: Color, pat: int, th: float, sc: float, visible: bool) -> void:
	var d := b - a
	var z := d.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x).normalized()
	var bs := Basis(x, y, z)
	var len := d.length() + 0.4
	_solid((a + b) * 0.5 - y * th * 0.5, Vector3(w, th, len), bs, col, pat, sc, true, visible)
	# fill the space under a tall ramp with steps so nobody gets wedged beneath it
	var lo := a if a.y < b.y else b
	var hi := b if a.y < b.y else a
	var rise := hi.y - lo.y
	if rise <= 1.2:
		return
	var flat := Vector3(hi.x - lo.x, 0, hi.z - lo.z)
	var hb := Basis(Vector3.UP, atan2(flat.x, flat.z))
	var n := ceili(rise / 0.9)
	for i in range(1, n):
		var t := float(i) / n
		var h := rise * t - th
		if h < 0.3:
			continue
		var c := lo + flat * (1.0 + t) * 0.5 + Vector3(0, h * 0.5, 0)
		_solid(c, Vector3(w * 0.98, h, flat.length() * (1.0 - t)), hb, col.darkened(0.2), pat, sc, true, visible)


## Stairs from `a` (bottom, centre of the first step's front edge) up to `b`; steps to look at,
## a smooth slope to walk on.
func stairs(a: Vector3, b: Vector3, w: float, col: Color, pat := P_MARBLE, sc := 1.0) -> void:
	_stairs(a, b, w, col, pat, sc)
	if mirror:
		_stairs(_mp(a), _mp(b), w, col, pat, sc)


func _stairs(a: Vector3, b: Vector3, w: float, col: Color, pat: int, sc: float) -> void:
	var rise := b.y - a.y
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var n := maxi(2, ceili(absf(rise) / 0.32))
	var yaw := atan2(flat.x, flat.z)
	var bs := Basis(Vector3.UP, yaw)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var h := rise * t1
		var foot := a + flat * (t0 + t1) * 0.5
		var k := _kit_at(foot)
		k.pat = pat
		k.scale = sc
		var bottom := minf(a.y - 0.3, a.y + h - 1.2)
		k.obox(Vector3(foot.x, (a.y + h + bottom) * 0.5, foot.z), Vector3(w, a.y + h - bottom, flat.length() / n + 0.02), bs, col)
	_ramp(a, b, w, col, pat, 0.5, sc, false)


## A round column with collision, standing on `base`.
func column(base: Vector3, r: float, h: float, col: Color, pat := P_MARBLE, segs := 10, cap_col := Color(0, 0, 0, 0)) -> void:
	_column(base, r, h, col, pat, segs, cap_col)
	if mirror:
		_column(_mp(base), r, h, col, pat, segs, cap_col)


func _column(base: Vector3, r: float, h: float, col: Color, pat: int, segs: int, cap_col: Color) -> void:
	var k := _kit_at(base)
	k.pat = pat
	k.scale = 1.0
	k.cyl(base, base + Vector3(0, h, 0), r, r * 0.92, col, segs)
	if cap_col.a > 0.0:
		k.box(base + Vector3(0, 0.25, 0), Vector3(r * 2.6, 0.5, r * 2.6), cap_col)
		k.box(base + Vector3(0, h - 0.25, 0), Vector3(r * 2.6, 0.5, r * 2.6), cap_col)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = base + Vector3(0, h * 0.5, 0)
	_body.add_child(cs)
	_boxes.append({"xf": Transform3D(Basis.IDENTITY, base + Vector3(0, h * 0.5, 0)), "h": Vector3(r, h * 0.5, r)})


# --- decoration (no collision) -------------------------------------------------------------

func deco(c: Vector3, s: Vector3, col: Color, glow := false, yaw := 0.0, pat := P_PLAIN) -> void:
	for p in ([[c, yaw], [_mp(c), yaw + PI]] if mirror else [[c, yaw]]):
		var k := _kit_at(p[0])
		k.pat = pat
		k.scale = 1.0
		k.box(p[0], s, col, glow, p[1])


## A glowing strip along the floor or a wall, from a to b.
func strip(a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := b - a
	var yaw := atan2(d.x, d.z)
	deco((a + b) * 0.5, Vector3(w, 0.06, d.length()), col, true, yaw)


## Calls fn(kit, transform) for custom decoration at `at` (and its mirror image): fn draws
## with the kit around the origin, `xf` places it.
func custom(at: Vector3, yaw: float, fn: Callable) -> void:
	for p in ([[at, yaw], [_mp(at), yaw + PI]] if mirror else [[at, yaw]]):
		var k := _kit_at(p[0])
		k.pat = P_PLAIN
		k.scale = 1.0
		k.xf = Transform3D(Basis(Vector3.UP, p[1]), p[0])
		fn.call(k)
		k.xf = Transform3D.IDENTITY


## A floating, slowly turning hedron (Zendikar's stone octahedra), no collision.
func hedron(c: Vector3, size: float, col: Color, glow_col: Color, spin := 0.2) -> void:
	for p in ([c, _mp(c)] if mirror else [c]):
		var k := MeshKit.new()
		k.cyl(Vector3(0, -size, 0), Vector3(0, 0, 0), 0.0, size * 0.42, col, 4, false, false, false)
		k.cyl(Vector3(0, 0, 0), Vector3(0, size, 0), size * 0.42, 0.0, col, 4, false, false, false)
		k.ring(Vector3.ZERO, Vector3.UP, size * 0.42, size * 0.05, glow_col, 4, 3, true)
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.position = p
		mi.rotation.y = p.x * 0.7
		mi.set_meta("spin", spin)
		add_child(mi)
		spinners.append(mi)


## A light. Few of them per arena: the browser renderer pays for each.
func light(pos: Vector3, col: Color, energy := 2.0, range := 14.0) -> void:
	for p in ([pos, _mp(pos)] if mirror else [pos]):
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = col
		l.light_energy = energy
		l.omni_range = range
		l.omni_attenuation = 1.2
		add_child(l)
		omni.append(l)


## A brazier or lamp: a glowing bowl with a light above it.
func torch(pos: Vector3, col: Color, lit := true) -> void:
	custom(pos, 0.0, func(k: MeshKit):
		k.cyl(Vector3(0, 0, 0), Vector3(0, 1.1, 0), 0.08, 0.06, Color(0.25, 0.22, 0.2), 6)
		k.cyl(Vector3(0, 1.1, 0), Vector3(0, 1.35, 0), 0.12, 0.28, Color(0.35, 0.28, 0.2), 8)
		k.sphere(Vector3(0, 1.45, 0), Vector3(0.2, 0.25, 0.2), col, 6, 4, true))
	if lit:
		light(pos + Vector3(0, 2.0, 0), col, 1.6, 11.0)


## Deadly lava (or acid, oil fire): a glowing surface; touching it kills.
func lava(x0: float, z0: float, x1: float, z1: float, y: float, col: Color) -> void:
	for r in ([[x0, z0, x1, z1], [-x1, -z1, -x0, -z0]] if mirror else [[x0, z0, x1, z1]]):
		var c := Vector3((r[0] + r[2]) * 0.5, y, (r[1] + r[3]) * 0.5)
		var s := Vector3(absf(r[2] - r[0]), 0.1, absf(r[3] - r[1]))
		var nx := maxi(1, ceili(s.x / CHUNK))
		var nz := maxi(1, ceili(s.z / CHUNK))
		for i in nx:
			for j in nz:
				var ps := Vector3(s.x / nx, 0.1, s.z / nz)
				var pc := c + Vector3(-s.x * 0.5 + ps.x * (i + 0.5), 0, -s.z * 0.5 + ps.z * (j + 0.5))
				_kit_at(pc).box(pc, ps, col, true)
		hazards.append(AABB(Vector3(minf(r[0], r[2]), y - 3.0, minf(r[1], r[3])), Vector3(s.x, 3.4, s.z)))


# --- gameplay things -----------------------------------------------------------------------

## A jump pad at `pos` that throws whoever steps on it to `target`, `apex` metres above the higher end.
func pad(pos: Vector3, target: Vector3, apex := 3.0) -> void:
	for p in ([[pos, target], [_mp(pos), _mp(target)]] if mirror else [[pos, target]]):
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var top := maxf(a.y, b.y) + apex
		var g := Data.GRAVITY
		var vy := sqrt(2.0 * g * (top - a.y))
		var t := vy / g + sqrt(2.0 * (top - b.y) / g)
		var flat := Vector3(b.x - a.x, 0, b.z - a.z) / t
		pads.append({"pos": a, "vel": flat + Vector3(0, vy, 0), "target": b})
		var mi := MeshInstance3D.new()
		mi.mesh = Models.jump_pad()
		mi.position = a
		add_child(mi)


## A portal at `pos` (facing `face`) that sends whoever walks in to `dest`, looking along `yaw`.
func tele(pos: Vector3, face: float, dest: Vector3, yaw: float, col := Color(0.6, 0.35, 1.0)) -> void:
	for p in ([[pos, face, dest, yaw], [_mp(pos), face + PI, _mp(dest), yaw + PI]] if mirror else [[pos, face, dest, yaw]]):
		teles.append({"pos": p[0], "dest": p[2], "yaw": p[3]})
		var mi := MeshInstance3D.new()
		mi.mesh = Models.portal()
		mi.position = p[0]
		mi.rotation.y = p[1]
		add_child(mi)
		var disc := MeshInstance3D.new()
		disc.mesh = Models.portal_disc(Color(col, 0.55))
		mi.add_child(disc)
		portal_discs.append(disc)


func item(kind: String, pos: Vector3) -> void:
	items.append({"kind": kind, "pos": pos})
	if mirror:
		items.append({"kind": kind, "pos": _mp(pos)})


func weapon(w: String, pos: Vector3) -> void:
	item("w:" + w, pos)


## A spawn point; team -1 is for anyone (and is used for Deathmatch on team maps).
func spawn(pos: Vector3, yaw: float, team := -1) -> void:
	spawns.append({"pos": pos, "yaw": yaw, "team": team})
	if mirror:
		spawns.append({"pos": _mp(pos), "yaw": yaw + PI, "team": 1 - team if team >= 0 else -1})


## Where a team's flag stands (team 0 red; with mirror on, blue gets the mirrored spot).
func flag(team: int, pos: Vector3) -> void:
	flags[team] = pos
	if mirror:
		flags[1 - team] = _mp(pos)


# --- meshes, sky, navigation ---------------------------------------------------------------

func _kit_at(p: Vector3) -> MeshKit:
	var key := Vector3i(floori(p.x / CHUNK), floori(p.y / 12.0), floori(p.z / CHUNK))
	if not _kits.has(key):
		_kits[key] = MeshKit.new()
	return _kits[key]


func _commit_meshes() -> void:
	for key in _kits:
		var mi := MeshInstance3D.new()
		mi.mesh = _kits[key].commit(null, [Game.mat_world, Game.mat_glow, Game.mat_gloss])
		mi.name = "Geo"
		add_child(mi)
	_kits.clear()


func _build_env() -> void:
	var th: Dictionary = def.theme
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = th.ambient
	env.ambient_light_energy = th.get("ambient_energy", 1.0)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = th.fog
	env.fog_density = th.get("fog_density", 0.008)
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.5)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-th.sun_elev, th.sun_az, 0)
	sun.light_color = th.sun
	sun.light_energy = th.sun_energy
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_blur = 1.2
	add_child(sun)
	sm.set_shader_parameter("top_color", th.sky_top)
	sm.set_shader_parameter("horizon_color", th.sky_horizon)
	sm.set_shader_parameter("ground_color", th.sky_ground)
	sm.set_shader_parameter("stars", th.get("stars", 0.0))
	sm.set_shader_parameter("aurora", th.get("aurora", Vector4.ZERO))
	sm.set_shader_parameter("shattered", 0.0)
	if th.get("sun_disc", 1.0) > 0.0:
		sm.set_shader_parameter("sun_dir", sun.transform.basis.z)
		sm.set_shader_parameter("sun_color", th.sun)
		sm.set_shader_parameter("sun_disc", th.get("sun_disc", 1.0))
	else:
		sm.set_shader_parameter("sun_color", Color(0, 0, 0))
		sm.set_shader_parameter("sun_disc", 0.0)
	if th.has("moon"):
		sm.set_shader_parameter("moon_color", th.moon)
		sm.set_shader_parameter("moon_dir", th.get("moon_dir", Vector3(0.3, 0.45, -1.0)))
	else:
		sm.set_shader_parameter("moon_color", Color(0, 0, 0))
	Game.set_sky(th.sky_top, th.sky_horizon, th.sky_ground)


func apply_quality() -> void:
	var q := Game.quality
	sun.shadow_enabled = q == Game.HIGH or (q == Game.MEDIUM and not Game.web)
	env.glow_enabled = q != Game.LOW
	env.fog_enabled = q != Game.LOW
	Game.mat_world.set_shader_parameter("detail", 1.0 if q != Game.LOW else 0.0)
	for l in omni:
		l.visible = q != Game.LOW


func _bake_nav() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_height = 2.0
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	for p in pads:
		_link(p.pos, p.target)
	for t in teles:
		_link(t.pos + Vector3(0, 0.1, 0), t.dest)
	_ledge_links()


func _link(a: Vector3, b: Vector3) -> void:
	var l := NavigationLink3D.new()
	l.bidirectional = false
	l.start_position = a
	l.end_position = b
	add_child(l)
	_links += 1


## Links from the edges of raised floors down to whatever is below, so bots know they can drop.
func _ledge_links() -> void:
	for bx in _boxes:
		var xf: Transform3D = bx.xf
		var h: Vector3 = bx.h
		if h.x < 1.2 or h.z < 1.2 or absf(xf.basis.y.y) < 0.99:
			continue
		var top: float = xf.origin.y + h.y
		for side in 4:
			var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
			var out := Vector3(0, 0, 1 if side == 0 else -1) if side < 2 else Vector3(1 if side == 2 else -1, 0, 0)
			var half_len: float = h.x if side < 2 else h.z
			var depth: float = h.z if side < 2 else h.x
			var n := int(half_len * 2.0 / 5.0)
			for i in range(n):
				var u := -half_len + (i + 0.5) * half_len * 2.0 / n
				var edge_l := along * u + out * depth
				var edge := xf * Vector3(edge_l.x, h.y, edge_l.z)
				var o := xf.basis * out
				var takeoff := edge - o * 0.8
				var land_xz := edge + o * 1.1
				var land_y := _floor_below(land_xz, top - 0.5)
				if land_y < -1e8 or top - land_y < 1.4 or top - land_y > 16.0:
					continue
				if _blocked(takeoff + Vector3(0, 0.3, 0), 1.6) or _blocked(Vector3(land_xz.x, land_y + 0.3, land_xz.z), top - land_y + 1.0):
					continue
				# nothing (a battlement, a rail) in the way of walking off the edge
				var clear := true
				for k in 4:
					var at := takeoff.lerp(edge + o * 0.5, (k + 1) / 4.0)
					if _blocked(Vector3(at.x, top + 0.2, at.z), 1.4):
						clear = false
				if not clear:
					continue
				var land := Vector3(land_xz.x, land_y, land_xz.z) + o * 0.6
				_link(Vector3(takeoff.x, top, takeoff.z), land)


## The highest solid top under (x, z) below `below`, or -1e9.
func _floor_below(p: Vector3, below: float) -> float:
	var best := -1e9
	for bx in _boxes:
		var xf: Transform3D = bx.xf
		var h: Vector3 = bx.h
		var l := xf.affine_inverse() * Vector3(p.x, below, p.z)
		if absf(l.x) > h.x or absf(l.z) > h.z:
			continue
		var t := 0.0
		if absf(xf.basis.y.y) > 0.99:
			t = xf.origin.y + h.y
		else:
			# a ramp: height of its top surface at this point
			var n := xf.basis.y.normalized()
			var top_c := xf.origin + n * h.y
			t = top_c.y - (n.x * (p.x - top_c.x) + n.z * (p.z - top_c.z)) / maxf(n.y, 0.2)
		if t < below and t > best:
			best = t
	var lava_y := -1e9
	for hz in hazards:
		if p.x > hz.position.x and p.x < hz.end.x and p.z > hz.position.z and p.z < hz.end.z:
			lava_y = maxf(lava_y, hz.end.y)
	if lava_y > best:
		return -1e9
	return best


## True if a vertical segment from p up `h` metres is inside a solid.
func _blocked(p: Vector3, h: float) -> bool:
	for bx in _boxes:
		var xf: Transform3D = bx.xf
		var hh: Vector3 = bx.h
		for k in 3:
			var l := xf.affine_inverse() * (p + Vector3(0, h * k / 2.0, 0))
			if absf(l.x) < hh.x + 0.3 and absf(l.y) < hh.y and absf(l.z) < hh.z + 0.3:
				return true
	return false


func link_count() -> int:
	return _links


func _process(dt: float) -> void:
	for s in spinners:
		s.rotation.y += dt * float(s.get_meta("spin"))
		s.position.y += sin(Time.get_ticks_msec() * 0.001 + s.position.x) * dt * 0.15
	var t := Time.get_ticks_msec() * 0.001
	for d in portal_discs:
		d.rotation.z = t * 0.7
