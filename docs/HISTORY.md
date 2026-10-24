# History

## Round 1: the first version
**Request (Petr):** "Build another game. This time it will be first person shooter game. It will
be inspired by ut99/quake 3 arena. But will again have motives of MTG. For example the person
models and names can be planeswalkers. Game will have different game modes like capture the flag,
free-for all and teams etc.... Each game mode at least 5 different maps (there can be overlap,
especially for free-for all and team game). multiplayer and/or bots needs to be available."

**Decided (defaults, offered to Petr):** the name Planeswalker Arena; a new repository like the
other games; three modes (free-for-all, team deathmatch, capture the flag); five arenas shared by
free-for-all and team deathmatch plus five symmetric arenas for capture the flag; bots and
host-run online rooms like Planar Wars, published on the shop.

**Built:**
- Quake-style movement (air control, jump pads, portals, stepping up ledges), seven weapons
  (Spellblade, Spark Repeater, Thunderclap, Aether Pulse, Lightning Lash, Fireball, Disintegrate
  with zoom and headshots), health, armour, Overload and Haste.
- Twelve planeswalkers with their own low-poly models, colours and original titles: Chandra, Jace,
  Liliana, Gideon, Nissa, Ajani, Teferi, Sorin, Karn, Vraska, Ral and Kaya.
- Ten arenas on ten planes: Ghirapur Foundry, Tenth District Plaza, Thraben Cathedral, Skyclash
  Ruins and Furnace Core (free-for-all and team deathmatch); Nyx Spires, Benalish Keeps, Orazca
  Temples, Neon Spires and Necropolis Trench (capture the flag, mirrored for fairness).
- Bots at four skills (Common to Mythic) that collect weapons and armour, use pads and portals,
  and play CTF roles.
- HUD (health, armour, weapon bar, ammo, clock, scores, flags, kill feed, hit marker, damage
  arrows), scoreboard, results; menus with a live bot match behind the title, a planeswalker
  picker with a turning model, options (mouse, field of view, graphics, sound), pause.
- Online rooms for up to eight people plus bots (WebRTC in the browser, ENet on a computer).
- Tests: bot-only simulation of every arena and mode, a visual smoke test, a two-copy online test.
