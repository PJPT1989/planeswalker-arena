class_name Data
extends RefCounted
## Everything the rules read: the planeswalkers (looks only, everyone plays the same), the
## weapons, the pickups, the game modes and bot skill levels.

const MAX_FIGHTERS := 12
const TEAM_NAMES := ["Red", "Blue"]
const TEAM_COLORS := [Color(0.95, 0.25, 0.2), Color(0.25, 0.55, 1.0)]
const FFA_COLOR := Color(0.95, 0.85, 0.55)

# --- movement (metres and seconds) ---
const RUN_SPEED := 9.0
const GROUND_ACCEL := 10.0
const AIR_ACCEL := 1.6
const FRICTION := 6.0
const STOP_SPEED := 2.5
const JUMP_SPEED := 7.2
const GRAVITY := 20.0
const EYE := 1.6
const HEIGHT := 1.8
const RADIUS := 0.4
const HEAD_Y := 1.45               # a hit above this height (from the feet) is a headshot

const START_HEALTH := 100
const MAX_HEALTH := 200            # the Elixir goes past 100; anything above ticks down
const MAX_ARMOR := 200
const ARMOR_ABSORB := 0.66
const SELF_DAMAGE := 0.5
const RESPAWN_DELAY := 1.6
const FLAG_RETURN := 30.0

## Planeswalkers. Colours: skin, hair, main (coat or armour), second, trim, glow.
## "hair": short, long, hood, bald, flame, mane, tendrils, spikes, veil, helm.
## "build": shoulders scale; "extra": a feature the model adds (goggles, cape, staff...).
const WALKERS := {
	"chandra": {"name": "Chandra", "full": "Chandra, Flame of Ghirapur", "plane": "Kaladesh", "hair": "flame", "build": 0.95,
		"skin": Color(0.93, 0.72, 0.58), "hair_col": Color(1.0, 0.45, 0.1), "main": Color(0.72, 0.16, 0.08),
		"second": Color(0.35, 0.22, 0.15), "trim": Color(0.95, 0.7, 0.3), "glow": Color(1.0, 0.55, 0.15), "extra": "goggles",
		"blurb": "A pyromancer from Kaladesh who answers most questions with fire."},
	"jace": {"name": "Jace", "full": "Jace, Weaver of Thoughts", "plane": "Vryn", "hair": "hood", "build": 0.95,
		"skin": Color(0.9, 0.74, 0.62), "hair_col": Color(0.25, 0.2, 0.18), "main": Color(0.12, 0.28, 0.62),
		"second": Color(0.82, 0.84, 0.9), "trim": Color(0.75, 0.85, 1.0), "glow": Color(0.35, 0.75, 1.0), "extra": "cape",
		"blurb": "A telepath who reads his opponents a moment before they move."},
	"liliana": {"name": "Liliana", "full": "Liliana, Mistress of the Grave", "plane": "Dominaria", "hair": "veil", "build": 0.9,
		"skin": Color(0.88, 0.76, 0.7), "hair_col": Color(0.1, 0.08, 0.1), "main": Color(0.22, 0.1, 0.28),
		"second": Color(0.08, 0.06, 0.08), "trim": Color(0.8, 0.75, 0.7), "glow": Color(0.7, 0.35, 1.0), "extra": "",
		"blurb": "A necromancer who has never once lost an argument with the dead."},
	"gideon": {"name": "Gideon", "full": "Gideon, Shield of the Gatewatch", "plane": "Theros", "hair": "short", "build": 1.12,
		"skin": Color(0.78, 0.58, 0.45), "hair_col": Color(0.15, 0.1, 0.08), "main": Color(0.88, 0.86, 0.8),
		"second": Color(0.85, 0.62, 0.22), "trim": Color(1.0, 0.82, 0.4), "glow": Color(1.0, 0.85, 0.4), "extra": "",
		"blurb": "A soldier with an unbreakable shield of light and a will even harder to break."},
	"nissa": {"name": "Nissa", "full": "Nissa, Heart of the Wilds", "plane": "Zendikar", "hair": "long", "build": 0.9,
		"skin": Color(0.82, 0.7, 0.55), "hair_col": Color(0.25, 0.75, 0.3), "main": Color(0.16, 0.42, 0.2),
		"second": Color(0.38, 0.28, 0.16), "trim": Color(0.6, 0.85, 0.35), "glow": Color(0.4, 1.0, 0.45), "extra": "ears",
		"blurb": "An animist elf; the land itself picks her fights for her."},
	"ajani": {"name": "Ajani", "full": "Ajani, Mane of Naya", "plane": "Naya", "hair": "mane", "build": 1.15,
		"skin": Color(0.85, 0.72, 0.5), "hair_col": Color(0.96, 0.94, 0.86), "main": Color(0.9, 0.88, 0.82),
		"second": Color(0.5, 0.35, 0.2), "trim": Color(0.95, 0.75, 0.3), "glow": Color(1.0, 0.92, 0.6), "extra": "axe",
		"blurb": "A white-maned leonin who fights for his pride and his friends."},
	"teferi": {"name": "Teferi", "full": "Teferi, Keeper of Hours", "plane": "Dominaria", "hair": "bald", "build": 1.0,
		"skin": Color(0.36, 0.24, 0.17), "hair_col": Color(0.9, 0.9, 0.88), "main": Color(0.92, 0.92, 0.95),
		"second": Color(0.2, 0.42, 0.72), "trim": Color(0.95, 0.8, 0.4), "glow": Color(0.55, 0.85, 1.0), "extra": "staff",
		"blurb": "A time mage. He is never late, and rarely where you expect."},
	"sorin": {"name": "Sorin", "full": "Sorin, Old Blood of Innistrad", "plane": "Innistrad", "hair": "long", "build": 1.02,
		"skin": Color(0.9, 0.88, 0.86), "hair_col": Color(0.92, 0.92, 0.94), "main": Color(0.12, 0.1, 0.12),
		"second": Color(0.55, 0.06, 0.08), "trim": Color(0.75, 0.75, 0.8), "glow": Color(1.0, 0.2, 0.2), "extra": "cape",
		"blurb": "An ancient vampire with very old grudges and very sharp teeth."},
	"karn": {"name": "Karn", "full": "Karn, the Silver Maker", "plane": "Dominaria", "hair": "bald", "build": 1.25,
		"skin": Color(0.72, 0.74, 0.78), "hair_col": Color(0.72, 0.74, 0.78), "main": Color(0.62, 0.64, 0.7),
		"second": Color(0.45, 0.47, 0.52), "trim": Color(0.88, 0.9, 0.95), "glow": Color(0.7, 0.9, 1.0), "extra": "golem",
		"blurb": "A silver golem who built half the artifacts you are shooting at him."},
	"vraska": {"name": "Vraska", "full": "Vraska, Queen Below", "plane": "Ravnica", "hair": "tendrils", "build": 0.95,
		"skin": Color(0.42, 0.6, 0.42), "hair_col": Color(0.3, 0.48, 0.3), "main": Color(0.3, 0.14, 0.32),
		"second": Color(0.18, 0.15, 0.1), "trim": Color(0.85, 0.7, 0.3), "glow": Color(0.9, 0.85, 0.3), "extra": "",
		"blurb": "A gorgon assassin. Do not meet her eyes. Do not miss either."},
	"ral": {"name": "Ral", "full": "Ral, Storm in a Bottle", "plane": "Ravnica", "hair": "spikes", "build": 0.98,
		"skin": Color(0.9, 0.75, 0.62), "hair_col": Color(0.9, 0.9, 0.95), "main": Color(0.2, 0.22, 0.4),
		"second": Color(0.55, 0.4, 0.2), "trim": Color(0.4, 0.75, 1.0), "glow": Color(0.55, 0.8, 1.0), "extra": "coil",
		"blurb": "A storm mage with a lightning coil strapped to his arm."},
	"kaya": {"name": "Kaya", "full": "Kaya, Ghost Walker", "plane": "Tolvada", "hair": "long", "build": 0.92,
		"skin": Color(0.5, 0.36, 0.28), "hair_col": Color(0.12, 0.08, 0.1), "main": Color(0.35, 0.18, 0.4),
		"second": Color(0.85, 0.84, 0.82), "trim": Color(0.75, 0.55, 0.95), "glow": Color(0.8, 0.6, 1.0), "extra": "",
		"blurb": "A ghost assassin who walks through walls, and sometimes through you."},
}
const WALKER_ORDER := ["chandra", "jace", "liliana", "gideon", "nissa", "ajani", "teferi", "sorin", "karn", "vraska", "ral", "kaya"]

