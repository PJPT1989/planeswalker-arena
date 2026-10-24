extends Node
## Headless bot matches on every map and mode (run with --fixed-fps so it goes as fast as it
## can): prints frags, captures, how often bots got stuck and how long a step took.
##   godot --headless --fixed-fps 60 --path . -- --simtest [--map=id] [--mode=ffa] [--minutes=3] [--bots=8] [--skill=2]

var _arg := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			_arg[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	var minutes := float(_arg.get("minutes", "3"))
	var only_map := str(_arg.get("map", ""))
	var only_mode := str(_arg.get("mode", ""))
	var bots := int(_arg.get("bots", "8"))
	var skill := int(_arg.get("skill", "2"))
	var total_stuck := 0
	for mp in Maps.LIST:
		if only_map != "" and mp.id != only_map:
			continue
		for mode in mp.modes:
			if only_mode != "" and mode != only_mode:
				continue
			var fl := Net.make_fighters([], bots, skill, mode)
			var m := Match.new()
			add_child(m)
			var t0 := Time.get_ticks_msec()
			m.start({"mode": mode, "map": mp.id, "fighters": fl, "me": -1, "headless": true, "seed": 1234,
				"minutes": minutes, "limit": 999})
			var steps := int(minutes * 60.0 * 60.0)
			var worst := 0
			for i in steps:
				var s0 := Time.get_ticks_usec()
				await get_tree().physics_frame
				worst = maxi(worst, Time.get_ticks_usec() - s0)
				if m.over:
					break
				if _arg.has("debug") and i % 1200 == 600:
					for id in m.bots:
						var b: Bot = m.bots[id]
						print("  t=%d %s at %s goal %s %s path %d/%d next %s alive %s" % [i / 60, b.f.display_name(), str(b.f.global_position.snapped(Vector3.ONE * 0.1)), b.goal_kind, str(b.goal.snapped(Vector3.ONE)), b.path_i, b.path.size(), str(b.path[b.path_i].snapped(Vector3.ONE * 0.1)) if b.path_i < b.path.size() else "-", b.f.alive])
			var st := m.standings()
			var line := "SIM %s %s: %.0fs real, links %d, shots %d, stuck %d, scores %s" % [mp.id, mode,
				(Time.get_ticks_msec() - t0) / 1000.0, m.arena.link_count(), m.stats.shots, m.stats.stuck, str(m.team_score)]
			var fr := []
			for s in st:
				fr.append("%s %d/%d%s" % [s.name, s.frags, s.deaths, ("/c%d" % s.caps) if mode == "ctf" else ""])
			print(line)
			var never := []
			for i in m.arena.items.size():
				if not m.stats.picked.has(i):
					never.append("%s@%s" % [m.arena.items[i].kind, str(m.arena.items[i].pos)])
			print("    self-kills %s; never picked: %s" % [str(m.stats.self), ", ".join(never)])
			print("    ", ", ".join(fr))
			total_stuck += m.stats.stuck
			m.queue_free()
			await get_tree().process_frame
	print("SIM done, stuck total %d" % total_stuck)
	get_tree().quit()
