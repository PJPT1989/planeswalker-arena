# Planeswalker Arena: notes for Claude

An arena first-person shooter in **Godot 4.3** (GDScript, GL Compatibility renderer), inspired by
*Unreal Tournament 99* and *Quake III Arena*, with Magic: The Gathering planeswalkers as the
fighters. It is Petr's project; he describes features in plain language and expects them built,
tested and shown with screenshots. `README.md` is the player-facing guide and must stay accurate
when gameplay changes. `docs/HISTORY.md` has every request Petr made and what was built. Sister
projects: `PJPT1989/planar-wars`, `PJPT1989/aether-drift`, `PJPT1989/defense-of-the-planes` and
`PJPT1989/ashen-depths` (same tooling). The web build is published on Petr's shop
(`PJPT1989/tomano-collection-shop`, `hry-planeswalker-arena.html`, imported with its
`tools/game_import.py`).

## Running and testing (cloud or Linux)
- `tools/setup_godot.sh` installs Godot 4.3 as `~/.local/bin/godot` and imports the project (the
  SessionStart hook in `.claude/settings.json` runs it in cloud sessions).
- Always run Godot with `timeout`: a script error can leave it hanging.
- `godot --headless --fixed-fps 60 --path . -- --simtest [--map=id] [--mode=ffa|tdm|ctf]
  [--minutes=N] [--bots=8] [--skill=0..3] [--why]` plays bot-only matches on every arena and mode
  without drawing (about 15 s each) and prints shots, `stuck` (a bot that could not move for 1.6 s),
  self-kills by cause and pickups nobody ever took. `--why` prints where bots got stuck or fell.
  Run it after any change to maps, movement or bots: stuck should stay near 0 and CTF should see
  captures.
- `tools/smoke_test.sh [dir]` runs `scripts/autotest.gd` under `xvfb-run` (several minutes):
  menus, the planeswalker picker, a match on every arena with the player's fighter driven by a bot
  (`autopilot`), weapons in the hand, scores, pause, a death, a CTF carry and the results. Look at
  the PNGs (default `/tmp/pa-shots`). A good run ends with `AUTOTEST done` and has no
  `SCRIPT ERROR`. ALSA errors, leaked RIDs and "Parameter m is null" at exit are normal.
- `tools/net_test.sh [dir] [mode] [map]` runs a host and a guest (ENet, headless), each played by
  a bot, in a one-minute online match; both `NETTEST over` lines must be identical.
- `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution
  1280x720 -- --mapshots=/tmp/pa-maps [--map=id]` saves a follow view and fixed views of each arena.
- `tools/export_web.sh` builds `build/web/` (no-threads template). Test it in headless Chromium
  (Playwright is preinstalled; launch with `--use-gl=angle --use-angle=swiftshader
  --enable-unsafe-swiftshader`, plus `--disable-features=WebRtcHideLocalIpsWithMdns` for two-tab
  online tests on `index.html?panet=host=CODE,start=2,bot` and `?panet=join=CODE,bot`).

## Design
- Lore: planeswalkers and planes keep their names; titles ("Chandra, Flame of Ghirapur"), models,
  weapons, arenas and all text are original. Never copy card names, card art, card text or Wizards
  assets.
- Everything visual is generated from code: `MeshKit` with vertex colours and the shared materials
  in `Game` (`mat_world` for arena geometry with world-space patterns from `shaders/world.gdshader`,
  picked by UV.x, scaled by UV.y; `mat_solid`, `mat_glow`, `mat_gloss`, additive `mat_fx`).
- Arenas (`scripts/maps.gd`, `Maps.LIST`) are built by `Arena` helpers: `floor_rect`, `wall`,
  `solid`, `ramp` (tall ramps get step colliders beneath), `stairs` (steps to look at, a slope to
  walk on), `pad`, `tele`, `lava`, `item`, `weapon`, `spawn`, `flag`. CTF arenas set
  `a.mirror = true`, which repeats everything turned half round for the other team. Meshes are cut
  into `Arena.CHUNK` pieces so each gets its own nearby lights. The navigation mesh is baked from
  the colliders at load; pads, portals and ledge drops become navigation links.
- Movement is Quake-like (`Fighter.physics_step`: ground and air acceleration, friction, step-up
  of ledges up to `Fighter.STEP`). Fighters are `CharacterBody3D` capsules (layer 2, world layer 1).
- `Match` holds the rules. The host decides damage, frags, pickups, flags and spawns
  (`host_event` -> `_apply` everywhere). Each computer simulates its own fighters (its player; on
  the host also the bots), traces its own shots and sends `request`s; puppets interpolate
  snapshots 100 ms behind. New state a guest needs must go into `pack_snapshot` or an event.
- Online (`scripts/net.gd`, autoload `Net`): rooms of up to 8 people plus bots; WebRTC in the
  browser with signalling through `tools/web/arena-net.js` (rooms "pa-CODE" on the shop's
  `window.AetherSignal`, else a BroadcastChannel between tabs), ENet on port 24710 on desktop.
- Bots (`scripts/bot.gd`): goals (item, fight, chase, CTF attack/defend/escort/home), navmesh
  paths, a ledge probe (`_safe`) so they do not walk into the void or lava, sidestep when stuck.
- Quality (`Game.quality`, L key, `user://settings.cfg`): `Main._apply_quality` sets the 3D scale
  and MSAA, `Arena.apply_quality` shadows, glow and lights. The web build drops to LOW once by
  itself if the first match runs slowly.

## Code conventions
- GDScript with tabs, static types where the surrounding code has them, `##` doc comment at the top
  of each script. Data in `const` dictionaries near the top of the script that owns it. Nodes are
  built in code; `scenes/main.tscn` only holds `Main`.
- Web fonts have no fallback: use plain ASCII in titles, buttons and the HUD.
