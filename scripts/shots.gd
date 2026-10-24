extends Node
## Screenshots of each map for checking the look: a bot match runs a few seconds, then the
## camera takes fixed views and a view following a bot.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --mapshots=/tmp/pa-maps [--map=id]

var _arg := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			_arg[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	var dir := str(_arg.get("mapshots", "/tmp/pa-maps"))
	DirAccess.make_dir_recursive_absolute(dir)
	for mp in Maps.LIST:
		if _arg.has("map") and mp.id != _arg.map:
			continue
		var mode: String = mp.modes[0]
		var m := Match.new()
		add_child(m)
		m.start({"mode": mode, "map": mp.id, "fighters": Net.make_fighters([], 8, 2, mode), "me": -1, "demo": true, "seed": 7})
		for i in 240:
			await get_tree().process_frame
		await _shot("%s/%s_follow.png" % [dir, mp.id])
		m.set_process(false)
		var views: Array = mp.get("views", [[Vector3(0, 30, 45), Vector3.ZERO]])
		for v in views.size():
			m.cam.global_position = views[v][0]
			m.cam.look_at(views[v][1], Vector3.UP)
			m.cam.fov = 80
			await _shot("%s/%s_view%d.png" % [dir, mp.id, v])
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _shot(path: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
