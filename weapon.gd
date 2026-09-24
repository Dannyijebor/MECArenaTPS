extends RefCounted

const RIFLE := "rifle"
const SMG := "smg"
const SHOTGUN := "shotgun"
const ORDER := [RIFLE, SMG, SHOTGUN]

const DATA := {
	RIFLE: {
		"name": "Rifle",
		"cooldown": 0.14,
		"damage": 5,
		"pellets": 1,
		"spread_deg": 1.2,
		"auto_aim_angle": 12.0,
		"mag": 30,
		"reload_time": 1.8,
		"recoil_pitch": 1.1,
		"color": Color(0.30, 0.85, 1.0),
	},
	SMG: {
		"name": "SMG",
		"cooldown": 0.075,
		"damage": 3,
		"pellets": 1,
		"spread_deg": 3.5,
		"auto_aim_angle": 8.0,
		"mag": 40,
		"reload_time": 1.5,
		"recoil_pitch": 0.6,
		"color": Color(1.0, 0.82, 0.30),
	},
	SHOTGUN: {
		"name": "Shotgun",
		"cooldown": 0.75,
		"damage": 4,
		"pellets": 6,
		"spread_deg": 5.5,
		"auto_aim_angle": 5.0,
		"mag": 6,
		"reload_time": 2.4,
		"recoil_pitch": 3.4,
		"color": Color(1.0, 0.42, 0.30),
	},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA[RIFLE])

static func next_id(current: String) -> String:
	var i: int = ORDER.find(current)
	if i < 0:
		return RIFLE
	return ORDER[(i + 1) % ORDER.size()]

static func mag_size(id: String) -> int:
	return int(get_data(id).get("mag", 30))
