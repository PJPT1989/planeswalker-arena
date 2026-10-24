extends Node
## Autoload `Net`: online matches. One player hosts a room and runs the match (the rules and
## the bots); friends join with the room code. Everything travels over Godot's high-level
## multiplayer:
##   in the browser  WebRTC, peer to peer. The browsers find each other through a signalling
##                   channel (tools/web/arena-net.js: on the shop page a Supabase Realtime
##                   channel per room, elsewhere a BroadcastChannel between tabs).
##   on a computer   ENet; the room code is the host's address (IP).
## In the room the host picks the mode, the map, how many bots and how good, and the limits;
## everyone picks a planeswalker and (in team modes) a side. During a match each guest sends
## where its own fighter is (twenty times a second) and its shots; the host sends snapshots
## and events (see Match).

signal lobby_changed
signal status_changed
signal match_start(cfg: Dictionary)
signal left(reason: String)

enum { OFF, HOST, CLIENT }
const PORT := 24710
const MAX_PEOPLE := 8
const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]}]}
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var role := OFF
var code := ""
var status := ""
## People in the room: {peer, name, walker, team (-1 auto, 0 red, 1 blue)}
var people: Array = []
## What the host set up: mode, map, bots, skill, limit, minutes
var setup := {"mode": "ffa", "map": "foundry", "bots": 3, "skill": 1, "limit": 20, "minutes": 10}
var in_match := false
var game: Match
var test_args: PackedStringArray = []   # automated tests: host=CODE, join=CODE, bot, start=N

var _js: JavaScriptObject
var _peer: MultiplayerPeer
var _conns := {}
var _hello_t := 0.0
var _join_wait := 0.0
var _pending := PackedByteArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Could not reach the host."))
	multiplayer.server_disconnected.connect(func(): _fail("The host left the room."))
	if OS.has_feature("web"):
		_js = JavaScriptBridge.get_interface("ArenaNet")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net="):
			test_args = a.substr(6).split(",")
	if _js and test_args.is_empty():
		var t := str(_js.testArgs())
		if t != "":
			test_args = t.split(",")


func active() -> bool:
	return role != OFF


func is_host() -> bool:
	return role == HOST


func is_client() -> bool:
	return role == CLIENT


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


func invite_code() -> String:
	return str(_js.roomFromUrl()) if _js else ""


func copy_code() -> void:
	if _js:
		_js.copy(code)
	else:
		DisplayServer.clipboard_set(code)


func test_flag(name: String) -> String:
	for a in test_args:
		if a == name:
			return "1"
		if a.begins_with(name + "="):
			return a.get_slice("=", 1)
	return ""


func _set_status(s: String) -> void:
	status = s
	status_changed.emit()


func me() -> Dictionary:
	for p in people:
		if int(p.peer) == my_id():
			return p
	return {}


# --- rooms ------------------------------------------------------------------------------

func host() -> void:
	leave()
	role = HOST
	people = [{"peer": 1, "name": Game.player_name, "walker": Game.walker, "team": -1}]
	if _js:
		code = ""
		for i in 5:
			code += CODE_CHARS[randi() % CODE_CHARS.length()]
		var fixed := test_flag("host")
		if fixed != "" and fixed != "1":
			code = fixed
		var p := WebRTCMultiplayerPeer.new()
		p.create_server()
		_peer = p
		_js.open(code)
	else:
		var p := ENetMultiplayerPeer.new()
		if p.create_server(PORT, MAX_PEOPLE) != OK:
			role = OFF
			_set_status("Could not open a room on port %d." % PORT)
			return
		_peer = p
		code = _local_ip()
	multiplayer.multiplayer_peer = _peer
	_set_status("Room open. Share the code with your friends.")
	lobby_changed.emit()


func join(room: String) -> void:
	leave()
	room = room.strip_edges()
	if room == "":
		_set_status("Type the room code first.")
		return
	role = CLIENT
	people = []
	if _js:
		code = room.to_upper()
		var p := WebRTCMultiplayerPeer.new()
		p.create_client(randi_range(2, 2147483646))
		_peer = p
		multiplayer.multiplayer_peer = _peer
		_js.open(code)
		_new_conn(1)
		_hello_t = 0.0
		_join_wait = 20.0
	else:
		code = room
		var p := ENetMultiplayerPeer.new()
		if p.create_client(room, PORT) != OK:
			role = OFF
			_set_status("That is not an address.")
			return
		_peer = p
		multiplayer.multiplayer_peer = _peer
		_join_wait = 12.0
	_set_status("Looking for room %s..." % code)


func leave() -> void:
	if _js:
		_js.close()
	for c in _conns.values():
		c.close()
	_conns.clear()
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	role = OFF
	in_match = false
	game = null
	people = []
	_join_wait = 0.0


func _fail(reason: String) -> void:
	if role == OFF:
		return
	leave()
	_set_status(reason)
	left.emit(reason)


