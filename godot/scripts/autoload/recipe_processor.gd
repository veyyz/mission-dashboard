extends Node
## Recipe processor. Polls recipes (loaded from `data/recipes.json`) and
## cycles them on a per-recipe timer. Each cycle scales with how many of the
## recipe's `building` are standing — two electrolyzers split twice the water.
##
## Extraction recipes (`input_resource`) are the exception to "just count
## buildings": every drill is classified as ON a matching deposit (within 1
## cell of a resource_node of that type) or OFF it. On-deposit drills give
## the full `output`; off-deposit drills give `output × trace_factor` (the
## ore is present in bulk regolith everywhere, just thin). So one drill on
## an ilmenite hotspot plus one in open ground = 1.25× the recipe output.
##
## `stop_at` idles a recipe once an output stock reaches that level; a recipe
## also idles when every output is at cap. Emits `EventBus.log_message` per
## cycle for player feedback.

const RECIPES_PATH: String = "res://data/recipes.json"

var _recipes: Dictionary = {}
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
		if not recipe.has("output"):
			continue
		_recipes[key] = recipe
	print("[RecipeProcessor] Ready. %d recipes loaded." % _recipes.size())


func _process(delta: float) -> void:
	if GameState != null and GameState.is_paused:
		return
	var time_scale: float = TimeManager.time_scale if TimeManager else 1.0
	if time_scale <= 0.0:
		return
	# Production is continuous: each active recipe publishes its per-minute
	# rates into ResourceManager, which integrates them every frame. Re-decide
	# what is active ~1×/sec (drill placement, building count, stock levels).
	# No lump per cycle — publishing a rate AND adding a lump would count
	# every recipe twice, and lumps against a steady drain make a full stock
	# flicker between max and max-1.
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0
		_refresh_rates()


## Runs one discrete cycle immediately (inputs deducted, outputs added).
## Not used by the simulation loop, which is rate-driven; kept for tests and
## for any future manual "craft now" action.
func try_run(key: String) -> bool:
	if not _recipes.has(key):
		return false
	return _try_run(key, _recipes[key])


## How many "units" of this recipe cycle at once right now:
##   - ordinary recipe: number of standing buildings of its type
##   - extraction recipe: on-deposit drills + off-deposit drills × trace_factor
## 0 means the recipe is idle (no building, or drills with no trace yield).
func multiplier(key: String) -> float:
	var recipe: Dictionary = _recipes.get(key, {})
	var building_key: String = recipe.get("building", recipe.get("required_building", ""))
	var buildings: Array = _buildings_of(building_key)
	if buildings.is_empty():
		return 0.0
	if not recipe.has("input_resource"):
		return float(buildings.size())
	var deposit_type: String = String(recipe["input_resource"]).trim_suffix("_node")
	var on_deposit: int = 0
	for b in buildings:
		if _near_node(b, deposit_type, 1):
			on_deposit += 1
	var off_deposit: int = buildings.size() - on_deposit
	return float(on_deposit) + float(off_deposit) * float(recipe.get("trace_factor", 0.0))


## The multiplier the recipe is actually running at: 0 when idle (no
## building, outputs not wanted, or inputs out of stock), otherwise
## `multiplier()` — floored to whole units and reduced to what stock affords
## for input-driven recipes. This is what gets published as rates, so the
## HUD never shows a phantom +/min for a starved or capped recipe.
func active_multiplier(key: String) -> float:
	var recipe: Dictionary = _recipes.get(key, {})
	var mult: float = multiplier(key)
	if mult <= 0.0 or not _outputs_wanted(key, recipe):
		return 0.0
	var input: Dictionary = recipe.get("input", {})
	if input.is_empty():
		return mult
	mult = floorf(mult)
	while mult >= 1.0 and not ResourceManager.can_afford(_scaled(input, mult)):
		mult -= 1.0
	return maxf(mult, 0.0)


func _try_run(key: String, recipe: Dictionary) -> bool:
	var mult: float = multiplier(key)
	if mult <= 0.0:
		return false
	if not _outputs_wanted(key, recipe):
		return false
	var input: Dictionary = recipe.get("input", {})
	# Input-driven recipes run in whole units; run as many as stock allows
	# (two forges with iron for one beam batch make one batch, not zero).
	var runs: float = mult
	if not input.is_empty():
		runs = floorf(mult)
		while runs >= 1.0 and not ResourceManager.can_afford(_scaled(input, runs)):
			runs -= 1.0
		if runs < 1.0:
			return false
		if not ResourceManager.deduct(_scaled(input, runs)):
			return false
	var output: Dictionary = recipe.get("output", {})
	for r_name in output.keys():
		ResourceManager.add(r_name, float(output[r_name]) * runs)
	EventBus.log_message.emit(
		"Recipe '%s' completed cycle (×%s)" % [recipe.get("display_name", key), str(snappedf(runs, 0.01))],
		"build",
	)
	return true


