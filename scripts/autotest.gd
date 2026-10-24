extends Node
## Automated visual test (`tools/smoke_test.sh`): the menus, the planeswalker picker, a match on
## every arena with the player's fighter driven by a bot, the scoreboard, the pause menu, a death,
## every weapon in the hand, and a finished match with its results. Saves a screenshot of each
## step, prints `AUTOTEST ...` lines and ends with `AUTOTEST done`.

var dir := "/tmp/pa-shots"
var main: Node


func _ready() -> void:
	main = get_parent()
	Game.testing = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(dir)
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("AUTOTEST shot ", name)


func _play(m: Match, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(m) and not m.over:
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	main.show_title()
	await _wait(120)
	await _shot("01_title")
	main.show_play()
	await _wait(5)
	await _shot("02_play")
	main.show_walkers()
	await _wait(20)
	await _shot("03_walkers")
	main.show_options()
	await _wait(5)
	await _shot("04_options")
	main.show_help()
	await _wait(5)
	await _shot("05_help")
	main.show_multiplayer()
	await _wait(5)
	await _shot("06_multiplayer")

	var walkers: Array = Data.WALKER_ORDER
	for i in Maps.LIST.size():
		var mp: Dictionary = Maps.LIST[i]
		var mode: String = mp.modes[i % mp.modes.size()]
		Game.walker = walkers[i % walkers.size()]
		var me := {"name": "Tester", "walker": Game.walker, "team": 0 if Data.MODES[mode].teams else -1, "peer": 1}
		var m: Match = main.start_match({"mode": mode, "map": mp.id, "seed": 50 + i, "me": 0, "autopilot": true,
			"fighters": Net.make_fighters([me], 5, 1, mode)})
		await _play(m, Match.WARMUP + 4.0)
		var p := m.fighters[0]
		print("AUTOTEST map %s %s as %s: frags %d deaths %d, shots %d, stuck %d" % [mp.id, mode, Game.walker, m.scores[0].frags, m.scores[0].deaths, m.stats.shots, m.stats.stuck])
		await _shot("10_%02d_%s_%s" % [i, mp.id, mode])
		if i == 0:
			# every weapon in the hand
			for w in ["thunder", "lash", "fireball", "disintegrate"]:
				if not p.alive:
					m._spawn(p)
					await _wait(2)
				p.health = 999
				p.give_weapon(w)
				p.switch_to(w)
				await _wait(25)
				await _shot("11_weapon_" + w)
			Input.action_press("scores")
			await _wait(3)
			await _shot("12_scores")
			Input.action_release("scores")
			main._show_pause()
			await _wait(5)
			await _shot("13_pause")
			main._resume()
			await _wait(5)
			if not p.alive:
				m._spawn(p)
				await _wait(5)
			p.health = 100
			m.damage(p, 1, 500, "fireball")
			await _wait(60)
			await _shot("14_dead")
			print("AUTOTEST died: alive ", p.alive, ", deaths ", m.scores[0].deaths)
		if i == 5:
			# CTF: hold the enemy banner
			m.flags[1].state = "carried"
			m.flags[1].carrier = 0
			p.carrying = 1
			await _wait(20)
			await _shot("15_ctf_carry")
			m._return_flag(1, -1)
			p.carrying = -1
		if i == Maps.LIST.size() - 1:
			m._end_match()
			await _wait(30)
			await _shot("16_results")
			print("AUTOTEST over: winner ", m.winner)
			var t := 0.0
			while is_instance_valid(main.match_node) and t < 15.0:
				await get_tree().process_frame
				t += get_process_delta_time()
			print("AUTOTEST back to title: ", main.screen != null and main.screen.name == "Title")
			await _wait(30)
			await _shot("17_title_again")
	print("AUTOTEST done")
	get_tree().quit()
