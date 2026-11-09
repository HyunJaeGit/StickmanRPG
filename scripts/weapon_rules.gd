extends RefCounted
class_name WeaponRules
## 무기 카피와 잠재능력에서 전투 능력치·성장 비용을 계산합니다.

const GAME_DATA = preload("res://scripts/game_data.gd")


static func enhancement_cost(item: Dictionary) -> int:
	var level := int(item.get("enhancement", 0))
	var rarity := int(item.get("rarity", 0))
	return 50 * (level + 1) * (level + 1) * (rarity + 1)


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
	return GAME_DATA.PLAYER_BASE_DAMAGE * float(GAME_DATA.RARITY_DAMAGE[rarity]) * pow(1.1, float(enhancement)) * (1.0 + attack_bonus / 100.0)


static func max_health(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_HEALTH * (1.0 + potential_total(item, "max_health") / 100.0)


static func move_speed(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_SPEED * (1.0 + potential_total(item, "move_speed") / 100.0)


static func attack_interval(item: Dictionary) -> float:
	return GAME_DATA.PLAYER_BASE_ATTACK_INTERVAL * 100.0 / (100.0 + potential_total(item, "attack_speed"))
