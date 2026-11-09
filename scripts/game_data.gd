extends RefCounted
## 무기·스킬·적의 정적 카탈로그와 조정 가능한 기본 밸런스 값.

const STAGE_IDS := ["1-1", "1-2", "1-3", "1-4", "1-5", "2-1"]
const STAGE_ENEMY_COUNTS := {"1-1":24, "1-2":30, "1-3":36, "1-4":42, "1-5":36, "2-1":48}
const BOSS_STAGES := ["1-5"]
const GACHA_COST := 5
const SKILL_GACHA_COST := 3
const MAGIC_SHARD_DROP_CHANCE := 0.04
const MAX_ENHANCEMENT := 20
const ENHANCEMENT_SUCCESS_CHANCES := [100.0, 100.0, 100.0, 100.0, 100.0, 90.0, 85.0, 80.0, 75.0, 70.0, 65.0, 60.0, 55.0, 50.0, 45.0, 40.0, 35.0, 30.0, 25.0, 20.0]
const DASH_SKILL_ID := "dash_impact"
const DASH_COOLDOWN_DURATION := 2.5
const PLAYER_BASE_HEALTH := 82.0
const PLAYER_BASE_SPEED := 190.0
const PLAYER_BASE_DAMAGE := 25.0
const PLAYER_BASE_ATTACK_INTERVAL := 0.82

const RARITY_NAMES := ["일반", "고급", "레어", "유니크", "전설"]
const RARITY_DAMAGE := [1.0, 1.1, 1.22, 1.38, 1.58]
const RARITY_CHANCES := [60, 25, 10, 4, 1]

const WEAPONS := [
	{"id":"pencil_sword", "name":"연필검", "desc":"근접 단일 공격 · 가장 가까운 적 1명", "damage_ratio":1.0, "attack_range":185.0},
	{"id":"ink_orb", "name":"먹물 구슬", "desc":"유도 투사체 · 적 1명", "damage_ratio":1.0, "attack_range":470.0},
	{"id":"orbit_line", "name":"회전 선분", "desc":"근접 회전 공격 · 반경 58 안 적 전체", "damage_ratio":0.8, "attack_range":58.0, "area_radius":58.0, "area_center":"player"},
	{"id":"ruler_spear", "name":"자 대검", "desc":"직선 관통 공격 · 궤적 위 적 전체", "damage_ratio":1.25, "attack_range":340.0},
	{"id":"brush_burst", "name":"붓 폭발탄", "desc":"부채꼴 3발 발사 · 발당 피해", "damage_ratio":0.55, "attack_range":425.0},
	{"id":"eraser_bomb", "name":"지우개 폭탄", "desc":"지연 폭발 · 반경 78 안 적 전체", "damage_ratio":1.55, "attack_range":470.0, "area_radius":78.0, "area_center":"target"},
	{"id":"paper_plane", "name":"종이비행기", "desc":"투척 후 귀환 · 첫 적 1명", "damage_ratio":0.9, "attack_range":470.0},
	{"id":"compass_spear", "name":"컴퍼스 창", "desc":"직선 관통 · 궤적 위 적 전체", "damage_ratio":1.65, "attack_range":390.0},
	{"id":"stamp_fist", "name":"도장 주먹", "desc":"범위 타격 · 목표 반경 88 안 적 전체", "damage_ratio":1.3, "attack_range":470.0, "area_radius":88.0, "area_center":"target"}
]

const POTENTIALS := [
	{"id":"attack", "name":"공격력", "min":3, "max":8},
	{"id":"boss_damage", "name":"보스 몬스터 피해", "min":5, "max":12},
	{"id":"attack_speed", "name":"공격 속도", "min":2, "max":6},
	{"id":"gold_gain", "name":"골드 획득량", "min":5, "max":12},
	{"id":"fragment_find", "name":"무기 조각 발견률", "min":1, "max":3},
	{"id":"max_health", "name":"최대 체력", "min":5, "max":10},
	{"id":"move_speed", "name":"이동 속도", "min":2, "max":5}
]

const SKILLS := [
	{"id":"ink_wave", "name":"잉크 파동", "role":"범위 공격", "description":"반경 140 안 적 전체", "icon":0, "cooldown":18.0, "cast_time":0.35, "radius":140.0, "damage_ratio":1.2},
	{"id":"compass_pierce", "name":"컴퍼스 관통", "role":"단일 공격", "description":"가장 가까운 적 1명", "icon":1, "cooldown":14.0, "cast_time":0.45, "damage_ratio":3.0},
	{"id":"lifeline", "name":"생명선", "role":"회복", "description":"최대 체력 비례 회복", "icon":2, "cooldown":40.0, "cast_time":0.35, "heal_ratio":0.3},
	{"id":"final_ink", "name":"종말의 획", "role":"단일 공격", "description":"집중 후 가장 가까운 적 1명", "icon":3, "cooldown":60.0, "cast_time":1.0, "charge_time":1.0, "damage_ratio":7.0},
	{"id":DASH_SKILL_ID, "name":"질주 충격", "role":"패시브", "description":"Space 대시 경로의 적 전체", "icon":-1, "passive":true, "damage_ratio":1.35}
]

const ENEMY_DATA := {
	"chaser": {"hp":44.0, "speed":58.0, "damage":12.0, "radius":13.0, "color":Color("33302b")},
	"charger": {"hp":76.0, "speed":47.0, "damage":19.0, "radius":15.0, "color":Color("704d37")},
	"thrower": {"hp":59.0, "speed":36.0, "damage":11.0, "radius":14.0, "color":Color("526e68")},
	"elite": {"hp":380.0, "speed":41.0, "damage":25.0, "radius":23.0, "color":Color("a74235")}
}
