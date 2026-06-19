class_name WeaponSystem
extends Node2D

## Run-scoped Survivor-style loadout. All equipped weapons update concurrently.
## Main owns collision/damage; this node owns loadout progression and firing.

var main = null
var weapons: Array = [] # [{id, level, evolved}]
var passives := {}      # id -> level
var cooldowns := {}     # weapon id -> seconds
var volley_counts := {}
var merged := {}        # merge id -> true
var merge_cooldowns := {}
var orbit_angle := 0.0
var rail_charge := 0.0

const MAX_WEAPONS := 4
const MAX_PASSIVES := 4

func reset_run() -> void:
	weapons = [{"id": "pulse", "level": 1, "evolved": ""}]
	passives = {}
	cooldowns = {}
	volley_counts = {}
	merged = {}
	merge_cooldowns = {}
	orbit_angle = 0.0
	rail_charge = 0.0
	queue_redraw()

func update(dt: float) -> void:
	if main == null or main.player == null:
		return
	position = main.player.position
	orbit_angle = fmod(orbit_angle + dt * 3.0, TAU)
	for entry in weapons:
		if entry.get("disabled", false):
			continue
		var id: String = entry.id
		cooldowns[id] = cooldowns.get(id, 0.0) - dt
		if cooldowns[id] <= 0.0:
			_fire(entry)
			cooldowns[id] += _interval(entry)
	_update_merges(dt)
	_update_shields(dt)
	queue_redraw()

func movement_multiplier() -> float:
	for entry in weapons:
		if not entry.get("disabled", false) and entry.id == "rail" and cooldowns.get("rail", 0.0) <= 0.15:
			return 0.4
	return 1.0

func _entry(id: String):
	for entry in weapons:
		if entry.id == id:
			return entry
	return null

func _stat(entry: Dictionary, key: String, fallback := 0.0):
	var def: Dictionary = Data.SURVIVOR_WEAPONS[entry.id]
	if not def.has(key):
		return fallback
	var value = def[key]
	if value is Array:
		return value[clampi(entry.level - 1, 0, value.size() - 1)]
	return value

func _passive_mult(effect: String) -> float:
	var total := 0.0
	for id in passives:
		var p: Dictionary = Data.PASSIVES[id]
		if p.effect == effect:
			total += float(passives[id]) * p.per_level
	return 1.0 + total

func _damage_mult() -> float:
	return (1.0 + main.upgrades.damage) * _passive_mult("damage")

func _rate_mult() -> float:
	return (1.0 + main.upgrades.fireRate) * _passive_mult("fire_rate")

func _interval(entry: Dictionary) -> float:
	if entry.id == "rail":
		var charge: float = 0.5 if entry.evolved == "annihilator" else _stat(entry, "charge", 1.5)
		charge *= max(0.35, 2.0 - _passive_mult("charge"))
		return charge
	return 1.0 / max(0.05, float(_stat(entry, "rate", 1.0)) * _rate_mult())

func _target(from: Vector2):
	return main._nearest_target(from)

func _fire(entry: Dictionary) -> void:
	match entry.id:
		"pulse": _fire_pulse(entry)
		"plasma": _fire_plasma(entry)
		"nova": _fire_nova(entry)
		"drones": _fire_drones(entry)
		"gravity": _fire_gravity(entry)
		"missiles": _fire_missiles(entry)
		"shield": _fire_satellites(entry)
		"rail": _fire_rail(entry)
	Audio.shoot("pulse" if entry.id in ["drones", "shield"] else entry.id)

func _base_angle(from: Vector2, projectile_speed: float = 720.0, inherit_factor: float = 0.65) -> float:
	var target = _target(from)
	if target == null:
		return main.player.aim_angle
	var target_vel := Vector2.ZERO
	if "vel" in target:
		target_vel = target.vel
	var inherited: Vector2 = main.player.vel * inherit_factor
	var relative_pos: Vector2 = target.position - from
	var relative_vel: Vector2 = target_vel - inherited
	var a: float = relative_vel.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * relative_pos.dot(relative_vel)
	var c: float = relative_pos.length_squared()
	var intercept_time := -1.0
	if absf(a) < 0.001:
		if absf(b) > 0.001:
			intercept_time = -c / b
	else:
		var disc: float = b * b - 4.0 * a * c
		if disc >= 0.0:
			var root: float = sqrt(disc)
			var t1: float = (-b - root) / (2.0 * a)
			var t2: float = (-b + root) / (2.0 * a)
			if t1 > 0.0 and t2 > 0.0:
				intercept_time = minf(t1, t2)
			elif t1 > 0.0:
				intercept_time = t1
			elif t2 > 0.0:
				intercept_time = t2
	if intercept_time > 0.0 and intercept_time < 3.0:
		return (relative_pos + relative_vel * intercept_time).angle()
	return relative_pos.angle()

