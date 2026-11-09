extends RefCounted
class_name WeaponRules
## 무기 카피와 잠재능력에서 전투 능력치·성장 비용을 계산합니다.

const GAME_DATA = preload("res://scripts/game_data.gd")


static func enhancement_cost(item: Dictionary) -> int:
	var level := int(item.get("enhancement", 0))
	var rarity := int(item.get("rarity", 0))
	var base_cost := 50 * (level + 1) * (level + 1) * (rarity + 1)
	var weapon := _weapon_profile(str(item.get("weapon_id", "")))
	var cost_multiplier := float(weapon.get("enhancement_cost_multiplier", 1.0))
	return maxi(1, roundi(float(base_cost) * cost_multiplier))


static func enhancement_success_chance(level: int) -> float:
	if GAME_DATA.ENHANCEMENT_SUCCESS_CHANCES.is_empty():
		return 100.0
	var chance_index := clampi(level, 0, GAME_DATA.ENHANCEMENT_SUCCESS_CHANCES.size() - 1)
	return float(GAME_DATA.ENHANCEMENT_SUCCESS_CHANCES[chance_index])


static func potential_reset_cost(item: Dictionary) -> int:
	return 100 * (int(item.get("rarity", 0)) + 1)


static func potential_total(item: Dictionary, potential_id: String) -> float:
	var total := 0.0
	for potential in item.get("potentials", []):
		if str(potential.get("id", "")) == potential_id:
			total += float(potential.get("value", 0))
	return total


static func attack_power(item: Dictionary) -> float:
	var rarity := clampi(int(item.get("rarity", 0)), 0, GAME_DATA.RARITY_DAMAGE.size() - 1)
	var enhancement := clampi(int(item.get("enhancement", 0)), 0, GAME_DATA.MAX_ENHANCEMENT)
	var attack_bonus := potential_total(item, "attack")
	var weapon := _weapon_profile(str(item.get("weapon_id", "")))
	var base_damage_multiplier := float(weapon.get("base_damage_multiplier", 1.0))
	return GAME_DATA.PLAYER_BASE_DAMAGE * base_damage_multiplier * float(GAME_DATA.RARITY_DAMAGE[rarity]) * pow(1.1, float(enhancement)) * (1.0 + attack_bonus / 100.0)


static func max_health(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_HEALTH * (1.0 + potential_total(item, "max_health") / 100.0)


static func move_speed(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_SPEED * (1.0 + potential_total(item, "move_speed") / 100.0)


static func attack_interval(item: Dictionary) -> float:
	var weapon := _weapon_profile(str(item.get("weapon_id", "")))
	var interval_multiplier := float(weapon.get("attack_interval_multiplier", 1.0))
	return GAME_DATA.PLAYER_BASE_ATTACK_INTERVAL * interval_multiplier * 100.0 / (100.0 + potential_total(item, "attack_speed"))


static func _weapon_profile(weapon_id: String) -> Dictionary:
	for weapon in GAME_DATA.WEAPONS:
		if str(weapon.get("id", "")) == weapon_id:
			return weapon
	return {}
