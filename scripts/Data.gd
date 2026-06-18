extends Node
## Global constants, colors and data tables for AETHERWING.
## Faithful port of the constant tables from AETHERWING_prototype_v11.html.

# ------------------------------------------------------------
# COLORS
# ------------------------------------------------------------
const NAVY        := Color("050A14")
const NAVY2       := Color("0B1F3A")
const NAVY3       := Color("102849")
const CYAN        := Color("00F0FF")
const CYAN_SOFT   := Color("6FF3FF")
const MAGENTA     := Color("FF2D7A")
const MAGENTA_SOFT:= Color("FF6B9D")
const AMBER       := Color("FFE600")
const AMBER_SOFT  := Color("FFF48A")
const CHROME      := Color("C8D2DC")
const WHITE       := Color("FFFFFF")
const GREEN       := Color("00FF88")
const PURPLE      := Color("B14EFF")
const GOLD        := Color("FFB838")

# ------------------------------------------------------------
# PLAYER
# ------------------------------------------------------------
const PLAYER := {
	"size": 14.0,
	"max_hp": 3,
	"follow_speed": 0.55,
	"direct_speed": 0.85,
	"fire_rate": 4.0,
	"bullet_speed": 720.0,
	"bullet_damage": 6.0,
	"dash_distance": 95.0,
	"dash_duration": 0.16,
	"dash_cooldown": 2.6,
	"iframe_duration": 0.5,
	"deadzone": 8.0,
	"bank_smoothing": 0.12,
	"angle_smoothing": 0.18,
	"max_bank": 0.4,
}

# ------------------------------------------------------------
# ECHO
# ------------------------------------------------------------
const ECHO := {
	"meter_max": 100.0,
	"meter_per_kill": 4.5,
	"meter_per_hit": 8.0,
	"phase_duration": 4.5,
	"phase_time_scale": 0.35,
	"rewind_charges": 1,
}

# ------------------------------------------------------------
# ENEMIES — base stats (HP scales with wave)
# ------------------------------------------------------------
const ENEMY_BASE := {
	"drone":   {"hp": 18.0, "size": 10.0, "speed": 65.0, "score": 50,  "color": CYAN,    "xp": 1},
	"diver":   {"hp": 30.0, "size": 12.0, "speed": 0.0,  "score": 80,  "color": MAGENTA, "xp": 2},
	"bulwark": {"hp": 90.0, "size": 16.0, "speed": 35.0, "score": 150, "color": AMBER,   "xp": 3, "shield_hp": 50.0},
	"lancer":  {"hp": 45.0, "size": 14.0, "speed": 0.0,  "score": 120, "color": GOLD,    "xp": 2},
}

const SPAWN_PROTECTION := 0.4
const SPAWN_PROTECTION_MULT := 0.3
const CULL_DISTANCE := 1400.0
const SPAWN_RING_MIN := 0.55
const SPAWN_RING_MAX := 0.75
const ELITE_INTERVAL := 30.0
const BOSS_INTERVAL := 60.0

func scale_enemy_hp(base: float, wave: int) -> float:
	return round(base * (1.0 + wave * 0.15))

# ------------------------------------------------------------
# WEAPONS
# ------------------------------------------------------------
const WEAPONS := [
	{
		"id": "pulse", "name": "PULSE", "fire_rate": 4.0, "damage": 6.0,
		"bullet_speed": 720.0, "bullet_size": 4.0, "color": CYAN, "behavior": "single",
	},
	{
		"id": "lance", "name": "LANCE", "fire_rate": 1.5, "damage": 4.0,
		"bullet_speed": 1400.0, "bullet_size": 3.0, "color": MAGENTA, "behavior": "pierce",
		"pierce_max": 5,
	},
	{
		"id": "spread", "name": "SPREAD", "fire_rate": 2.5, "damage": 4.0,
		"bullet_speed": 600.0, "bullet_size": 4.0, "color": AMBER, "behavior": "spread",
		"spread_count": 3, "spread_angle": 0.35,
	},
	{
		"id": "singularity", "name": "SINGULARITY", "fire_rate": 0.8, "damage": 25.0,
		"bullet_speed": 400.0, "bullet_size": 8.0, "color": PURPLE, "behavior": "singularity",
		"singularity_radius": 120.0, "singularity_duration": 1.5, "singularity_pull": 200.0,
	},
]

