extends Node
## Tracks the six core resources. Subscribe to EventBus.resource_changed
## for UI updates — never poll these directly.

class ResourceData:
	var current: float
	var maximum: float
	var rate_per_min: float

	func _init(c: float, m: float, r: float = 0.0) -> void:
		current = c
		maximum = m
		rate_per_min = r


var resources: Dictionary = {}


func _ready() -> void:
	# Six core resources tracked by the HUD (per spec §5.1).
	resources["power"]     = ResourceData.new(1250, 1250)
	resources["oxygen"]    = ResourceData.new(860, 860)
	resources["food"]      = ResourceData.new(740, 1000)
	resources["materials"] = ResourceData.new(420, 1000)
	resources["science"]   = ResourceData.new(310, 1000)
	resources["crew"]      = ResourceData.new(28, 36)
	# Secondary stockpiles referenced by `data/buildings.json` and `data/recipes.json`
	# but not surfaced on the main resource bar yet.
	resources["silicon"]     = ResourceData.new(120, 200)
	resources["iron"]        = ResourceData.new(140, 200)
	resources["water"]       = ResourceData.new(180, 300)
	resources["rare_metals"] = ResourceData.new(40, 100)
	resources["samples"]     = ResourceData.new(0, 50)
	resources["helium3"]     = ResourceData.new(0, 100)
	resources["titanium"]    = ResourceData.new(0, 100)
	print("[ResourceManager] Ready. %d resources tracked." % resources.size())


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


func get_current(name: String) -> float:
	return resources[name].current if resources.has(name) else 0.0


func get_max(name: String) -> float:
	return resources[name].maximum if resources.has(name) else 0.0


func get_rate(name: String) -> float:
	return resources[name].rate_per_min if resources.has(name) else 0.0


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
