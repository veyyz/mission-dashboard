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
var _applied_rates: Dictionary = {}  # recipe_key → { resource: rate_per_min }
var _refresh_timer: float = 0.0


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
		# Process recipes with output. Standard recipes have an input dict;
		# extraction recipes have input_resource (node type) and no input
		# dict — treat them as zero-input recipes triggered by drill presence.
		if not recipe.has("output"):
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
	# Refresh published rates ~1×/sec so the HUD reflects which recipes are
	# currently active (drill near node, building present, etc.).
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0
		_refresh_rates()
	for key in _recipes.keys():
		var recipe: Dictionary = _recipes[key]
		var building_key: String = recipe.get("building", recipe.get("required_building", ""))
		if not _has_building(building_key):
			continue
		# Extraction recipes need a matching deposit within 1 cell of a drill.
		if recipe.has("input_resource"):
			var deposit_type: String = String(recipe["input_resource"]).trim_suffix("_node")
			if not _building_near_node(building_key, deposit_type, 1):
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


## For each recipe, decide if it's currently runnable. If yes, compute its
## per-resource rate (output_amount * 60 / duration_seconds, minus inputs)
## and push the delta into ResourceManager's rate_per_min. Idle recipes
## subtract their previously-published rates.
func _refresh_rates() -> void:
	for key in _recipes.keys():
		var recipe: Dictionary = _recipes[key]
		var building_key: String = recipe.get("building", recipe.get("required_building", ""))
		var active: bool = _has_building(building_key)
		if active and recipe.has("input_resource"):
			var dep_type: String = String(recipe["input_resource"]).trim_suffix("_node")
			active = _building_near_node(building_key, dep_type, 1)
		var new_rates: Dictionary = _compute_recipe_rates(recipe) if active else {}
		var prev: Dictionary = _applied_rates.get(key, {})
		for r in new_rates.keys():
			ResourceManager.add_to_rate(r, new_rates[r] - prev.get(r, 0.0))
		for r in prev.keys():
			if not new_rates.has(r):
				ResourceManager.add_to_rate(r, -prev[r])
		_applied_rates[key] = new_rates


func _compute_recipe_rates(recipe: Dictionary) -> Dictionary:
	var rates: Dictionary = {}
	var dur: float = float(recipe.get("duration_seconds", 5.0))
	if dur <= 0.0:
		return rates
	var per_min: float = 60.0 / dur
	for r in recipe.get("output", {}).keys():
		rates[r] = float(recipe["output"][r]) * per_min
	for r in recipe.get("input", {}).keys():
		rates[r] = rates.get(r, 0.0) - float(recipe["input"][r]) * per_min
	return rates


func _has_building(building_key: String) -> bool:
	if building_key == "":
		return false
	for node in get_tree().get_nodes_in_group("buildings"):
		if node.has_method("get") and node.get("building_key") == building_key:
			return true
	return false


## True if any building of `building_key` sits within `max_cells` iso tiles
## of a resource_node whose deposit_type matches. Iso world: 1 tile width =
## 64px, 1 tile height = 32px. Use the larger dim plus a fudge so adjacent
## iso tiles in any direction count as "1 away".
func _building_near_node(building_key: String, deposit_type: String, max_cells: int) -> bool:
	var matching_drills: Array = []
	for n in get_tree().get_nodes_in_group("buildings"):
		if n.has_method("get") and n.get("building_key") == building_key:
			matching_drills.append(n)
	if matching_drills.is_empty():
		return false
	for n in get_tree().get_nodes_in_group("resource_node"):
		var rn := n as Node2D
		if rn == null:
			continue
		if rn.get("deposit_type") != deposit_type:
			continue
		for d in matching_drills:
			var dn := d as Node2D
			# Per-drill radius: half of drill's visual footprint width + max_cells tiles.
			# Drill anchor is at bottom apex of its diamond; node can be anywhere
			# within `max_cells` tiles of any drill edge.
			var drill_cells: float = float(dn.get("cells_per_side")) if dn.get("cells_per_side") != null else 6.0
			var radius_px: float = drill_cells * 32.0 + max_cells * 64.0
			if rn.global_position.distance_to(dn.global_position) <= radius_px:
				return true
	return false


func recipe_keys() -> Array:
	return _recipes.keys()
