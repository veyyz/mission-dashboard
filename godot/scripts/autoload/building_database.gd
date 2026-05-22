extends Node
## Loads `res://data/buildings.json` once at boot and exposes definitions by key.
## Loaders should be **forward-compatible** (tolerate unknown fields) per the
## convention in `data/README.md`.

const BUILDINGS_PATH: String = "res://data/buildings.json"

const SCENE_PATHS := {
	"solar_array":    "res://scenes/buildings/SolarArray.tscn",
	"habitat_module": "res://scenes/buildings/HabitatModule.tscn",
	"mining_drill":   "res://scenes/buildings/MiningDrill.tscn",
	"rtg":            "res://scenes/buildings/RTG.tscn",
	"electrolyzer":   "res://scenes/buildings/Electrolyzer.tscn",
	"hydroponics_bay": "res://scenes/buildings/HydroponicsBay.tscn",
	"storage_silo":   "res://scenes/buildings/StorageSilo.tscn",
	"comms_dish":     "res://scenes/buildings/CommsDish.tscn",
	"research_lab":   "res://scenes/buildings/ResearchLab.tscn",
	"matter_forge":   "res://scenes/buildings/MatterForge.tscn",
}

var _defs: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("[BuildingDatabase] Cannot open %s" % BUILDINGS_PATH)
		return
	var raw: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[BuildingDatabase] %s did not parse to a dictionary" % BUILDINGS_PATH)
		return
	_defs = parsed
	print("[BuildingDatabase] Ready. %d definitions loaded." % _defs.size())


func has_definition(key: String) -> bool:
	return _defs.has(key)


func get_definition(key: String) -> Dictionary:
	return _defs.get(key, {})


func list_keys() -> Array:
	return _defs.keys()


## Phase-5 ships scenes for solar_array, habitat_module, mining_drill.
## Returns an empty string for keys that don't have a scene yet.
func get_scene_path(key: String) -> String:
	return SCENE_PATHS.get(key, "")


func has_scene(key: String) -> bool:
	return SCENE_PATHS.has(key)
