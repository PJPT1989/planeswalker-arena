class_name Hud
extends Control
## The heads-up display, drawn in one `_draw`: crosshair and hit marker, health, armour, the
## weapon bar with ammo, power-up timers, the clock and the score (flags in CTF), the kill feed,
## big centre messages, arrows towards whoever hurt you, the scoreboard (Tab) and the results.

var mt: Match
var hit_mark := 0.0
var _hurt := []          # [angle (world yaw towards the attacker), time left]
var _center := ["", Color.WHITE, 0.0]
var _pickup := ["", Color.WHITE, 0.0]
var _results := false
var _flash := 0.0        # red edge when hurt


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	hit_mark = maxf(0.0, hit_mark - dt)
	_flash = maxf(0.0, _flash - dt * 2.0)
	_center[2] = maxf(0.0, _center[2] - dt)
	_pickup[2] = maxf(0.0, _pickup[2] - dt)
	for h in _hurt:
		h[1] -= dt
	_hurt = _hurt.filter(func(h): return h[1] > 0.0)


func on_hurt(attacker: int, amount: int) -> void:
	_flash = clampf(0.25 + amount * 0.012, 0.0, 0.8)
	if attacker < 0 or attacker >= mt.fighters.size() or attacker == mt.me:
		return
	var d: Vector3 = mt.fighters[attacker].global_position - mt.fighters[mt.me].global_position
	_hurt.append([atan2(-d.x, -d.z), 1.4])


func pickup_msg(kind: String) -> void:
	if kind.begins_with("w:"):
		var w: Dictionary = Data.WEAPONS[kind.substr(2)]
		_pickup = [w.name, w.color, 2.0]
	else:
		var it: Dictionary = Data.ITEMS[kind]
		_pickup = [it.name, it.color, 2.0]


func center_msg(text: String, col: Color) -> void:
	_center = [text, col, 2.6]


func show_results() -> void:
	_results = true


func _draw() -> void:
	if mt == null or mt.me < 0:
		return
	var sz := get_viewport_rect().size
	var k := clampf(sz.y / 900.0, 0.7, 1.6)
	var f: Fighter = mt.fighters[mt.me]
	var ft: Font = Game.font_title_bold
	var fb: Font = Game.font_bold
	if _flash > 0.0:
		_edge_glow(sz, Color(0.8, 0.05, 0.02, _flash * 0.55))
	if f.power("overload"):
		_edge_glow(sz, Color(0.7, 0.2, 1.0, 0.18))
	if _results or mt.over:
		_scoreboard(sz, k, true)
		return
	if f.alive:
		_crosshair(sz * 0.5, k, f)
		_hurt_arrows(sz * 0.5, k, f)
	_vitals(sz, k, f)
	_weapon_bar(sz, k, f)
	_top(sz, k, f)
	_kill_feed(sz, k)
	_powers(sz, k, f)
	var mid := Vector2(sz.x * 0.5, sz.y * 0.3)
	if mt.warmup > 0.0:
		_text_c(ft, mid, "Get ready", 40 * k, Game.GOLD)
		_text_c(ft, mid + Vector2(0, 56 * k), str(ceili(mt.warmup)), 54 * k, Color.WHITE)
	elif _center[2] > 0.0:
		var c: Color = _center[1]
		c.a = clampf(_center[2] * 1.5, 0.0, 1.0)
		_text_c(ft, mid, _center[0], 34 * k, c)
	if _pickup[2] > 0.0:
		var c: Color = _pickup[1]
		c.a = clampf(_pickup[2] * 1.5, 0.0, 1.0)
		_text_c(fb, Vector2(sz.x * 0.5, sz.y - 128 * k), _pickup[0], 22 * k, c)
	if not f.alive:
		var msg := "Click to return to the arena" if f.dead_t > Data.RESPAWN_DELAY else "Your spark gutters..."
		_text_c(fb, Vector2(sz.x * 0.5, sz.y * 0.62), msg, 24 * k, Game.PALE)
	if f.carrying >= 0:
		_text_c(fb, Vector2(sz.x * 0.5, sz.y * 0.68), "You have the %s banner! Bring it home." % Data.TEAM_NAMES[f.carrying], 22 * k, Data.team_color(f.carrying))
	if Input.is_action_pressed("scores"):
		_scoreboard(sz, k, false)