func _spawn_projectile(from: Vector2, angle: float, speed: float, damage: float, size: float,
		color: Color, inherit_factor: float = 0.65) -> Bullet:
	var b := Bullet.new()
	b.friendly = true
	b.position = from
	b.prev_position = from
	b.vel = Vector2.from_angle(angle) * speed + main.player.vel * inherit_factor
	b.damage = damage * _damage_mult()
	b.size = size
	b.color = color
	b.life = 2.5
	b.z_index = 15
	main.world.add_child(b)
	main.bullets.append(b)
	return b

func _fire_pulse(entry: Dictionary) -> void:
	var speed := 1100.0 if entry.evolved == "triple_beam" else float(_stat(entry, "speed"))
	var angle := _base_angle(main.player.position, speed)
	var count := 3 if entry.evolved == "triple_beam" else (2 if entry.level >= 5 else 1)
	var damage := 20.0 if entry.evolved == "triple_beam" else float(_stat(entry, "damage"))
	for i in count:
		var off := (i - (count - 1) / 2.0) * 0.13
		var b := _spawn_projectile(main.player.position, angle + off, speed, damage, 4.0, Data.CYAN)
		b.weapon_id = "pulse"
		if entry.evolved == "triple_beam":
			b.pierce = 99
			b.is_beam = true

func _fire_plasma(entry: Dictionary) -> void:
	var angle := _base_angle(main.player.position, 400.0)
	var count := 2 if entry.level >= 5 else 1
	for i in count:
		var b := _spawn_projectile(main.player.position, angle + (i - (count - 1) / 2.0) * 0.14,
			400.0, 100.0 if entry.evolved == "supernova" else _stat(entry, "damage"), 9.0, Data.MAGENTA)
		b.weapon_id = "plasma"
		b.splash_radius = (150.0 if entry.evolved == "supernova" else _stat(entry, "radius")) * _passive_mult("splash")
		b.knockback = 90.0 if entry.level >= 3 else 0.0
		if entry.evolved == "supernova":
			b.burn_dps = 20.0
			b.burn_duration = 2.0

func _fire_nova(entry: Dictionary) -> void:
	var rings := 2 if entry.level >= 5 and entry.evolved == "" else 1
	for i in rings:
		var b := _spawn_projectile(main.player.position, 0.0, 0.0,
			30.0 if entry.evolved == "quasar" else _stat(entry, "damage"), 3.0, Data.AMBER, 0.0)
		b.weapon_id = "nova"
		b.is_ring = true
		b.ring_max_radius = 250.0 if entry.evolved == "quasar" else _stat(entry, "radius")
		b.ring_speed = 85.0 if entry.evolved == "quasar" else 400.0
		b.life = 3.0 if entry.evolved == "quasar" else b.ring_max_radius / b.ring_speed
		b.field_dps = 30.0 if entry.evolved == "quasar" else 0.0
		b.knockback = 50.0 if entry.level >= 3 else 0.0
		if i > 0:
			b.life += 0.2

func _orbital_position(index: int, count: int, radius: float = 80.0) -> Vector2:
	var a: float = orbit_angle + float(index) / max(1, count) * TAU
	return main.player.position + Vector2.from_angle(a) * radius

func _fire_drones(entry: Dictionary) -> void:
	var count: int = _stat(entry, "count", 2)
	var damage: float = 15.0 if entry.evolved == "wingfleet" else _stat(entry, "damage")
	damage *= _passive_mult("drone")
	for i in count:
		var pos: Vector2 = _orbital_position(i, count)
		var b := _spawn_projectile(pos, _base_angle(pos, 760.0), 760.0, damage, 3.0, Data.CYAN_SOFT)
		b.weapon_id = "drones"
		if entry.level >= 3: b.pierce = 1
		if entry.level >= 5:
			b.homing_turn_rate = 1.5
			b.target = _target(pos)
	# Wingfleet copies a restrained pulse from slot one; it deliberately does
	# not recursively clone evolutions or deployables.
	if entry.evolved == "wingfleet" and not weapons.is_empty():
		for i in count:
			var pos: Vector2 = _orbital_position(i, count)
			var b := _spawn_projectile(pos, _base_angle(pos, 850.0), 850.0, 8.0, 3.0, Data.WHITE)
			b.weapon_id = "wingfleet_copy"

