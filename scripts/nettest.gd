extends Node
## Automated online test (`tools/net_test.sh`, or the web build with `?panet=...`). Flags in
## `--net=` (comma separated):
##   host[=CODE]  open a room;  join=CODE  join one (on a computer CODE is the host's address)
##   start=N      host: start once N people are in the room
##   bot          a bot plays my fighter (on a guest it runs there and sends its shots to the host)
##   mode=ffa|tdm|ctf, map=id, bots=N, minutes=M (default 1)
## When the match ends each side prints `NETTEST over ...` with the scores from its own copy of
## the match; the host's and the guests' lines must match. Then `NETTEST done`.

var main: Node
var m: Match
var printed := false
var _start_wait := 0.0
var _report := 0.0


func _ready() -> void:
	main = get_parent()
	Game.testing = true
	Net.match_start.connect(_on_start, CONNECT_DEFERRED)
	Net.left.connect(func(r: String):
		print("NETTEST left: ", r)
		_quit())
	if Net.test_flag("host") != "":
		Net.host()
		print("NETTEST hosting ", Net.code)
		var mode := Net.test_flag("mode") if Net.test_flag("mode") != "" else "tdm"
		Net.set_setup({"mode": mode})
		var changes := {"bots": int(Net.test_flag("bots")) if Net.test_flag("bots") != "" else 4, "limit": 999,
			"minutes": float(Net.test_flag("minutes")) if Net.test_flag("minutes") != "" else 1.0, "skill": 2}
		if Net.test_flag("map") != "":
			changes.map = Net.test_flag("map")
		Net.set_setup(changes)
	else:
		Net.join(Net.test_flag("join"))
		print("NETTEST joining ", Net.test_flag("join"))
	main.show_lobby()


func _on_start(_cfg: Dictionary) -> void:
	m = main.match_node
	print("NETTEST started as fighter ", m.me, " host=", m.host, " mode=", m.mode, " map=", m.map_def.id, " fighters=", m.fighters.size())


func _process(delta: float) -> void:
	if m == null:
		if Net.is_host() and not Net.in_match and Net.people.size() >= maxi(1, int(Net.test_flag("start"))):
			_start_wait += delta
			if _start_wait > 1.0:
				Net.start_match()
		return
	if not is_instance_valid(m):
		return
	_report += delta
	if _report > 10.0:
		_report = 0.0
		var me := m.fighters[m.me]
		print("NETTEST progress left=%.0f fps=%d me alive=%s hp=%d frags=%d" % [m.time_left, Engine.get_frames_per_second(), me.alive, me.health, m.scores[m.me].frags])
	if not printed and m.over:
		printed = true
		print(_summary())
		get_tree().create_timer(3.0 if Net.is_host() else 0.5).timeout.connect(_quit)


func _summary() -> String:
	var line := "NETTEST over team=%s red=%d blue=%d" % [m.winner.get("team", -1), m.team_score[0], m.team_score[1]]
	for i in m.fighters.size():
		var s: Dictionary = m.scores[i]
		line += " | %s %d/%d/%d" % [m.fighters[i].display_name(), s.frags, s.deaths, s.caps]
	return line


func _quit() -> void:
	print("NETTEST done")
	get_tree().quit()