# --- pieces -------------------------------------------------------------------------------

func _crosshair(c: Vector2, k: float, f: Fighter) -> void:
	var col := Color(1, 1, 1, 0.9)
	if f.zoom and f.weapon == "disintegrate":
		# a scope: rings and a fine cross
		draw_arc(c, 120 * k, 0, TAU, 64, Color(0, 0, 0, 0.6), 3.0 * k)
		draw_arc(c, 6 * k, 0, TAU, 16, Color(0.6, 1.0, 0.8, 0.9), 1.5)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 12 * k, c + d * 110 * k, Color(0.6, 1.0, 0.8, 0.8), 1.0)
	else:
		var g := 5.0 * k
		var l := 7.0 * k
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * (g + 1), c + d * (g + l + 1), Color(0, 0, 0, 0.6), 4.0)
			draw_line(c + d * g, c + d * (g + l), col, 2.0)
		draw_rect(Rect2(c - Vector2.ONE, Vector2.ONE * 2), col)
	if hit_mark > 0.0:
		var a := hit_mark / 0.25
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 6 * k, c + d * 14 * k, Color(1.0, 0.35, 0.25, a), 2.5)


func _hurt_arrows(c: Vector2, k: float, f: Fighter) -> void:
	for h in _hurt:
		var rel: float = wrapf(float(h[0]) - f.yaw, -PI, PI)
		# screen angle: 0 = up (in front), clockwise to the right
		var ang := -rel
		var dir := Vector2(sin(ang), -cos(ang))
		var p := c + dir * 90 * k
		var side := Vector2(-dir.y, dir.x)
		var a := clampf(float(h[1]), 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([p + dir * 22 * k, p + side * 14 * k, p - side * 14 * k]), Color(1.0, 0.2, 0.1, 0.75 * a))


func _vitals(sz: Vector2, k: float, f: Fighter) -> void:
	var ft: Font = Game.font_title_bold
	var x := 28 * k
	var y := sz.y - 34 * k
	# health: a heart-red gem, the number, a bar
	_gem(Vector2(x + 14 * k, y - 16 * k), 14 * k, Color(0.9, 0.2, 0.18))
	var hc := Game.PALE if f.health > 25 else Game.BAD
	if f.health > 100:
		hc = Color(0.5, 0.75, 1.0)
	draw_string(ft, Vector2(x + 36 * k, y), str(maxi(f.health, 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * k), hc)
	_bar(Rect2(x, y + 8 * k, 150 * k, 6 * k), clampf(f.health / 100.0, 0.0, 1.0), Color(0.9, 0.25, 0.2))
	# armour: a gold shield
	var ax := x + 180 * k
	_shield(Vector2(ax + 14 * k, y - 16 * k), 14 * k, Color(0.95, 0.78, 0.35))
	draw_string(ft, Vector2(ax + 36 * k, y), str(f.armor), HORIZONTAL_ALIGNMENT_LEFT, -1, int(40 * k), Game.PALE if f.armor > 0 else Color(0.6, 0.58, 0.55))
	_bar(Rect2(ax, y + 8 * k, 150 * k, 6 * k), clampf(f.armor / 100.0, 0.0, 1.0), Color(0.95, 0.78, 0.35))


func _weapon_bar(sz: Vector2, k: float, f: Fighter) -> void:
	var fb: Font = Game.font_bold
	var n := Data.WEAPON_ORDER.size()
	var w := 64.0 * k
	var gap := 6.0 * k
	var x0 := sz.x * 0.5 - (n * w + (n - 1) * gap) * 0.5
	var y := sz.y - 70 * k
	for i in n:
		var wid: String = Data.WEAPON_ORDER[i]
		var r := Rect2(x0 + i * (w + gap), y, w, 46 * k)
		var have := f.weapons.has(wid)
		var cur := wid == f.weapon
		var col: Color = Data.WEAPONS[wid].color
		draw_rect(r, Color(0.05, 0.05, 0.07, 0.75 if cur else 0.45))
		if cur:
			draw_rect(r, col, false, 2.0)
		if not have:
			draw_string(fb, r.position + Vector2(5 * k, 14 * k), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), Color(1, 1, 1, 0.25))
			continue
		var ammo := int(f.weapons[wid])
		var dim := 1.0 if ammo != 0 else 0.35
		_weapon_icon(wid, r.get_center() + Vector2(0, -4 * k), k, Color(col, dim))
		draw_string(fb, r.position + Vector2(5 * k, 14 * k), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), Color(1, 1, 1, 0.6))
		if ammo >= 0:
			draw_string(fb, Vector2(r.position.x, r.end.y - 4 * k), str(ammo), HORIZONTAL_ALIGNMENT_CENTER, w, int(14 * k), Color(Game.PALE, dim))
	# the current weapon's name and ammo, big, on the right
	var ft: Font = Game.font_title_bold
	var cw: Dictionary = Data.WEAPONS[f.weapon]
	var ammo_now := int(f.weapons.get(f.weapon, 0))
	var rx := sz.x - 28 * k
	if ammo_now >= 0:
		draw_string(ft, Vector2(rx - 200 * k, sz.y - 34 * k), str(ammo_now), HORIZONTAL_ALIGNMENT_RIGHT, 200 * k, int(40 * k), Game.PALE if ammo_now > 0 else Game.BAD)
	draw_string(fb, Vector2(rx - 300 * k, sz.y - 78 * k), cw.name, HORIZONTAL_ALIGNMENT_RIGHT, 300 * k, int(18 * k), cw.color)


