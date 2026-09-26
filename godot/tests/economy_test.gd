extends SceneTree
## Lunar ISRU economy test (Phase-10 resource overhaul).
## Verifies:
##   1. ResourceManager loads every resource from data/resources.json, with
##      groups and no legacy `materials`
##   2. Crew life support drains oxygen/water/food as a negative rate that
##      scales with crew count
##   3. Every building cost is payable in resources that exist
##   4. Every recipe input/output names a resource that exists and a
##      building that has a scene
##   5. Zero-input recipe (excavator) runs on building presence alone
##   6. The ilmenite → iron/titanium/water reduction loop runs
##   7. `stop_at` halts a fabricator recipe once stock is reached
##   8. Storage Silo `raises_cap` applies on build and unwinds on removal
##   9. The starter kit affords the opening build order

var resource_manager: Node
var recipe_processor: Node
var building_database: Node
var time_manager: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []

	resource_manager = root.get_node_or_null("ResourceManager")
	recipe_processor = root.get_node_or_null("RecipeProcessor")
	building_database = root.get_node_or_null("BuildingDatabase")
	time_manager = root.get_node_or_null("TimeManager")
	for pair in [
		["ResourceManager", resource_manager], ["RecipeProcessor", recipe_processor],
		["BuildingDatabase", building_database], ["TimeManager", time_manager],
	]:
		if pair[1] == null:
			failures.append("Autoload missing: %s" % pair[0])
	if not failures.is_empty():
		_done(failures)
		return
	time_manager.set_time_scale(0.0)

	# 1. Definitions loaded, grouped, legacy key gone.
	var keys: Array = resource_manager.ordered_keys()
	if keys.size() < 20:
		failures.append("expected 20+ resources from resources.json, got %d" % keys.size())
	if resource_manager.resources.has("materials"):
		failures.append("legacy 'materials' resource still tracked")
	for group in ["vital", "raw", "refined", "component"]:
		if resource_manager.keys_in_group(group).is_empty():
			failures.append("no resources in group '%s'" % group)
	for must in ["regolith", "ilmenite", "anorthite", "hydrogen", "alloy_beams", "electronics"]:
		if not resource_manager.resources.has(must):
			failures.append("resource '%s' missing" % must)

	# 2. Life support scales with crew.
	var crew: float = resource_manager.get_current("crew")
	var o2_def: Dictionary = resource_manager.get_definition("oxygen")
	var expected_drain: float = float(o2_def.get("per_crew_drain", 0.0)) * crew
	if expected_drain <= 0.0:
		failures.append("oxygen has no per_crew_drain")
	if not is_equal_approx(resource_manager.life_support_drain("oxygen"), expected_drain):
		failures.append("oxygen drain %.2f != %.2f" % [resource_manager.life_support_drain("oxygen"), expected_drain])
	if resource_manager.get_rate("oxygen") >= 0.0:
		failures.append("oxygen rate should be negative with no O2 production, got %.2f" % resource_manager.get_rate("oxygen"))
	var rate_before: float = resource_manager.get_rate("oxygen")
	resource_manager.add("crew", 1.0)
	var rate_after: float = resource_manager.get_rate("oxygen")
	if not is_equal_approx(rate_before - rate_after, float(o2_def.get("per_crew_drain", 0.0))):
		failures.append("adding a crew member did not raise the O2 drain (%.2f → %.2f)" % [rate_before, rate_after])
	resource_manager.add("crew", -1.0)

	# 3. Building costs reference real resources.
	for b_key in building_database.list_keys():
		var def: Dictionary = building_database.get_definition(b_key)
		for r_name in def.get("cost", {}).keys():
			if not resource_manager.resources.has(r_name):
				failures.append("building '%s' costs unknown resource '%s'" % [b_key, r_name])
		for field in ["produces", "consumes", "raises_cap"]:
			for r_name in def.get(field, {}).keys():
				if not resource_manager.resources.has(r_name):
					failures.append("building '%s'.%s names unknown resource '%s'" % [b_key, field, r_name])
		if not building_database.has_scene(b_key):
			failures.append("building '%s' has no scene" % b_key)

	# 4. Recipes reference real resources and buildings.
	for r_key in recipe_processor.recipe_keys():
		var recipe: Dictionary = recipe_processor._recipes[r_key]
		for field in ["input", "output", "stop_at"]:
			for r_name in recipe.get(field, {}).keys():
				if not resource_manager.resources.has(r_name):
					failures.append("recipe '%s'.%s names unknown resource '%s'" % [r_key, field, r_name])
		var b_key: String = recipe.get("building", recipe.get("required_building", ""))
		if not building_database.has_definition(b_key):
			failures.append("recipe '%s' needs unknown building '%s'" % [r_key, b_key])

	# Spawn processing buildings directly (no placement) for the recipe checks.
	var holder := Node2D.new()
	root.add_child(holder)
	for scene_name in ["RegolithExcavator", "ReductionPlant", "MatterForge", "StorageSilo"]:
		var packed := load("res://scenes/buildings/%s.tscn" % scene_name) as PackedScene
		if packed == null:
			failures.append("%s.tscn missing" % scene_name)
			continue
		holder.add_child(packed.instantiate())
	await process_frame

	# 5. Excavator: no inputs, regolith appears.
	var regolith_before: float = resource_manager.get_current("regolith")
	if not recipe_processor.try_run("excavate_regolith"):
		failures.append("excavate_regolith did not run")
	elif resource_manager.get_current("regolith") <= regolith_before:
		failures.append("excavate_regolith produced no regolith")

	# 6. Reduction loop: ilmenite + hydrogen → iron + titanium + water.
	resource_manager.add("ilmenite", 20.0)
	var h2_before: float = resource_manager.get_current("hydrogen")
	var iron_before: float = resource_manager.get_current("iron")
	var ti_before: float = resource_manager.get_current("titanium")
	var water_before: float = resource_manager.get_current("water")
	if not recipe_processor.try_run("reduce_ilmenite"):
		failures.append("reduce_ilmenite did not run")
	else:
		if resource_manager.get_current("hydrogen") >= h2_before:
			failures.append("reduce_ilmenite consumed no hydrogen")
		if resource_manager.get_current("iron") <= iron_before:
			failures.append("reduce_ilmenite produced no iron")
		if resource_manager.get_current("titanium") <= ti_before:
			failures.append("reduce_ilmenite produced no titanium")
		if resource_manager.get_current("water") <= water_before:
			failures.append("reduce_ilmenite returned no water (H2 loop broken)")

	# 6b. Per-building scaling and drill hotspots.
	#   - a second excavator doubles the regolith cycle
	#   - a drill off any deposit drills regolith and trace ilmenite (×0.25)
	#   - a drill with an ilmenite node beside it yields the full amount
	#   - KREEP has no trace yield, so an off-deposit drill gives nothing
	var excavator_scene := load("res://scenes/buildings/RegolithExcavator.tscn") as PackedScene
	holder.add_child(excavator_scene.instantiate())
	await process_frame
	if not is_equal_approx(recipe_processor.multiplier("excavate_regolith"), 2.0):
		failures.append("two excavators should give multiplier 2, got %.2f" % recipe_processor.multiplier("excavate_regolith"))
	var reg_before: float = resource_manager.get_current("regolith")
	recipe_processor.try_run("excavate_regolith")
	if not is_equal_approx(resource_manager.get_current("regolith") - reg_before, 12.0):
		failures.append("two excavators should yield 12 regolith per cycle, got %.1f" % (resource_manager.get_current("regolith") - reg_before))

	var drill_scene := load("res://scenes/buildings/MiningDrill.tscn") as PackedScene
	var drill: Node2D = drill_scene.instantiate()
	drill.position = Vector2(5000, 5000)
	holder.add_child(drill)
	await process_frame
	reg_before = resource_manager.get_current("regolith")
	if not recipe_processor.try_run("drill_regolith"):
		failures.append("drill_regolith did not run for an off-deposit drill")
	elif resource_manager.get_current("regolith") - reg_before < 2.9:
		failures.append("drill_regolith yielded too little regolith")
	if not is_equal_approx(recipe_processor.multiplier("extract_ilmenite"), 0.25):
		failures.append("off-deposit drill should give ilmenite multiplier 0.25, got %.2f" % recipe_processor.multiplier("extract_ilmenite"))
	var ilm_before: float = resource_manager.get_current("ilmenite")
	if not recipe_processor.try_run("extract_ilmenite"):
		failures.append("extract_ilmenite did not run for an off-deposit drill (trace yield)")
	elif not is_equal_approx(resource_manager.get_current("ilmenite") - ilm_before, 1.25):
		failures.append("off-deposit drill should yield 1.25 ilmenite, got %.2f" % (resource_manager.get_current("ilmenite") - ilm_before))
	if recipe_processor.multiplier("extract_kreep") > 0.0 or recipe_processor.try_run("extract_kreep"):
		failures.append("KREEP should have no trace yield off-deposit")

	var node_scene := load("res://scenes/world/ResourceNode.tscn") as PackedScene
	var node: Node2D = node_scene.instantiate()
	node.deposit_type = "ilmenite"
	node.position = drill.position + Vector2(40, 0)
	holder.add_child(node)
	await process_frame
	if not is_equal_approx(recipe_processor.multiplier("extract_ilmenite"), 1.0):
		failures.append("drill beside an ilmenite node should give multiplier 1.0, got %.2f" % recipe_processor.multiplier("extract_ilmenite"))
	ilm_before = resource_manager.get_current("ilmenite")
	recipe_processor.try_run("extract_ilmenite")
	if not is_equal_approx(resource_manager.get_current("ilmenite") - ilm_before, 5.0):
		failures.append("on-deposit drill should yield 5 ilmenite, got %.2f" % (resource_manager.get_current("ilmenite") - ilm_before))
	if not recipe_processor.try_run("drill_regolith"):
		failures.append("drill on a deposit should still drill regolith")

	# 6c. A capped output only idles the recipe when nothing drains it.
	#   Regolith bricks have no life-support drain (water does — crew drink
	#   it — so it can't serve here). With bricks at cap and no consumer,
	#   sinter_bricks must idle (don't waste regolith). Add an external drain
	#   and it must run again so the stock holds at max instead of
	#   flickering max / max-1.
	holder.add_child((load("res://scenes/buildings/SinteringKiln.tscn") as PackedScene).instantiate())
	await process_frame
	resource_manager.add("regolith", 100.0)
	resource_manager.add("regolith_bricks", resource_manager.get_max("regolith_bricks"))  # → cap
	recipe_processor._refresh_rates()
	if recipe_processor.active_multiplier("sinter_bricks") > 0.0:
		failures.append("sinter_bricks should idle with bricks at cap and nothing draining them")
	resource_manager.add_to_rate("regolith_bricks", -5.0)  # something else consumes bricks
	if recipe_processor.active_multiplier("sinter_bricks") <= 0.0:
		failures.append("sinter_bricks should keep running at cap while bricks are being drained")
	resource_manager.add_to_rate("regolith_bricks", 5.0)
	recipe_processor._refresh_rates()

	# 7. stop_at: fabricator halts once alloy_beams reach the threshold.
	var beams_recipe: Dictionary = recipe_processor._recipes["fab_alloy_beams"]
	var stop_level: float = float(beams_recipe.get("stop_at", {}).get("alloy_beams", -1))
	if stop_level <= 0.0:
		failures.append("fab_alloy_beams has no stop_at")
	else:
		resource_manager.add("iron", 50.0)
		resource_manager.add("titanium", 50.0)
		var beams_now: float = resource_manager.get_current("alloy_beams")
		resource_manager.add("alloy_beams", stop_level - beams_now)  # pin at threshold
		if recipe_processor.try_run("fab_alloy_beams"):
			failures.append("fab_alloy_beams ran while stock was at stop_at")
		resource_manager.add("alloy_beams", -10.0)
		if not recipe_processor.try_run("fab_alloy_beams"):
			failures.append("fab_alloy_beams refused to run below stop_at")

	# 8. Storage Silo raises caps and unwinds on removal.
	var silo_def: Dictionary = building_database.get_definition("storage_silo")
	var raises: Dictionary = silo_def.get("raises_cap", {})
	if raises.is_empty():
		failures.append("storage_silo has no raises_cap")
	else:
		var base_regolith_cap: float = float(resource_manager.get_definition("regolith").get("max", 0))
		var expected_cap: float = base_regolith_cap + float(raises.get("regolith", 0))
		if not is_equal_approx(resource_manager.get_max("regolith"), expected_cap):
			failures.append("silo did not raise regolith cap (%.0f, expected %.0f)" % [resource_manager.get_max("regolith"), expected_cap])
		for child in holder.get_children():
			if child.get("building_key") == "storage_silo":
				child.queue_free()
		await process_frame
		await process_frame
		if not is_equal_approx(resource_manager.get_max("regolith"), base_regolith_cap):
			failures.append("removing silo did not restore regolith cap (%.0f)" % resource_manager.get_max("regolith"))

	# 9. Starter kit covers the opening build order AND the colony stays
	#    power-positive at every step. Power hitting 0 is a defeat condition
	#    and nothing pauses a building, so the kit must carry enough PV to
	#    reach the point where the forge can make more cells (needs smelter
	#    silicon + kiln glass). Re-read from definitions, not live stock,
	#    since earlier checks spent some.
	var kit: Dictionary = {}
	for r_name in keys:
		kit[r_name] = float(resource_manager.get_definition(r_name).get("start", 0))
	var opening: Array = [
		"solar_array", "solar_array", "mining_drill", "electrolyzer", "reduction_plant",
		"solar_array", "solar_array", "solar_array", "matter_forge", "mre_smelter",
		"regolith_excavator", "sintering_kiln",
	]
	var net_power: float = 0.0
	for b_key in opening:
		var def: Dictionary = building_database.get_definition(b_key)
		for r_name in def.get("cost", {}).keys():
			kit[r_name] -= float(def["cost"][r_name])
			if kit[r_name] < 0.0:
				failures.append("starter kit short on %s by the time %s is built" % [r_name, b_key])
		net_power += float(def.get("produces", {}).get("power", 0)) - float(def.get("consumes", {}).get("power", 0))
		if net_power < 0.0:
			failures.append("opening order goes power-negative (%.0f/min) at %s" % [net_power, b_key])

	holder.queue_free()
	time_manager.set_time_scale(1.0)
	_done(failures)


func _done(failures: Array) -> void:
	if failures.is_empty():
		print("PASS")
	else:
		for f in failures:
			print("FAIL: ", f)
	quit()