func _fire_gravity(entry: Dictionary) -> void:
	var evolved: bool = entry.evolved == "event_horizon"
	var b := _spawn_projectile(main.player.position, 0.0, 0.0,
		40.0 if evolved else _stat(entry, "damage"), 8.0, Data.PURPLE, 0.0)
	b.weapon_id = "gravity"
	b.is_singularity = true
	b.singularity_activated = true
	b.singularity_radius = (200.0 if evolved else _stat(entry, "radius")) * _passive_mult("area")
	b.singularity_duration = (6.0 if evolved else _stat(entry, "duration")) * _passive_mult("area")
	b.singularity_pull = 520.0 if evolved else 220.0
	b.life = b.singularity_duration
	b.destroys_enemy_bullets = evolved or entry.level >= 5
	b.detonation_damage = 200.0 if evolved else 50.0
	b.detonation_radius = 100.0 if evolved else 60.0

func _fire_missiles(entry: Dictionary) -> void:
	var count: int = 6 if entry.evolved == "barrage" else int(_stat(entry, "count", 1))
	volley_counts.missiles = volley_counts.get("missiles", 0) + 1
	for i in count:
		var angle: float = main.player.aim_angle + (i - (count - 1) / 2.0) * 0.15
		var b := _spawn_projectile(main.player.position, angle, 420.0,
			50.0 if entry.evolved == "barrage" else _stat(entry, "damage"), 6.0, Data.GOLD)
		b.weapon_id = "missiles"
		b.target = _target(b.position)
		b.homing_turn_rate = (6.0 if entry.evolved == "barrage" else 3.0) * _passive_mult("homing")
		b.splash_radius = (60.0 if entry.evolved == "barrage" else _stat(entry, "radius")) * _passive_mult("splash")
		if entry.level >= 5: b.pierce = 1
	if entry.evolved == "barrage" and volley_counts.missiles % 5 == 0:
		var mega := _spawn_projectile(main.player.position, _base_angle(main.player.position, 330.0),
			330.0, 300.0, 12.0, Data.MAGENTA)
		mega.weapon_id = "mega_missile"
		mega.target = _target(mega.position)
		mega.homing_turn_rate = 5.0
		mega.splash_radius = 150.0

func _fire_satellites(entry: Dictionary) -> void:
	var count: int = 4 if entry.evolved == "aegis" else int(_stat(entry, "count", 1))
	for i in count:
		var pos: Vector2 = _orbital_position(i, count)
		var b := _spawn_projectile(pos, _base_angle(pos, 900.0), 900.0,
			5.0 if entry.evolved == "aegis" else _stat(entry, "damage"), 3.0, Data.GREEN)
		b.weapon_id = "shield"
		if entry.evolved == "aegis": b.pierce = 3

func _fire_rail(entry: Dictionary) -> void:
	var evolved: bool = entry.evolved == "annihilator"
	var b := _spawn_projectile(main.player.position, _base_angle(main.player.position, 2000.0), 2000.0,
		200.0 if evolved else _stat(entry, "damage"), 20.0 if evolved else _stat(entry, "width"), Data.AMBER_SOFT)
	b.weapon_id = "rail"
	b.pierce = 99
	b.is_beam = true
	b.life = 0.8
	b.boss_damage_mult = 2.0 if entry.level >= 5 else 1.0
	b.shield_break = evolved

func _update_merges(dt: float) -> void:
	for id in merged:
		merge_cooldowns[id] = merge_cooldowns.get(id, 0.0) - dt
		if merge_cooldowns[id] > 0.0:
			continue
		match id:
			"genesis_ray":
				_fire_genesis()
				merge_cooldowns[id] = 0.16
			"big_bang":
				_fire_big_bang()
				merge_cooldowns[id] = 8.0
			"arsenal_fleet":
				_fire_arsenal()
				merge_cooldowns[id] = 0.34
			"judgement":
				_fire_judgement()
				merge_cooldowns[id] = 2.0
			"phalanx_array":
				_fire_phalanx()
				merge_cooldowns[id] = 0.18
			"singularity_barrage":
				_fire_singularity_barrage()
				merge_cooldowns[id] = 0.4

func _fire_genesis() -> void:
	var angle := _base_angle(main.player.position, 1200.0)
	for i in 3:
		var b := _spawn_projectile(main.player.position, angle + (i - 1) * 0.13, 1200.0, 20.0, 5.0, Data.WHITE)
		b.weapon_id = "genesis_ray"
		b.pierce = 99
		b.is_beam = true
		b.splash_radius = 100.0