# ------------------------------------------------------------
# UPGRADES (Survivor.io style level-up pool)
# id, icon, name, desc, rarity (common/rare)
# ------------------------------------------------------------
const UPGRADES := [
	{"id": "damage",      "icon": "⚔", "name": "DAMAGE UP",      "desc": "+25% bullet damage",            "rarity": "common"},
	{"id": "firerate",    "icon": "⚡", "name": "FIRE RATE",      "desc": "+20% fire rate",                "rarity": "common"},
	{"id": "multishot",   "icon": "✦", "name": "MULTI-SHOT",     "desc": "+1 bullet per shot",            "rarity": "rare"},
	{"id": "pierce",      "icon": "⟶", "name": "PIERCE",         "desc": "Bullets pierce +1 enemy",       "rarity": "rare"},
	{"id": "bulletspeed", "icon": "➤", "name": "BULLET SPEED",   "desc": "+30% bullet speed",             "rarity": "common"},
	{"id": "maxhp",       "icon": "♥", "name": "MAX HP +1",      "desc": "Permanent +1 max HP, full heal","rarity": "common"},
	{"id": "dashcd",      "icon": "◈", "name": "DASH COOLDOWN",  "desc": "-25% dash cooldown",            "rarity": "common"},
	{"id": "echogain",    "icon": "◊", "name": "ECHO GAIN",      "desc": "+50% Echo meter gain",          "rarity": "common"},
	{"id": "critchance",  "icon": "✸", "name": "CRIT CHANCE",    "desc": "+15% crit chance (3x dmg)",     "rarity": "rare"},
	{"id": "magnet",      "icon": "◐", "name": "MAGNET FIELD",   "desc": "+40% pickup magnet radius",     "rarity": "common"},
	{"id": "movespeed",   "icon": "✈", "name": "AGILITY",        "desc": "+15% ship follow speed",        "rarity": "common"},
	{"id": "rewind",      "icon": "↺", "name": "REWIND +1",      "desc": "+1 Echo Rewind charge",         "rarity": "rare"},
	{"id": "echoduration","icon": "◷", "name": "ECHO EXTEND",    "desc": "+1.5s Echo Phase duration",     "rarity": "common"},
	{"id": "lifesteal",   "icon": "✚", "name": "LIFESTEAL",      "desc": "5% chance to heal on kill",     "rarity": "rare"},
	{"id": "effboost",    "icon": "»", "name": "EFFICIENT BOOST","desc": "-20% boost Echo drain",         "rarity": "common"},
	{"id": "overdrive",   "icon": "⚡", "name": "OVERDRIVE",      "desc": "+30% boost speed",              "rarity": "rare"},
]

# ------------------------------------------------------------
# WORLD LANDMARKS + MINI-BOSSES
# ------------------------------------------------------------
const LANDMARK_GRID := 900.0

const LANDMARK_TYPES := {
	"cache":   {"icon": "⬡", "name": "CACHE",           "color": AMBER,  "effect": "FREE UPGRADE",          "radius": 50.0},
	"station": {"icon": "✚", "name": "HEALING STATION", "color": GREEN,  "effect": "FULL HEAL + ECHO",      "radius": 55.0},
	"ruins":   {"icon": "◬", "name": "XP RUINS",        "color": PURPLE, "effect": "2x XP FOR 30s",         "radius": 60.0},
	"beacon":  {"icon": "◉", "name": "BEACON",          "color": CYAN,   "effect": "RADAR EXPANDED 60s",    "radius": 50.0},
}

const MINI_BOSS_TYPES := {
	"warden":  {"name": "WARDEN",  "hp": 400.0, "size": 32.0, "speed": 50.0,  "color": MAGENTA_SOFT, "score": 2000, "xp": 15, "behavior": "chase"},
	"stalker": {"name": "STALKER", "hp": 250.0, "size": 26.0, "speed": 130.0, "color": MAGENTA,      "score": 1500, "xp": 12, "behavior": "chase_fast"},
	"sentry":  {"name": "SENTRY",  "hp": 300.0, "size": 30.0, "speed": 30.0,  "color": GOLD,         "score": 1800, "xp": 14, "behavior": "ranged"},
}

# Boost system
const BOOST := {
	"mult": 1.8,
	"drain_rate": 25.0,
	"min_echo_to_start": 5.0,
}

# XP curve
func xp_required(level: int) -> int:
	return int(floor(10.0 * pow(1.5, level - 1)))

# ------------------------------------------------------------
# DAILY + WEEKLY MODIFIERS
# ------------------------------------------------------------
const DAILY_MODIFIERS := {
	"cache":   {"icon": "⬡", "name": "CACHE DAY",   "desc": "Caches give 2 upgrades instead of 1",   "color": AMBER},
	"beacon":  {"icon": "◉", "name": "BEACON DAY",  "desc": "Beacons last 2x longer (120s)",          "color": CYAN},
	"ruins":   {"icon": "◬", "name": "RUINS DAY",   "desc": "XP Ruins give 3x XP (instead of 2x)",    "color": PURPLE},
	"station": {"icon": "✚", "name": "STATION DAY", "desc": "Stations also grant a temporary shield", "color": GREEN},
	"hunt":    {"icon": "✦", "name": "HUNT DAY",    "desc": "Elites spawn 2x as often, drop 2x XP",   "color": MAGENTA},
}

const WEEKLY_MODIFIERS := {
	"swarm":    {"icon": "◆", "name": "SWARM WEEK",    "desc": "50% more enemies per wave",            "color": PURPLE},
	"elite":    {"icon": "▲", "name": "ELITE WEEK",    "desc": "All enemies +50% HP, +50% XP",         "color": AMBER},
	"speed":    {"icon": "⚡", "name": "SPEED WEEK",    "desc": "Player +20% speed, enemies +15% speed","color": CYAN},
	"greed":    {"icon": "$", "name": "GREED WEEK",    "desc": "2x score, but -1 max HP",              "color": AMBER},
	"explorer": {"icon": "◈", "name": "EXPLORER WEEK", "desc": "Landmarks 50% more common, boost drain halved", "color": GREEN},
}
