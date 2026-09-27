extends RefCounted
class_name CharacterDB

const ORDER := ["SWAT", "AJ", "CH39", "MARIA", "HEAVY"]

const DATA := {
	"SWAT": {
		"label": "VECTOR",
		"blurb": "Versatile - no weaknesses",
		"path": "res://models/avatars/swat.glb",
		"hp_mult": 1.0,
		"speed_mult": 1.0,
		"dmg_mult": 1.0,
		"regen_delay_mult": 1.0,
		"regen_rate_mult": 1.0,
		"heal_bonus": 0,
		"ability": "FOCUS", "ability_desc": "Infinite ammo + 40% faster fire", "ability_color": Color(0.30, 0.65, 1.0),
		"color": Color(0.30, 0.65, 1.0),
	},
	"AJ": {
		"label": "WRAITH",
		"blurb": "Blitz scout - fastest on the field",
		"path": "res://models/avatars/characters/aj.fbx",
		"hp_mult": 0.80,
		"speed_mult": 1.25,
		"dmg_mult": 1.0,
		"regen_delay_mult": 0.8,
		"regen_rate_mult": 1.2,
		"heal_bonus": 0,
		"ability": "BLITZ", "ability_desc": "Massive speed burst + jump boost", "ability_color": Color(1.0, 0.85, 0.30),
		"color": Color(1.0, 0.85, 0.30),
	},
	"CH39": {
		"label": "ANVIL",
		"blurb": "Fortress - built to absorb fire",
		"path": "res://models/avatars/characters/ch39.fbx",
		"hp_mult": 1.50,
		"speed_mult": 0.75,
		"dmg_mult": 1.0,
		"regen_delay_mult": 1.2,
		"regen_rate_mult": 0.8,
		"heal_bonus": 0,
		"ability": "IRONHIDE", "ability_desc": "Immune to damage", "ability_color": Color(0.85, 0.45, 0.20),
		"color": Color(0.85, 0.45, 0.20),
	},
	"MARIA": {
		"label": "ORACLE",
		"blurb": "Support - rapid recovery",
		"path": "res://models/avatars/characters/maria.fbx",
		"hp_mult": 1.0,
		"speed_mult": 1.05,
		"dmg_mult": 0.9,
		"regen_delay_mult": 0.35,
		"regen_rate_mult": 2.5,
		"heal_bonus": 30,
		"ability": "REJUVENATE", "ability_desc": "Instant full heal", "ability_color": Color(0.85, 0.55, 0.95),
		"color": Color(0.85, 0.55, 0.95),
	},
	"HEAVY": {
		"label": "REAVER",
		"blurb": "Juggernaut - devastating firepower",
		"path": "res://models/avatars/characters/boss.fbx",
		"hp_mult": 1.1,
		"speed_mult": 0.9,
		"dmg_mult": 1.35,
		"regen_delay_mult": 1.0,
		"regen_rate_mult": 1.0,
		"heal_bonus": 0,
		"ability": "OVERDRIVE", "ability_desc": "3x weapon damage", "ability_color": Color(0.75, 0.20, 0.25),
		"color": Color(0.75, 0.20, 0.25),
	},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["SWAT"])

static func next_id(current: String) -> String:
	var i: int = ORDER.find(current)
	if i < 0:
		return "SWAT"
	return ORDER[(i + 1) % ORDER.size()]