func _fire_big_bang() -> void:
	var b := _spawn_projectile(main.player.position, 0.0, 0.0, 50.0, 12.0, Data.PURPLE, 0.0)
	b.weapon_id = "big_bang"
	b.is_singularity = true
	b.singularity_activated = true
	b.singularity_radius = 300.0
	b.singularity_duration = 8.0
	b.singularity_pull = 650.0
	b.destroys_enemy_bullets = true
	b.life = 8.0

func _fire_arsenal() -> void:
	for drone in 4:
		var pos := _orbital_position(drone, 4)
		for missile in 3:
			var b := _spawn_projectile(pos, _base_angle(pos, 460.0) + (missile - 1) * 0.13,
				460.0, 50.0, 5.0, Data.GOLD)
			b.weapon_id = "arsenal_fleet"
			b.target = _target(pos)
			b.homing_turn_rate = 7.0
			b.splash_radius = 60.0

func _fire_judgement() -> void:
	for i in 4:
		var pos: Vector2 = _orbital_position(i, 4)
		var b := _spawn_projectile(pos, _base_angle(pos, 2100.0), 2100.0, 200.0, 16.0, Data.AMBER_SOFT)
		b.weapon_id = "judgement"
		b.pierce = 99
		b.is_beam = true
		b.boss_damage_mult = 2.0
		b.shield_break = true

func _fire_phalanx() -> void:
	var angle: float = _base_angle(main.player.position, 1200.0)
	for origin in 5:
		var pos: Vector2 = main.player.position if origin == 0 else _orbital_position(origin - 1, 4)
		for beam in 3:
			var b := _spawn_projectile(pos, angle + (beam - 1) * 0.13, 1200.0, 20.0, 4.0, Data.CYAN)
			b.weapon_id = "phalanx_array"
			b.pierce = 99
			b.is_beam = true

func _fire_singularity_barrage() -> void:
	for i in 6:
		var b := _spawn_projectile(main.player.position, main.player.aim_angle + (i - 2.5) * 0.14,
			430.0, 50.0, 6.0, Data.PURPLE)
		b.weapon_id = "singularity_barrage"
		b.target = _target(b.position)
		b.homing_turn_rate = 6.0
		b.is_singularity = true
		b.singularity_radius = 60.0
		b.singularity_duration = 1.0
		b.singularity_pull = 280.0

func _update_shields(_dt: float) -> void:
	var entry = _entry("shield")
	if entry == null:
		return
	var count: int = 4 if entry.evolved == "aegis" else int(_stat(entry, "count", 1))
	var arc_deg: float = 180.0 if entry.evolved == "aegis" else float(_stat(entry, "arc", 90.0)) * _passive_mult("shield")
	for bullet in main.enemy_bullets:
		if bullet.hit:
			continue
		for i in count:
			var sat: Vector2 = _orbital_position(i, count)
			var rel: Vector2 = bullet.position - main.player.position
			var sat_rel: Vector2 = sat - main.player.position
			if abs(rel.length() - 80.0) <= bullet.size + 7.0:
				var delta: float = abs(wrapf(rel.angle() - sat_rel.angle(), -PI, PI))
				if delta <= deg_to_rad(arc_deg * 0.5):
					bullet.hit = true
					if entry.level >= 3:
						var chance: float = 1.0 if entry.evolved == "aegis" else (0.5 if entry.level >= 5 else 0.25)
						if randf() <= chance:
							var reflected := _spawn_projectile(sat, (sat - main.player.position).angle(), bullet.vel.length(),
								bullet.damage if entry.evolved == "aegis" else bullet.damage * 0.5, bullet.size, Data.GREEN)
							reflected.reflected = true
					break

