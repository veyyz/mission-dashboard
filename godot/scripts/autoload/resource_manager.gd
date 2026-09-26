extends Node
## Tracks every colony resource, defined in `data/resources.json` (vitals,
## raw ore, refined stock, fabricated components). Subscribe to
## EventBus.resource_changed for UI updates — never poll these directly.
##
## Life support: each crew member drains oxygen / water / food per minute
## (`per_crew_drain` in resources.json). The drain is published as a negative
## rate so the HUD and the win/lose checkpoint see the real net figure.

const RESOURCES_PATH: String = "res://data/resources.json"

class ResourceData:
	var current: float
	var maximum: float
	var rate_per_min: float

	func _init(c: float, m: float, r: float = 0.0) -> void:
		current = c
		maximum = m
		rate_per_min = r


var resources: Dictionary = {}

## Raw definition dicts from resources.json, in file order.
var _defs: Dictionary = {}
var _order: Array[String] = []

## Life-support rates currently applied, so a crew-count change can be
## re-applied as a delta instead of clobbering building rates.
var _life_support_applied: Dictionary = {}


func _ready() -> void:
	_load_definitions()
	for r_name in _order:
		var d: Dictionary = _defs[r_name]
		resources[r_name] = ResourceData.new(float(d.get("start", 0)), float(d.get("max", 100)))
	_refresh_life_support()
	print("[ResourceManager] Ready. %d resources tracked." % resources.size())


func _load_definitions() -> void:
	var f := FileAccess.open(RESOURCES_PATH, FileAccess.READ)
	if f == null:
		push_error("[ResourceManager] cannot open %s" % RESOURCES_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[ResourceManager] %s did not parse to a dictionary" % RESOURCES_PATH)
		return
	for key in (parsed as Dictionary).keys():
		if String(key).begins_with("_"):
			continue
		_defs[key] = parsed[key]
		_order.append(key)


func _process(delta: float) -> void:
	if GameState.is_paused:
		return
	var time_scale: float = TimeManager.time_scale if TimeManager else 1.0
	if time_scale <= 0.0:
		return
	# Apply rate_per_min to current per real-second tick. Rates from buildings
	# are summed via `add_to_rate(name, delta_rate)`.
	for r_name in resources.keys():
		var data: ResourceData = resources[r_name]
		if data.rate_per_min == 0.0:
			continue
		var change: float = (data.rate_per_min / 60.0) * delta * time_scale
		var prev: float = data.current
		data.current = clampf(data.current + change, 0.0, data.maximum)
		if not is_equal_approx(prev, data.current):
			EventBus.resource_changed.emit(r_name, data.current, data.maximum, data.rate_per_min)
			if data.current <= 0.0:
				EventBus.resource_depleted.emit(r_name)


# --- Definitions -------------------------------------------------------------

## Resource keys in resources.json order (the HUD display order).
func ordered_keys() -> Array[String]:
	return _order.duplicate()


## Keys whose `group` matches ("vital", "raw", "refined", "component").
func keys_in_group(group: String) -> Array[String]:
	var out: Array[String] = []
	for r_name in _order:
		if _defs[r_name].get("group", "") == group:
			out.append(r_name)
	return out


func get_definition(name: String) -> Dictionary:
	return _defs.get(name, {})


func display_name(name: String) -> String:
	return String(_defs.get(name, {}).get("display_name", name.capitalize()))


func glyph(name: String) -> String:
	return String(_defs.get(name, {}).get("glyph", "?"))


func color(name: String) -> Color:
	var c: Variant = _defs.get(name, {}).get("color", null)
	if c is Array and (c as Array).size() >= 3:
		return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color.WHITE


## "Alloy Beams 8, Wiring 4" — for tooltips and log lines.
func format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for r_name in cost.keys():
		parts.append("%s %d" % [display_name(r_name), int(cost[r_name])])
	return ", ".join(parts)


# --- Queries -----------------------------------------------------------------

func get_current(name: String) -> float:
	return resources[name].current if resources.has(name) else 0.0


func get_max(name: String) -> float:
	return resources[name].maximum if resources.has(name) else 0.0


func get_rate(name: String) -> float:
	return resources[name].rate_per_min if resources.has(name) else 0.0


# --- Mutation ----------------------------------------------------------------

## Add (or subtract, with a negative amount) a resource. Clamps to [0, max]
## and emits resource_changed. Emits resource_depleted if it hits zero.
func add(name: String, amount: float) -> void:
	if not resources.has(name):
		push_warning("ResourceManager.add: unknown resource '%s'" % name)
		return
	var data: ResourceData = resources[name]
	data.current = clampf(data.current + amount, 0.0, data.maximum)
	EventBus.resource_changed.emit(name, data.current, data.maximum, data.rate_per_min)
	if data.current <= 0.0:
		EventBus.resource_depleted.emit(name)
	if name == "crew":
		_refresh_life_support()


func set_rate(name: String, rate: float) -> void:
	if not resources.has(name):
		return
	resources[name].rate_per_min = rate
	var data: ResourceData = resources[name]
	EventBus.resource_changed.emit(name, data.current, data.maximum, rate)


## Buildings call this on completion (positive delta for produces, negative for
## consumes) and on destruction (the inverse). Lets multiple buildings stack
## without clobbering each other's rate.
func add_to_rate(name: String, delta_rate: float) -> void:
	if not resources.has(name):
		push_warning("ResourceManager.add_to_rate: unknown resource '%s'" % name)
		return
	var data: ResourceData = resources[name]
	data.rate_per_min += delta_rate
	EventBus.resource_changed.emit(name, data.current, data.maximum, data.rate_per_min)


## Returns true iff every resource in the cost dict is currently >= the requested amount.
func can_afford(cost: Dictionary) -> bool:
	for r_name in cost.keys():
		if not resources.has(r_name):
			return false
		if resources[r_name].current < float(cost[r_name]):
			return false
	return true


## Atomically deducts a cost dict. Returns false if any line item is unaffordable
## (no partial deductions). Emits resource_changed for each line.
func deduct(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for r_name in cost.keys():
		add(r_name, -float(cost[r_name]))
	return true


## Raise (or lower) the storage cap for a resource. Used by Storage Silos.
func set_max(name: String, new_max: float) -> void:
	if not resources.has(name):
		return
	var data: ResourceData = resources[name]
	data.maximum = maxf(0.0, new_max)
	data.current = minf(data.current, data.maximum)
	EventBus.resource_changed.emit(name, data.current, data.maximum, data.rate_per_min)


# --- Life support ------------------------------------------------------------

## Re-derive the per-crew drain from the current crew count and apply the
## difference against what was last applied. Called at boot and whenever the
## crew count changes (rescue events, deaths, save-load).
func _refresh_life_support() -> void:
	var crew_count: float = get_current("crew")
	for r_name in _order:
		var drain: float = float(_defs[r_name].get("per_crew_drain", 0.0))
		if drain <= 0.0:
			continue
		var wanted: float = -drain * crew_count
		var prev: float = _life_support_applied.get(r_name, 0.0)
		if not is_equal_approx(wanted, prev):
			add_to_rate(r_name, wanted - prev)
			_life_support_applied[r_name] = wanted


## Total per-minute drain for a resource at the current crew count (positive
## number). Exposed for the HUD tooltip and tests.
func life_support_drain(name: String) -> float:
	return -_life_support_applied.get(name, 0.0)
