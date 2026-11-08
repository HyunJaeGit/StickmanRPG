extends RefCounted
class_name ProgressStore
## 진행 데이터의 ConfigFile 입출력만 담당합니다. 진행 규칙과 마이그레이션은 게임 컨트롤러가 처리합니다.

const SAVE_PATH := "user://stickman_rpg.cfg"
const SETTINGS_PATH := "user://stickman_settings.cfg"


static func load_progress() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return {"_has_save":false}
	var progress := {"_has_save":true}
	for key in config.get_section_keys("progress"):
		progress[key] = config.get_value("progress", key)
	return progress


static func save_progress(progress: Dictionary) -> Error:
	var config := ConfigFile.new()
	for key in progress:
		config.set_value("progress", str(key), progress[key])
	return config.save(SAVE_PATH)


static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return {"master_volume":80}
	return {
		"master_volume":clampi(int(config.get_value("settings", "master_volume", 80)), 0, 100)
	}


static func save_settings(settings: Dictionary) -> Error:
	var config := ConfigFile.new()
	config.set_value("settings", "master_volume", clampi(int(settings.get("master_volume", 80)), 0, 100))
	return config.save(SETTINGS_PATH)