func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "127.0.0.1"


## Host: change the match setup (any of mode, map, bots, skill, limit, minutes).
func set_setup(changes: Dictionary) -> void:
	if not is_host():
		return
	for k in changes:
		setup[k] = changes[k]
	if setup.has("mode") and changes.has("mode"):
		var maps := Maps.for_mode(setup.mode)
		var ok := false
		for mp in maps:
			ok = ok or mp.id == setup.map
		if not ok:
			setup.map = maps[0].id
		setup.limit = Data.MODES[setup.mode].limit
		setup.minutes = Data.MODES[setup.mode].minutes
	_push_lobby()


## My planeswalker and side in the room.
func pick(walker: String, team: int) -> void:
	Game.set_player(Game.player_name, walker)
	if is_host():
		_apply_pick(1, Game.player_name, walker, team)
	elif is_client():
		_req_pick.rpc_id(1, Game.player_name, walker, team)


func _apply_pick(peer: int, name: String, walker: String, team: int) -> void:
	for p in people:
		if int(p.peer) == peer:
			p.name = name.substr(0, 16)
			if Data.WALKERS.has(walker):
				p.walker = walker
			p.team = clampi(team, -1, 1)
	_push_lobby()


func _push_lobby() -> void:
	if not is_host():
		return
	lobby_changed.emit()
	if not multiplayer.get_peers().is_empty():
		_lobby.rpc(people, setup, code)