func get_cards() -> Array:
	var guaranteed: Array = []
	var pool: Array = []
	for entry in weapons:
		if entry.get("disabled", false):
			continue
		var def: Dictionary = Data.SURVIVOR_WEAPONS[entry.id]
		if entry.level < 5:
			pool.append(_card("weapon_up", entry.id, def.icon, "%s LV%d" % [def.name, entry.level + 1],
				"Upgrade equipped weapon", "common"))
		elif entry.evolved == "" and passives.get(def.passive, 0) >= 5:
			var evo: Dictionary = Data.EVOLUTIONS[def.evolution]
			guaranteed.append(_card("evolve", entry.id, evo.icon, evo.name, "EVOLVE " + def.name, "rare"))
	if weapons.size() < MAX_WEAPONS:
		for id in Data.SURVIVOR_WEAPONS:
			if _entry(id) == null:
				var def: Dictionary = Data.SURVIVOR_WEAPONS[id]
				pool.append(_card("weapon_new", id, def.icon, def.name, "Install weapon at Level 1", "rare"))
	for id in passives:
		if passives[id] < 5:
			var p: Dictionary = Data.PASSIVES[id]
			pool.append(_card("passive_up", id, p.icon, "%s LV%d" % [p.name, passives[id] + 1],
				"Increase universal %s bonus" % p.effect, "common"))
	if passives.size() < MAX_PASSIVES:
		for id in Data.PASSIVES:
			if not passives.has(id):
				var p: Dictionary = Data.PASSIVES[id]
				pool.append(_card("passive_new", id, p.icon, p.name, "Install passive at Level 1", "common"))
	for recipe in Data.MERGE_RECIPES:
		if merged.has(recipe.id):
			continue
		var a = _entry_by_evolution(recipe.a)
		var b = _entry_by_evolution(recipe.b)
		if a != null and b != null and not a.get("disabled", false) and not b.get("disabled", false):
			guaranteed.append(_card("merge", recipe.id, "✦", recipe.name,
				"MERGE two evolved weapons (occupies both slots)", "rare"))
	var choices: Array = []
	if not guaranteed.is_empty():
		choices.append(guaranteed.pick_random())
	pool.shuffle()
	for card in pool:
		if choices.size() >= 3: break
		if not choices.any(func(c): return c.id == card.id):
			choices.append(card)
	return choices

func _card(kind: String, id: String, icon: String, name: String, desc: String, rarity: String) -> Dictionary:
	return {"kind": kind, "id": kind + ":" + id, "target_id": id, "icon": icon,
		"name": name, "desc": desc, "rarity": rarity}

func apply_card(card: Dictionary) -> bool:
	var id: String = card.target_id
	match card.kind:
		"weapon_new":
			if weapons.size() >= MAX_WEAPONS or _entry(id) != null: return false
			weapons.append({"id": id, "level": 1, "evolved": ""})
		"weapon_up":
			var entry = _entry(id)
			if entry == null or entry.level >= 5: return false
			entry.level += 1
		"passive_new":
			if passives.size() >= MAX_PASSIVES or passives.has(id): return false
			passives[id] = 1
		"passive_up":
			if not passives.has(id) or passives[id] >= 5: return false
			passives[id] += 1
		"evolve":
			var entry = _entry(id)
			if entry == null or entry.level < 5: return false
			entry.evolved = Data.SURVIVOR_WEAPONS[id].evolution
		"merge":
			var recipe: Dictionary = {}
			for candidate in Data.MERGE_RECIPES:
				if candidate.id == id:
					recipe = candidate
					break
			if recipe.is_empty(): return false
			var a = _entry_by_evolution(recipe.a)
			var b = _entry_by_evolution(recipe.b)
			if a == null or b == null: return false
			a.disabled = true
			b.disabled = true
			merged[id] = true
		_:
			return false
	queue_redraw()
	return true

func summary() -> String:
	var names: Array[String] = []
	for entry in weapons:
		if entry.get("disabled", false):
			continue
		var label: String = Data.SURVIVOR_WEAPONS[entry.id].name
		if entry.evolved != "":
			label = Data.EVOLUTIONS[entry.evolved].name
		else:
			label += " %d" % entry.level
		names.append(label)
	for id in merged:
		for recipe in Data.MERGE_RECIPES:
			if recipe.id == id:
				names.append(recipe.name)
	return "  •  ".join(names)

func _entry_by_evolution(evolution_id: String):
	for entry in weapons:
		if entry.evolved == evolution_id:
			return entry
	return null

func _draw() -> void:
	if main == null or main.player == null:
		return
	var drone = _entry("drones")
	if drone != null:
		var count: int = _stat(drone, "count", 2)
		for i in count:
			var local := _orbital_position(i, count) - position
			Neon.glow_dot(self, local, 6.0, Data.CYAN_SOFT)
			draw_circle(local, 2.0, Data.WHITE)
	var shield = _entry("shield")
	if shield != null:
		var count := 4 if shield.evolved == "aegis" else int(_stat(shield, "count", 1))
		var arc := deg_to_rad(180.0 if shield.evolved == "aegis" else float(_stat(shield, "arc", 90.0)))
		for i in count:
			var local := _orbital_position(i, count) - position
			Neon.glow_dot(self, local, 7.0, Data.GREEN)
			var a := local.angle()
			draw_arc(Vector2.ZERO, 80.0, a - arc * 0.5, a + arc * 0.5, 20, Color(Data.GREEN, 0.65), 2.0)