## Weapons, in key order 1-7. kind: melee, hitscan, pellets, beam, rail, projectile.
## rate: seconds between shots. ammo: [start, pickup, max] (-1: needs none).
## bot: the distance band (m) where bots like to use it, and how much they like it.
const WEAPONS := {
	"blade": {"name": "Spellblade", "kind": "melee", "dmg": 50, "rate": 0.55, "range": 2.4, "ammo": [-1, 0, 0],
		"color": Color(1.0, 0.85, 0.5), "bot": [0.0, 3.0, 0.3],
		"desc": "A blade of light for when the mana runs dry."},
	"repeater": {"name": "Spark Repeater", "kind": "hitscan", "dmg": 7, "rate": 0.1, "spread": 0.025, "range": 120.0, "ammo": [100, 50, 200],
		"color": Color(1.0, 0.9, 0.55), "bot": [0.0, 40.0, 0.5],
		"desc": "Quick sparks of mana. Never great, never useless."},
	"thunder": {"name": "Thunderclap", "kind": "pellets", "dmg": 8, "pellets": 11, "rate": 1.0, "spread": 0.07, "range": 60.0, "ammo": [10, 10, 25],
		"color": Color(0.8, 0.9, 1.0), "bot": [0.0, 10.0, 0.9],
		"desc": "A blast of thunder that shreds anyone close."},
	"pulse": {"name": "Aether Pulse", "kind": "projectile", "dmg": 20, "splash": 15, "radius": 1.6, "speed": 45.0, "rate": 0.11, "knock": 3.0, "ammo": [50, 50, 200],
		"color": Color(0.35, 0.95, 1.0), "bot": [0.0, 22.0, 0.8],
		"desc": "Bolts of raw aether. Fast, and it can climb walls."},
	"lash": {"name": "Lightning Lash", "kind": "beam", "dmg": 7, "rate": 0.06, "range": 26.0, "ammo": [100, 100, 200],
		"color": Color(0.7, 0.8, 1.0), "bot": [3.0, 24.0, 0.85],
		"desc": "A whip of chained lightning. Keep it on them."},
	"fireball": {"name": "Fireball", "kind": "projectile", "dmg": 100, "splash": 100, "radius": 3.6, "speed": 28.0, "rate": 0.8, "knock": 11.0, "ammo": [10, 10, 50],
		"color": Color(1.0, 0.5, 0.15), "bot": [5.0, 45.0, 1.0],
		"desc": "The classic. Aim at their feet; jump on your own blasts."},
	"disintegrate": {"name": "Disintegrate", "kind": "rail", "dmg": 90, "head": 150, "rate": 1.5, "range": 300.0, "ammo": [10, 10, 25],
		"color": Color(0.85, 0.35, 1.0), "bot": [12.0, 300.0, 0.95],
		"desc": "A beam that unmakes. Right mouse to zoom; headshots kill."},
}
const WEAPON_ORDER := ["blade", "repeater", "thunder", "pulse", "lash", "fireball", "disintegrate"]
const START_WEAPONS := ["blade", "repeater"]