func _scaled(amounts: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = {}
	for r_name in amounts.keys():
		out[r_name] = float(amounts[r_name]) * factor
	return out


## For each recipe, decide if it's currently runnable. If yes, compute its
## per-resource rate (output_amount * 60 / duration_seconds, minus inputs,
## × multiplier) and push the delta into ResourceManager's rate_per_min.
## Idle recipes subtract their previously-published rates.
func _refresh_rates() -> void:
	for key in _recipes.keys():
		var recipe: Dictionary = _recipes[key]
		var mult: float = active_multiplier(key)
		var new_rates: Dictionary = _compute_recipe_rates(recipe, mult) if mult > 0.0 else {}
		var prev: Dictionary = _applied_rates.get(key, {})
		for r in new_rates.keys():
			ResourceManager.add_to_rate(r, new_rates[r] - prev.get(r, 0.0))
		for r in prev.keys():
			if not new_rates.has(r):
				ResourceManager.add_to_rate(r, -prev[r])
		_applied_rates[key] = new_rates


func _compute_recipe_rates(recipe: Dictionary, mult: float) -> Dictionary:
	var rates: Dictionary = {}
	var dur: float = float(recipe.get("duration_seconds", 5.0))
	if dur <= 0.0:
		return rates
	var per_min: float = 60.0 / dur * mult
	for r in recipe.get("output", {}).keys():
		rates[r] = float(recipe["output"][r]) * per_min
	for r in recipe.get("input", {}).keys():
		rates[r] = rates.get(r, 0.0) - float(recipe["input"][r]) * per_min
	return rates


## False when any output has reached its recipe `stop_at` level (`stop_at`
## is how the fabricator keeps a stock of each component instead of draining
## all its iron into the first recipe in the file), or when every output is
## at its storage cap AND nothing else is draining it. A capped output that
## something consumes keeps the recipe running: production covers the drain,
## the clamp holds the stock at max, and the HUD shows a steady full value
## instead of max / max-1 flicker. Only when drain exceeds production does
## the stock actually fall.
func _outputs_wanted(key: String, recipe: Dictionary) -> bool:
	var output: Dictionary = recipe.get("output", {})
	if output.is_empty():
		return false
	var stop_at: Dictionary = recipe.get("stop_at", {})
	for r_name in stop_at.keys():
		if ResourceManager.get_current(r_name) >= float(stop_at[r_name]):
			return false
	var mine: Dictionary = _applied_rates.get(key, {})
	for r_name in output.keys():
		if ResourceManager.get_current(r_name) < ResourceManager.get_max(r_name):
			return true
		# At cap: is anyone other than this recipe pulling it down?
		var others: float = ResourceManager.get_rate(r_name) - float(mine.get(r_name, 0.0))
		if others < 0.0:
			return true
	return false


func _buildings_of(building_key: String) -> Array:
	var out: Array = []
	if building_key == "":
		return out
	for node in get_tree().get_nodes_in_group("buildings"):
		if node.has_method("get") and node.get("building_key") == building_key:
			out.append(node)
	return out


## True if `building` sits within `max_cells` iso tiles of a resource_node
## whose deposit_type matches. Iso world: 1 tile width = 64px, 1 tile height
## = 32px. Radius = half the building's visual footprint plus max_cells tiles,
## so a node anywhere along the building's edge counts as "1 away".
func _near_node(building: Node, deposit_type: String, max_cells: int) -> bool:
	var bn := building as Node2D
	if bn == null:
		return false
	var cells: float = float(bn.get("cells_per_side")) if bn.get("cells_per_side") != null else 6.0
	var radius_px: float = cells * 32.0 + max_cells * 64.0
	for n in get_tree().get_nodes_in_group("resource_node"):
		var rn := n as Node2D
		if rn == null or rn.get("deposit_type") != deposit_type:
			continue
		if rn.global_position.distance_to(bn.global_position) <= radius_px:
			return true
	return false


func recipe_keys() -> Array:
	return _recipes.keys()


func get_recipe(key: String) -> Dictionary:
	return _recipes.get(key, {})


## recipe_key → { resource: rate_per_min } for recipes currently cycling.
## Read by the resource inspector to attribute live flow to recipes.
func applied_rates() -> Dictionary:
	return _applied_rates.duplicate(true)
