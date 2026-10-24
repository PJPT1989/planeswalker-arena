# Planeswalker Arena

A fast arena first-person shooter built in Godot 4.3, in the spirit of *Unreal Tournament 99* and
*Quake III Arena*, set in the Multiverse of Magic: The Gathering. Twelve planeswalkers fight in ten
arenas on ten planes: free-for-all, team deathmatch and capture the flag, against bots or online
with friends (bots fill the empty places).

Fan-made and unofficial. Planeswalker and plane names are kept for the setting; the models,
titles, weapons, arenas and all text are original.

## How to play
- **Free-for-all**: everyone against everyone. The first to the frag limit wins, or whoever leads
  when the time runs out.
- **Team Deathmatch**: Red against Blue; every frag counts for the team.
- **Capture the Flag**: touch the enemy banner to take it and bring it to your own banner while
  yours is at home. A carrier who dies drops the banner; touching your own dropped banner sends it
  home (it also goes home by itself after 30 seconds).
- You come back a moment after dying with the Spellblade and the Spark Repeater. Everything else
  lies in the arena and comes back a while after someone takes it.
- Health above 100 slowly fades back to 100. Armour takes two thirds of every hit.
- Your own blasts hurt you at half strength, and throw you: fireball jumps work.

## Controls
| Input | Action |
| --- | --- |
| Mouse | Look |
| W A S D or arrows | Run (you keep your speed in the air) |
| Space | Jump |
| Left click | Fire (after dying: come back) |
| Right click or Z | Zoom (Disintegrate) |
| Wheel, 1-7, E / Q | Change weapon |
| R | Last weapon again |
| Tab | Scores |
| Esc or F10 | Menu (pauses when not online) |
| L / M | Graphics quality (Low, Medium, High) / sound on or off |

## Weapons
| Key | Weapon | What it does |
| --- | --- | --- |
| 1 | Spellblade | A blade of light, 50 damage close up. Never runs out |
| 2 | Spark Repeater | Fast sparks, 7 damage each. You always start with it |
| 3 | Thunderclap | Eleven pellets in a cone, deadly up close |
| 4 | Aether Pulse | Quick bolts with a small blast |
| 5 | Lightning Lash | A short beam; keep it on them |
| 6 | Fireball | 100 damage and a big blast that throws people. Aim at the feet |
| 7 | Disintegrate | A beam through everyone in the line. 90 damage, 150 to the head. Zoom with the right button |

## Pickups
| Pickup | Effect |
| --- | --- |
| Healing Salve | +25 health, up to 100 |
| Elixir of Life | +100 health, up to 200 |
| Aegis Shard | +5 armour, up to 200 |
| Ward Plate | +50 armour |
| Aegis of the Gods | +100 armour |
| Overload | Triple damage for 30 seconds |
| Haste | A third faster for 30 seconds |

Jump pads throw you to a ledge or a tower top; portals carry you to their twin. Lava and the void
kill (a push off the edge counts as a frag for whoever pushed).

## Planeswalkers
Chandra (Kaladesh), Jace (Vryn), Liliana (Dominaria), Gideon (Theros), Nissa (Zendikar), Ajani
(Naya), Teferi (Dominaria), Sorin (Innistrad), Karn (Dominaria), Vraska (Ravnica), Ral (Ravnica)
and Kaya (Tolvada). Pick yours under **Planeswalkers**; it only changes how you look. Bots take
the others.

## Arenas
| Arena | Plane | Modes | |
| --- | --- | --- | --- |
| Ghirapur Foundry | Kaladesh | FFA, TDM | A raised hub, four balconies and a ring of catwalks |
| Tenth District Plaza | Ravnica | FFA, TDM | A fountain square, rooftops, bridges and narrow streets |
| Thraben Cathedral | Innistrad | FFA, TDM | The nave, galleries, a choir loft and the crypt below |
| Skyclash Ruins | Zendikar | FFA, TDM | Floating islands among hedrons, jump pads and a long fall |
| Furnace Core | New Phyrexia | FFA, TDM | A burning pit with one bridge across, a ring above and four towers |
| Nyx Spires | Theros | CTF | Two marble towers under the stars and a long open field |
| Benalish Keeps | Dominaria | CTF | Two castles across a river valley, wall walks and a watchtower |
| Orazca Temples | Ixalan | CTF | Step pyramids in the jungle, the banners in the shrines on top |
| Neon Spires | Kamigawa | CTF | Two neon towers, sky walks and portals to the middle |
| Necropolis Trench | Amonkhet | CTF | Two tombs in the desert with a trench between them |

## Bots
Four skills named after card rarities: Common, Uncommon, Rare and Mythic. Better bots aim better,
react sooner, turn faster and dodge more. Bots pick up weapons and armour, use pads and portals,
and in CTF split into attackers, defenders and roamers, escort their carrier and chase yours.

## Multiplayer
**Multiplayer** opens a room (up to eight people) or joins one with its code. The host picks the
mode, arena, limit, time and how many bots fill the arena (up to twelve fighters in all); everyone
picks a planeswalker and, in team modes, a side. In the browser the room code works anywhere
(players connect peer to peer); on a computer the code is the host's address (port 24710, UDP).
After the match everyone goes back to the room.

## Graphics
L cycles Low, Medium and High. The browser build starts on Medium and drops to Low once by itself
if the first match runs slowly; your own choice is remembered.

## Running it
- Godot 4.3: open the folder in the editor and press Play, or `godot --path .`.
- Browser: `tools/export_web.sh` builds `build/web/` (upload the whole folder; see
  `tools/web/HOW-TO-UPLOAD.txt`).

## Files
| Path | What |
| --- | --- |
| `scripts/main.gd` | Menus, the title screen's bot match, the pause menu, graphics quality |
| `scripts/match.gd` | One match: rules, weapons, pickups, flags, the camera, online sync |
| `scripts/fighter.gd` | A planeswalker: movement, weapons, health, the animated model |
| `scripts/bot.gd` | The bots |
| `scripts/hud.gd` | The heads-up display, scoreboard and results |
| `scripts/arena.gd`, `scripts/maps.gd` | The arena builder and the ten arenas |
| `scripts/models.gd`, `scripts/mesh_kit.gd` | Planeswalkers, weapons and pickups made from code |
| `scripts/data.gd` | Planeswalkers, weapons, pickups, modes, bot skills |
| `scripts/net.gd`, `tools/web/arena-net.js` | Online rooms (WebRTC in the browser, ENet on a computer) |
| `scripts/game.gd`, `scripts/ui.gd`, `scripts/fx.gd` | Settings, materials, sounds, menu theme, effects |
| `scripts/simtest.gd`, `autotest.gd`, `nettest.gd`, `shots.gd` | Automated tests and screenshots |