func _top(sz: Vector2, k: float, f: Fighter) -> void:
	var ft: Font = Game.font_title_bold
	var fb: Font = Game.font_bold
	var c := Vector2(sz.x * 0.5, 40 * k)
	var t := maxi(0, ceili(mt.time_left))
	_text_c(ft, c, "%d:%02d" % [t / 60, t % 60], 26 * k, Game.PALE if t > 30 else Game.BAD)
	if mt.teams:
		for team in 2:
			var s := -1 if team == 0 else 1
			var r := Rect2(c.x + s * 46 * k - 34 * k + (0 if team == 0 else 0), c.y - 26 * k, 68 * k, 40 * k)
			r.position.x = c.x - 34 * k + s * 88 * k
			var col := Data.team_color(team)
			draw_rect(r, Color(col.darkened(0.6), 0.75))
			draw_rect(r, Color(col, 0.9 if f.team == team else 0.4), false, 2.0)
			draw_string(ft, Vector2(r.position.x, r.end.y - 9 * k), str(mt.team_score[team]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(26 * k), Color.WHITE)
			if mt.mode == Data.CTF and mt.flags.size() == 2:
				var fl: Dictionary = mt.flags[team]
				var fp := Vector2(r.get_center().x, r.end.y + 16 * k)
				var state := str(fl.state)
				_flag_icon(fp, k, col, state)
				var label: String = {"home": "Home", "carried": "Taken", "dropped": "Dropped"}.get(state, "")
				_text_c(fb, fp + Vector2(0, 22 * k), label, 12 * k, Color(1, 1, 1, 0.75))
		_text_c(fb, c + Vector2(0, 24 * k), "Limit %d" % mt.limit, 13 * k, Color(1, 1, 1, 0.5))
	else:
		var st := mt.standings()
		var place := 1
		for i in st.size():
			if st[i].id == mt.me:
				place = i + 1
		var mine: int = mt.scores[mt.me].frags
		var lead: int = st[0].frags if st[0].id != mt.me else (st[1].frags if st.size() > 1 else 0)
		var ahead := mine - lead
		var txt := "%d frags   %s of %d   (%s%d)" % [mine, _ord(place), st.size(), "+" if ahead >= 0 else "", ahead]
		_text_c(fb, c + Vector2(0, 28 * k), txt, 17 * k, Game.GOLD if place == 1 else Game.PALE)
		_text_c(fb, c + Vector2(0, 48 * k), "Frag limit %d" % mt.limit, 13 * k, Color(1, 1, 1, 0.5))


func _kill_feed(sz: Vector2, k: float) -> void:
	var fb: Font = Game.font_bold
	var y := 30 * k
	for line in mt.feed:
		var a := clampf(7.0 - float(line[2]), 0.0, 1.0)
		var col: Color = line[1]
		col.a = a
		var w := fb.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k)).x
		draw_rect(Rect2(sz.x - w - 34 * k, y - 17 * k, w + 16 * k, 23 * k), Color(0, 0, 0, 0.4 * a))
		draw_string(fb, Vector2(sz.x - w - 26 * k, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), col)
		y += 26 * k


