class_name Fx
extends MeshInstance3D
## Short-lived effects, all drawn into one ImmediateMesh each frame (one draw call): beams and
## tracers, sparks, muzzle flashes and explosion flashes, as quads that face the camera.
## Explosions also borrow one of a few pooled lights.

var cam: Camera3D
var _im := ImmediateMesh.new()
var _beams := []      # [a, b, col, width, t, life, jitter]
var _sparks := []     # [pos, vel, col, t, life, size, gravity]
var _flashes := []    # [pos, col, size, t, life]
var _lights: Array[OmniLight3D] = []
var _light_at := 0
var _light_t := []


func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	for i in 3:
		var l := OmniLight3D.new()
		l.visible = false
		l.omni_range = 10.0
		get_parent().add_child.call_deferred(l)
		_lights.append(l)
		_light_t.append(0.0)


func beam(a: Vector3, b: Vector3, col: Color, width := 0.06, life := 0.12, jitter := 0.0) -> void:
	_beams.append([a, b, col, width, 0.0, life, jitter])


func sparks(p: Vector3, n: int, col: Color, speed := 6.0, life := 0.45, size := 0.08, gravity := 9.0) -> void:
	if Game.quality == Game.LOW:
		n = n / 2
	for i in n:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		_sparks.append([p, d * speed * randf_range(0.4, 1.0), col, 0.0, life * randf_range(0.6, 1.2), size, gravity])


func flash(p: Vector3, col: Color, size := 0.5, life := 0.06) -> void:
	_flashes.append([p, col, size, 0.0, life])


func explosion(p: Vector3, col: Color, radius: float) -> void:
	flash(p, col, radius * 0.9, 0.35)
	flash(p, Color(1, 1, 0.9), radius * 0.45, 0.18)
	sparks(p, 24, col, radius * 3.0, 0.6, 0.12, 6.0)
	sparks(p, 10, Color(1, 0.95, 0.7), radius * 4.0, 0.3, 0.08, 2.0)
	light_flash(p, col, radius * 3.5)


func light_flash(p: Vector3, col: Color, range := 10.0, life := 0.25) -> void:
	if Game.quality == Game.LOW or _lights.is_empty():
		return
	var l := _lights[_light_at]
	_light_t[_light_at] = life
	_light_at = (_light_at + 1) % _lights.size()
	l.global_position = p
	l.light_color = col
	l.omni_range = range
	l.light_energy = 4.0
	l.visible = true


func _process(dt: float) -> void:
	for i in _lights.size():
		if _light_t[i] > 0.0:
			_light_t[i] -= dt
			_lights[i].light_energy = maxf(0.0, _light_t[i] * 16.0)
			if _light_t[i] <= 0.0:
				_lights[i].visible = false
	_im.clear_surfaces()
	if cam == null or not is_instance_valid(cam):
		return
	var cp := cam.global_position
	var cup := cam.global_transform.basis.y
	var cright := cam.global_transform.basis.x
	var any := false
	var keep := []
	for b in _beams:
		b[4] += dt
		if b[4] < b[5]:
			keep.append(b)
	_beams = keep
	keep = []
	for s in _sparks:
		s[3] += dt
		s[1].y -= s[6] * dt
		s[0] += s[1] * dt
		if s[3] < s[4]:
			keep.append(s)
	_sparks = keep
	keep = []
	for f in _flashes:
		f[3] += dt
		if f[3] < f[4]:
			keep.append(f)
	_flashes = keep
	if _beams.is_empty() and _sparks.is_empty() and _flashes.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, Game.mat_fx)
	for b in _beams:
		var fade: float = 1.0 - b[4] / b[5]
		var col: Color = b[2]
		col.a = fade
		var jit: float = b[6]
		if jit > 0.0:
			# a crackling bolt: a few kinked segments that change every frame
			var a: Vector3 = b[0]
			var e: Vector3 = b[1]
			var n := 8
			var prev := a
			for k in range(1, n + 1):
				var p := a.lerp(e, float(k) / n)
				if k < n:
					p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jit
				_quad_line(prev, p, b[3], col, cp)
				prev = p
		else:
			_quad_line(b[0], b[1], b[3] * (0.6 + 0.4 * fade), col, cp)
	for s in _sparks:
		var col: Color = s[2]
		col.a = 1.0 - s[3] / s[4]
		var tail: Vector3 = s[0] - s[1] * 0.03
		_quad_line(tail, s[0], s[5], col, cp)
	for f in _flashes:
		var col: Color = f[1]
		var k: float = f[3] / f[4]
		col.a = 1.0 - k
		var r: float = f[2] * (0.6 + k * 0.8)
		var c: Vector3 = f[0]
		# a soft disc: bright in the middle, clear at the rim
		var rim := Color(col, 0.0)
		var n := 12
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := c + (cright * cos(a0) + cup * sin(a0)) * r
			var p1 := c + (cright * cos(a1) + cup * sin(a1)) * r
			_tri3(c, p0, p1, col, rim, rim)
	_im.surface_end()


func _quad_line(a: Vector3, b: Vector3, w: float, col: Color, cp: Vector3) -> void:
	var d := b - a
	if d.length_squared() < 1e-6:
		return
	var side := d.cross(cp - (a + b) * 0.5).normalized() * w * 0.5
	_tri(a - side, b - side, b + side, col)
	_tri(a - side, b + side, a + side, col)


func _tri3(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_im.surface_set_color(ca)
	_im.surface_add_vertex(a)
	_im.surface_set_color(cb)
	_im.surface_add_vertex(b)
	_im.surface_set_color(cc)
	_im.surface_add_vertex(c)


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_im.surface_set_color(col)
	_im.surface_add_vertex(a)
	_im.surface_set_color(col)
	_im.surface_add_vertex(b)
	_im.surface_set_color(col)
	_im.surface_add_vertex(c)
