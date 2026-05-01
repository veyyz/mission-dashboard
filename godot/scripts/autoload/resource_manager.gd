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
	# Initial values match the HUD reference (screenshot 1 / 4).
	resources["power"]     = ResourceData.new(1250, 1250)
	resources["oxygen"]    = ResourceData.new(860, 860)
	resources["food"]      = ResourceData.new(740, 1000)
	resources["materials"] = ResourceData.new(420, 1000)
	resources["science"]   = ResourceData.new(310, 1000)
	resources["crew"]      = ResourceData.new(28, 36)
	print("[ResourceManager] Ready. %d resources tracked." % resources.size())


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


## Raise (or lower) the storage cap for a resource. Used by Storage Silos.
func set_max(name: String, new_max: float) -> void:
	if not resources.has(name):
		return
	var data: ResourceData = resources[name]
	data.maximum = maxf(0.0, new_max)
	data.current = minf(data.current, data.maximum)
	EventBus.resource_changed.emit(name, data.current, data.maximum, data.rate_per_min)
