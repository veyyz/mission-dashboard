extends Node
## Phase-9 random event manager. Loads `data/events.json`, then on every
## `EventBus.mission_day_advanced` rolls each event independently against
## its `trigger_chance_per_day`, gated by `min_day` and (if specified)
## `requires_building`. Applies the supported effects:
##   - `add_resource` — directly adds to ResourceManager
##   - others (damage_random_outdoor_building, disable_random_building,
##     radiation_pulse, spawn_rescue_objective) are stubs that emit a log
##     message; full gameplay wiring lands in Phase 10 polish.
##
## Public:
##   - `try_event(event_id)` deterministically fires an event ignoring RNG
##     and gating, used by tests.

const EVENTS_PATH: String = "res://data/events.json"

var _events: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if f == null:
		push_error("[EventManager] cannot open %s" % EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[EventManager] data not a dict")
		return
	for k in parsed.keys():
		if k.begins_with("_"):
			continue
		_events[k] = parsed[k]
	EventBus.mission_day_advanced.connect(_on_day_advanced)
	print("[EventManager] Ready. %d events loaded." % _events.size())


func _on_day_advanced(day: int) -> void:
	for event_id in _events.keys():
		var ev: Dictionary = _events[event_id]
		if day < int(ev.get("min_day", 0)):
			continue
		var req_building: String = ev.get("requires_building", "")
		if req_building != "" and not _has_building(req_building):
			continue
		var chance: float = float(ev.get("trigger_chance_per_day", 0.0))
		if _rng.randf() < chance:
			_fire(event_id, ev)


## Public — fire an event ignoring RNG/gating. Used for tests + scripted moments.
func try_event(event_id: String) -> bool:
	if not _events.has(event_id):
		return false
	_fire(event_id, _events[event_id])
	return true


func _fire(event_id: String, ev: Dictionary) -> void:
	var summary: String = ev.get("display_name", event_id)
	var effects: Array = ev.get("effects", [])
	for effect in effects:
		var t: String = effect.get("type", "")
		match t:
			"add_resource":
				ResourceManager.add(
					effect.get("resource", "materials"),
					float(effect.get("amount", 0)),
				)
			_:
				# Stub effects — surface to log so the player sees something happened.
				pass
	EventBus.random_event_fired.emit(event_id, summary)
	EventBus.log_message.emit("Event: %s" % summary, "alert")


func _has_building(building_key: String) -> bool:
	for node in get_tree().get_nodes_in_group("buildings"):
		if node.has_method("get") and node.get("building_key") == building_key:
			return true
	return false


func event_keys() -> Array:
	return _events.keys()