@rpc("any_peer", "call_remote", "reliable")
func _hello(name: String, walker: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if in_match:
		_kick.rpc_id(id, "A match is already running in that room. Try again after it.")
		return
	for p in people:
		if int(p.peer) == id:
			p.name = name.substr(0, 16)
			_push_lobby()
			return
	if people.size() >= MAX_PEOPLE:
		_kick.rpc_id(id, "That room is full.")
		return
	people.append({"peer": id, "name": name.substr(0, 16), "walker": walker if Data.WALKERS.has(walker) else "jace", "team": -1})
	_push_lobby()


@rpc("authority", "call_remote", "reliable")
func _kick(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func _lobby(p: Array, s: Dictionary, c: String) -> void:
	people = p
	setup = s
	code = c
	_set_status("In room %s." % c)
	lobby_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _req_pick(name: String, walker: String, team: int) -> void:
	_apply_pick(multiplayer.get_remote_sender_id(), name, walker, team)


func _on_peer_connected(id: int) -> void:
	if is_client() and id == 1:
		_on_connected()


func _on_connected() -> void:
	if not is_client():
		return
	_join_wait = 0.0
	_set_status("Connected, joining the room...")
	_hello.rpc_id(1, Game.player_name, Game.walker)


func _on_peer_disconnected(id: int) -> void:
	if is_client():
		if id == 1:
			_fail("The host left the room.")
		return
	if not is_host():
		return
	_conns.erase(id)
	for i in range(people.size() - 1, -1, -1):
		if int(people[i].peer) == id:
			people.remove_at(i)
	if game and is_instance_valid(game):
		game.peer_left(id)
	_push_lobby()


# --- the match ---------------------------------------------------------------------------

## Builds the fighter list: the people (sides as they asked, "auto" evens them out) and the
## bots, who fill the smaller side first.
static func make_fighters(humans: Array, bots: int, skill: int, mode: String) -> Array:
	var teams: bool = Data.MODES[mode].teams
	var out := []
	var counts := [0, 0]
	for h in humans:
		if teams and int(h.team) >= 0:
			counts[int(h.team)] += 1
	for h in humans:
		var t := -1
		if teams:
			t = int(h.team)
			if t < 0:
				t = 0 if counts[0] <= counts[1] else 1
				counts[t] += 1
		out.append({"name": h.name, "walker": h.walker, "team": t, "peer": int(h.peer), "bot": -1})
	var used := {}
	for o in out:
		used[o.walker] = true
	var pool := []
	for w in Data.WALKER_ORDER:
		if not used.has(w):
			pool.append(w)
	pool.shuffle()
	for i in mini(bots, Data.MAX_FIGHTERS - out.size()):
		var w: String = pool[i % pool.size()] if not pool.is_empty() else Data.WALKER_ORDER[i % Data.WALKER_ORDER.size()]
		var t := -1
		if teams:
			t = 0 if counts[0] <= counts[1] else 1
			counts[t] += 1
		out.append({"name": Data.WALKERS[w].name, "walker": w, "team": t, "peer": 1, "bot": skill})
	return out


func can_start() -> bool:
	return is_host() and not in_match


func start_match() -> void:
	if not can_start():
		return
	var fl := make_fighters(people, int(setup.bots), int(setup.skill), str(setup.mode))
	var c := {"mode": setup.mode, "map": setup.map, "limit": int(setup.limit), "minutes": int(setup.minutes),
		"seed": randi() % 1000000, "fighters": fl, "online": true}
	_start.rpc(c)
	_start(c)


@rpc("authority", "call_remote", "reliable")
func _start(c: Dictionary) -> void:
	in_match = true
	var cc := c.duplicate(true)
	cc.me = -1
	for i in cc.fighters.size():
		if int(cc.fighters[i].peer) == my_id() and int(cc.fighters[i].bot) < 0:
			cc.me = i
	cc.guest = is_client()
	match_start.emit(cc)


func attach(m: Match) -> void:
	game = m


func back_to_room() -> void:
	in_match = false
	game = null
	if is_host():
		_push_lobby()


## Guest -> host: a request from its fighter (a shot, a respawn).
func send_request(e: Dictionary) -> void:
	if is_client():
		_req.rpc_id(1, e)


@rpc("any_peer", "call_remote", "reliable")
func _req(e: Dictionary) -> void:
	if is_host() and game and is_instance_valid(game):
		game.net_request(e, multiplayer.get_remote_sender_id())


## Host -> guests: an event (except to the one who caused it, when given).
func broadcast_event(e: Dictionary, except_peer := 0) -> void:
	if not is_host():
		return
	for p in multiplayer.get_peers():
		if p != except_peer:
			_event.rpc_id(p, e)


@rpc("authority", "call_remote", "reliable")
func _event(e: Dictionary) -> void:
	if game and is_instance_valid(game):
		game.net_event(e)


func broadcast_snapshot(data: PackedByteArray) -> void:
	if is_host() and not multiplayer.get_peers().is_empty():
		_snapshot.rpc(data)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(data: PackedByteArray) -> void:
	_pending = data


func send_state(data: PackedByteArray) -> void:
	if is_client():
		_state.rpc_id(1, data)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(data: PackedByteArray) -> void:
	if is_host() and game and is_instance_valid(game):
		game.net_state(multiplayer.get_remote_sender_id(), data)


# --- WebRTC signalling ---------------------------------------------------------------------

func _new_conn(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize(ICE)
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		_sig({"t": "sdp", "o": id, "type": type, "sdp": sdp}))
	c.ice_candidate_created.connect(func(mid: String, index: int, cand: String):
		_sig({"t": "ice", "o": id, "mid": mid, "i": index, "c": cand}))
	(_peer as WebRTCMultiplayerPeer).add_peer(c, id)
	_conns[id] = c
	return c


func _sig(m: Dictionary) -> void:
	if _js == null:
		return
	m["f"] = multiplayer.get_unique_id()
	_js.send(JSON.stringify(m))


func _on_signal(m: Dictionary) -> void:
	var from := int(m.get("f", 0))
	var to := int(m.get("o", 0))
	if from == 0 or from == multiplayer.get_unique_id():
		return
	if to != 0 and to != multiplayer.get_unique_id():
		return
	match str(m.get("t", "")):
		"hello":
			if not is_host():
				return
			if _conns.has(from):
				var old: WebRTCPeerConnection = _conns[from]
				if old.get_connection_state() != WebRTCPeerConnection.STATE_FAILED:
					return
				(_peer as WebRTCMultiplayerPeer).remove_peer(from)
				_conns.erase(from)
			if in_match or people.size() >= MAX_PEOPLE:
				_sig({"t": "busy", "o": from, "full": not in_match})
				return
			var c := _new_conn(from)
			c.create_offer()
		"sdp":
			if _conns.has(from):
				_conns[from].set_remote_description(str(m.type), str(m.sdp))
		"ice":
			if _conns.has(from):
				_conns[from].add_ice_candidate(str(m.mid), int(m.i), str(m.c))
		"busy":
			if is_client() and _join_wait > 0.0:
				_fail("That room is full." if m.get("full", false) else "A match is already running in that room. Try again after it.")


func _process(dt: float) -> void:
	if not _pending.is_empty():
		if game and is_instance_valid(game):
			game.apply_snapshot(_pending)
		_pending = PackedByteArray()
	if _js and active():
		var raw := str(_js.poll())
		if raw != "[]" and raw != "":
			var arr = JSON.parse_string(raw)
			if arr is Array:
				for s in arr:
					var m = JSON.parse_string(str(s))
					if m is Dictionary:
						_on_signal(m)
	if is_client() and _join_wait > 0.0:
		_join_wait -= dt
		if _js:
			_hello_t -= dt
			if _hello_t <= 0.0 and bool(_js.ready()):
				_hello_t = 1.0
				_sig({"t": "hello", "o": 1})
		if _join_wait <= 0.0:
			var c: WebRTCPeerConnection = _conns.get(1)
			if c and c.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTING:
				_fail("Found the room, but could not connect to the host. One of your networks blocks direct connections.")
			else:
				_fail("No room %s found. Check the code, and that the host is still in the room." % code)