## Pickups. "respawn" in seconds.
const ITEMS := {
	"salve": {"name": "Healing Salve", "health": 25, "cap": 100, "respawn": 30.0, "color": Color(0.4, 1.0, 0.5)},
	"elixir": {"name": "Elixir of Life", "health": 100, "cap": 200, "respawn": 35.0, "color": Color(0.3, 0.6, 1.0)},
	"shard": {"name": "Aegis Shard", "armor": 5, "cap": 200, "respawn": 25.0, "color": Color(0.9, 0.95, 0.6)},
	"plate": {"name": "Ward Plate", "armor": 50, "cap": 200, "respawn": 25.0, "color": Color(0.95, 0.8, 0.3)},
	"aegis": {"name": "Aegis of the Gods", "armor": 100, "cap": 200, "respawn": 35.0, "color": Color(1.0, 0.5, 0.2)},
	"overload": {"name": "Overload", "power": "overload", "time": 30.0, "respawn": 90.0, "color": Color(0.85, 0.3, 1.0)},
	"haste": {"name": "Haste", "power": "haste", "time": 30.0, "respawn": 90.0, "color": Color(1.0, 0.3, 0.25)},
}
const OVERLOAD_MULT := 3.0
const HASTE_MULT := 1.35
const WEAPON_RESPAWN := 8.0

const FFA := "ffa"
const TDM := "tdm"
const CTF := "ctf"
const MODES := {
	"ffa": {"name": "Free-for-all", "short": "FFA", "teams": false, "limit": 20, "limits": [10, 15, 20, 30, 50], "minutes": 10,
		"desc": "Everyone against everyone. The first planeswalker to the frag limit wins."},
	"tdm": {"name": "Team Deathmatch", "short": "TDM", "teams": true, "limit": 40, "limits": [20, 30, 40, 60, 100], "minutes": 12,
		"desc": "Red against Blue. Every frag counts for your team."},
	"ctf": {"name": "Capture the Flag", "short": "CTF", "teams": true, "limit": 3, "limits": [1, 3, 5, 8, 10], "minutes": 15,
		"desc": "Steal the enemy banner and bring it to your own while yours is safe at home."},
}
const MODE_ORDER := ["ffa", "tdm", "ctf"]
const MINUTES := [5, 10, 15, 20, 30]

## Bot skill, by mana rarity. aim: error (radians), react: seconds before they shoot at someone
## new, turn: how fast they turn (radians/s), dodge: how much they strafe.
const SKILLS := [
	{"name": "Common", "aim": 0.11, "react": 0.75, "turn": 3.5, "dodge": 0.3, "lead": 0.4},
	{"name": "Uncommon", "aim": 0.065, "react": 0.5, "turn": 5.5, "dodge": 0.55, "lead": 0.7},
	{"name": "Rare", "aim": 0.04, "react": 0.32, "turn": 8.0, "dodge": 0.8, "lead": 0.9},
	{"name": "Mythic", "aim": 0.022, "react": 0.2, "turn": 12.0, "dodge": 1.0, "lead": 1.0},
]


static func team_color(team: int) -> Color:
	return TEAM_COLORS[team] if team >= 0 and team < 2 else FFA_COLOR


static func ammo_of(w: String) -> Array:
	return WEAPONS[w].ammo