func _powers(sz: Vector2, k: float, f: Fighter) -> void:
	var fb: Font = Game.font_bold
	var y := sz.y - 120 * k
	for p in f.powers:
		var left := float(f.powers[p])
		if left <= 0.0:
			continue
		var it: Dictionary = Data.ITEMS[p]
		_gem(Vector2(40 * k, y), 11 * k, it.color)
		draw_string(fb, Vector2(60 * k, y + 7 * k), "%s  %d" % [it.name, ceili(left)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), it.color)
		y -= 30 * k


func _scoreboard(sz: Vector2, k: float, final: bool) -> void:
	var ft: Font = Game.font_title_bold
	var fb: Font = Game.font_bold
	var st := mt.standings()
	var w := 640.0 * k
	var row := 30.0 * k
	var h := 150 * k + row * st.size()
	var r := Rect2(sz.x * 0.5 - w * 0.5, maxf(20 * k, sz.y * 0.5 - h * 0.5 - 20 * k), w, h)
	draw_rect(r, Color(0.04, 0.04, 0.06, 0.88))
	draw_rect(r, Color(Ui.EDGE, 0.7), false, 2.0)
	var title := "%s - %s" % [Data.MODES[mt.mode].name, mt.map_def.name]
	if final:
		title = _winner_text()
	_text_c(ft, Vector2(sz.x * 0.5, r.position.y + 46 * k), title, 30 * k, Game.GOLD)
	if mt.teams:
		_text_c(fb, Vector2(sz.x * 0.5, r.position.y + 76 * k), "Red %d  -  %d Blue" % [mt.team_score[0], mt.team_score[1]], 20 * k, Game.PALE)
	var y := r.position.y + 112 * k
	var cols := [r.position.x + 30 * k, r.end.x - 250 * k, r.end.x - 170 * k, r.end.x - 90 * k]
	draw_string(fb, Vector2(cols[0], y), "Planeswalker", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.5))
	draw_string(fb, Vector2(cols[1], y), "Frags", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.5))
	draw_string(fb, Vector2(cols[2], y), "Deaths", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.5))
	if mt.mode == Data.CTF:
		draw_string(fb, Vector2(cols[3], y), "Caps", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), Color(1, 1, 1, 0.5))
	for s in st:
		y += row
		var col := Game.PALE
		if mt.teams:
			col = Data.team_color(int(s.team)).lightened(0.35)
		if s.id == mt.me:
			draw_rect(Rect2(r.position.x + 12 * k, y - 21 * k, w - 24 * k, row - 2), Color(1, 1, 1, 0.08))
		var name := str(s.name) + ("  (bot)" if s.bot else "")
		draw_string(fb, Vector2(cols[0], y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), col)
		draw_string(fb, Vector2(cols[1], y), str(s.frags), HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), col)
		draw_string(fb, Vector2(cols[2], y), str(s.deaths), HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), col)
		if mt.mode == Data.CTF:
			draw_string(fb, Vector2(cols[3], y), str(s.caps), HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), col)
	if final:
		_text_c(fb, Vector2(sz.x * 0.5, r.end.y - 16 * k), "The arena resets in a few seconds...", 15 * k, Color(1, 1, 1, 0.55))


func _winner_text() -> String:
	var w := mt.winner
	if mt.teams:
		var t := int(w.get("team", -1))
		if t < 0:
			return "A draw"
		return "%s team wins!" % Data.TEAM_NAMES[t]
	var fi := int(w.get("f", -1))
	if fi < 0:
		return "A draw"
	if fi == mt.me:
		return "You win!"
	return "%s wins!" % mt.fighters[fi].display_name()


# --- drawing helpers ------------------------------------------------------------------------

