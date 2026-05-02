extends Node
## Phase-8 recipe processor. Polls active recipes (loaded from
## `data/recipes.json`) and runs them whenever:
##   1. A building of the recipe's `building` type is in the "buildings" group
##   2. ResourceManager has all the recipe's input resources available
## On each successful cycle, deducts inputs and adds outputs to ResourceManager.
## Emits `EventBus.log_message` per cycle for player feedback.

const RECIPES_PATH: String = "res://data/recipes.json"

var _recipes: Dictionary = {}
var _timers: Dictionary = {}  # recipe_key → seconds until next cycle


func _ready() -> void:
	var f := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	if f == null:
		push_error("[RecipeProcessor] cannot open %s" % RECIPES_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[RecipeProcessor] data not a dict")
		return
	for key in parsed.keys():
		if key.begins_with("_"):
			continue
		var recipe: Dictionary = parsed[key]
		# Phase-8 scope: process recipes with explicit input/output dicts.
		# Extraction recipes (`input_resource: <node_type>`) are wired in
		# alongside resource node interaction in a later polish pass.
		if not (recipe.has("input") and recipe.has("output")):
			continue
		_recipes[key] = recipe
		_timers[key] = float(recipe.get("duration_seconds", 5.0))
	print("[RecipeProcessor] Ready. %d recipes loaded." % _recipes.size())


func _process(delta: float) -> void:
	if GameState != null and GameState.is_paused:
		return
	var time_scale: float = TimeManager.time_scale if TimeManager else 1.0
	if time_scale <= 0.0:
		return
	for key in _recipes.keys():
		var recipe: Dictionary = _recipes[key]
		var building_key: String = recipe.get("building", recipe.get("required_building", ""))
		if not _has_building(building_key):
			continue
		_timers[key] -= delta * time_scale
		if _timers[key] <= 0.0:
			_timers[key] = float(recipe.get("duration_seconds", 5.0))
			_try_run(key, recipe)


## Runs one cycle. Returns true if the cycle ran (inputs available, outputs
## applied). Public so tests can drive it deterministically without timers.
func try_run(key: String) -> bool:
	if not _recipes.has(key):
		return false
	return _try_run(key, _recipes[key])


func _try_run(key: String, recipe: Dictionary) -> bool:
	var input: Dictionary = recipe.get("input", {})
	if not ResourceManager.can_afford(input):
		return false
	if not ResourceManager.deduct(input):
		return false
	var output: Dictionary = recipe.get("output", {})
	for r_name in output.keys():
		ResourceManager.add(r_name, float(output[r_name]))
	EventBus.log_message.emit(
		"Recipe '%s' completed cycle" % recipe.get("display_name", key),
		"build",
	)
	return true


func _has_building(building_key: String) -> bool:
	if building_key == "":
		return false
	for node in get_tree().get_nodes_in_group("buildings"):
		if node.has_method("get") and node.get("building_key") == building_key:
			return true
	return false


func recipe_keys() -> Array:
	return _recipes.keys()
