class_name BossCatalog
extends RefCounted

const ORDER := [
	"conductor", "spiral", "warden", "stalker", "sentry",
	"summoner", "bomber", "mirror", "weaver", "tide",
	"golem", "phantom", "architect", "storm", "colossus",
]

const SUPPORTED := ["conductor", "spiral", "warden", "stalker", "sentry", "summoner", "bomber"]

const DEFINITIONS := {
	"conductor": {"name": "THE CONDUCTOR", "hp": 700.0, "size": 38.0, "difficulty": "MEDIUM"},
	"spiral": {"name": "THE SPIRAL", "hp": 850.0, "size": 32.0, "difficulty": "HARD"},
	"warden": {"name": "THE WARDEN", "hp": 1200.0, "size": 40.0, "speed": 50.0, "difficulty": "MEDIUM"},
	"stalker": {"name": "THE STALKER", "hp": 350.0, "size": 26.0, "speed": 130.0, "difficulty": "HARD"},
	"sentry": {"name": "THE SENTRY", "hp": 400.0, "size": 30.0, "speed": 30.0, "difficulty": "MEDIUM"},
	"summoner": {"name": "THE SUMMONER", "hp": 420.0, "size": 30.0, "speed": 40.0, "difficulty": "HARD"},
	"bomber": {"name": "THE BOMBER", "hp": 240.0, "size": 28.0, "speed": 90.0, "difficulty": "MEDIUM"},
	"mirror": {"name": "THE MIRROR", "hp": 500.0, "size": 32.0, "speed": 60.0, "difficulty": "HARD"},
	"weaver": {"name": "THE WEAVER", "hp": 600.0, "size": 34.0, "speed": 35.0, "difficulty": "HARD"},
	"tide": {"name": "THE TIDE", "hp": 650.0, "size": 36.0, "speed": 50.0, "difficulty": "HARD"},
	"golem": {"name": "THE GOLEM", "hp": 900.0, "size": 42.0, "speed": 40.0, "difficulty": "VERY HARD"},
	"phantom": {"name": "THE PHANTOM", "hp": 550.0, "size": 30.0, "speed": 100.0, "difficulty": "VERY HARD"},
	"architect": {"name": "THE ARCHITECT", "hp": 700.0, "size": 36.0, "speed": 50.0, "difficulty": "HARD"},
	"storm": {"name": "THE STORM", "hp": 600.0, "size": 34.0, "speed": 45.0, "difficulty": "VERY HARD"},
	"colossus": {"name": "THE COLOSSUS", "hp": 1500.0, "size": 60.0, "speed": 20.0, "difficulty": "NIGHTMARE"},
}

static func id_for_encounter(encounter_number: int) -> String:
	var unlocked: int = mini(SUPPORTED.size(), 2 + encounter_number)
	return SUPPORTED[(encounter_number - 1) % max(1, unlocked)]

static func scaled_hp(id: String, wave: int) -> float:
	var base: float = DEFINITIONS[id].hp
	return round(base * (1.0 + wave * 0.2))