func _text_c(font: Font, c: Vector2, text: String, fsize: float, col: Color) -> void:
	var s := int(fsize)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(font, Vector2(c.x - w * 0.5 + 2, c.y + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color(0, 0, 0, col.a * 0.7))
	draw_string(font, Vector2(c.x - w * 0.5, c.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), col)


func _edge_glow(sz: Vector2, col: Color) -> void:
	var t := sz.y * 0.08
	var clear := Color(col, 0.0)
	for e in [[Vector2.ZERO, Vector2(sz.x, 0), Vector2(sz.x, t), Vector2(0, t)],
			[Vector2(0, sz.y), Vector2(sz.x, sz.y), Vector2(sz.x, sz.y - t), Vector2(0, sz.y - t)],
			[Vector2.ZERO, Vector2(0, sz.y), Vector2(t, sz.y), Vector2(t, 0)],
			[Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(sz.x - t, sz.y), Vector2(sz.x - t, 0)]]:
		draw_polygon(PackedVector2Array(e), PackedColorArray([col, col, clear, clear]))


func _gem(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], c]), col.lightened(0.35))


func _shield(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-r * 0.85, -r), c + Vector2(r * 0.85, -r), c + Vector2(r * 0.8, r * 0.1), c + Vector2(0, r * 1.05), c + Vector2(-r * 0.8, r * 0.1)])
	draw_colored_polygon(pts, col)
	draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.8), col.darkened(0.4), 2.0)


func _flag_icon(c: Vector2, k: float, col: Color, state: String) -> void:
	var a := 1.0 if state == "home" else (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))
	draw_line(c + Vector2(-7 * k, -10 * k), c + Vector2(-7 * k, 10 * k), Color(0.9, 0.85, 0.7, a), 2.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6 * k, -10 * k), c + Vector2(9 * k, -5 * k), c + Vector2(-6 * k, 0)]), Color(col, a))


## Small shapes for the weapon bar.
func _weapon_icon(w: String, c: Vector2, k: float, col: Color) -> void:
	match w:
		"blade":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 6) * k, c + Vector2(12, -8) * k, c + Vector2(14, -6) * k, c + Vector2(-12, 8) * k]), col)
			draw_line(c + Vector2(-10, 0) * k, c + Vector2(-6, 8) * k, col.darkened(0.3), 3.0)
		"repeater":
			draw_rect(Rect2(c + Vector2(-14, -4) * k, Vector2(24, 7) * k), col)
			draw_rect(Rect2(c + Vector2(-8, 2) * k, Vector2(5, 7) * k), col.darkened(0.3))
			for i in 3:
				draw_circle(c + Vector2(12 + i * 3, -1) * k, 1.4 * k, col.lightened(0.4))
		"thunder":
			draw_rect(Rect2(c + Vector2(-14, -5) * k, Vector2(26, 5) * k), col)
			draw_rect(Rect2(c + Vector2(-14, 0) * k, Vector2(26, 4) * k), col.darkened(0.25))
			draw_rect(Rect2(c + Vector2(-16, -3) * k, Vector2(6, 11) * k), col.darkened(0.4))
		"pulse":
			draw_rect(Rect2(c + Vector2(-14, -4) * k, Vector2(20, 8) * k), col.darkened(0.3))
			draw_circle(c + Vector2(9, 0) * k, 5 * k, col)
		"lash":
			for i in 4:
				var a := c + Vector2(-14 + i * 7, (-1 if i % 2 == 0 else 1) * 4) * k
				var b := c + Vector2(-7 + i * 7, (1 if i % 2 == 0 else -1) * 4) * k
				draw_line(a, b, col, 2.5)
		"fireball":
			draw_rect(Rect2(c + Vector2(-14, -5) * k, Vector2(18, 10) * k), col.darkened(0.35))
			draw_circle(c + Vector2(8, 0) * k, 6 * k, col)
			draw_circle(c + Vector2(9, -1) * k, 3 * k, col.lightened(0.5))
		"disintegrate":
			draw_rect(Rect2(c + Vector2(-16, -2) * k, Vector2(32, 4) * k), col)
			draw_rect(Rect2(c + Vector2(-4, -6) * k, Vector2(9, 4) * k), col.darkened(0.3))
			draw_rect(Rect2(c + Vector2(-16, 1) * k, Vector2(7, 6) * k), col.darkened(0.4))


func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
	return "%dth" % n
