extends PanelContainer
## Resource inspector. Hidden until a vital or stockpile chip is clicked
## (EventBus.resource_inspect_requested), then shows for that resource:
##   - name, tier, description
##   - stored / cap, net rate
##   - CURRENT FLOW  — every live contributor: standing buildings' flat
##                     rates, recipes that are actually cycling, crew drain
##   - REQUIRED BY   — buildings that cost it to build, consume it to run,
##                     or feed it into a recipe (with amounts and purpose)
##   - PRODUCED BY   — buildings / recipes that yield it
## Clicking another resource retargets the panel. Wrapped by hud_chrome like
## every other panel, so it can be dragged, docked, collapsed and resized.

const COL_TEXT := "#e8edf2"
const COL_MUTED := "#8c9bb3"
const COL_UP := "#73c780"
const COL_DOWN := "#eb6673"
const COL_CAP := "#f2b54d"
const TIER_LABEL := {"vital": "VITAL", "raw": "RAW", "refined": "REFINED", "component": "COMPONENT"}
const TIER_COLOR := {
	"vital": Color(0.95, 0.71, 0.30), "raw": Color(0.85, 0.62, 0.35),
	"refined": Color(0.36, 0.71, 0.84), "component": Color(0.66, 0.45, 0.85),
}
const REFRESH_INTERVAL: float = 0.25

@onready var glyph_label: Label = $Margin/VBox/Title/Glyph
@onready var name_label: Label = $Margin/VBox/Title/Name
@onready var tier_label: Label = $Margin/VBox/Title/Tier
@onready var close_btn: Button = $Margin/VBox/Title/Close
@onready var description_label: Label = $Margin/VBox/Description
@onready var body: RichTextLabel = $Margin/VBox/Scroll/Body

var subject: String = ""
var _dirty: bool = false
var _refresh_timer: float = 0.0


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func() -> void: visible = false)
	EventBus.resource_inspect_requested.connect(show_resource)
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.building_completed.connect(func(_k: String, _p: Vector2i) -> void: _dirty = true)
	EventBus.building_destroyed.connect(func(_k: String, _p: Vector2i) -> void: _dirty = true)


func _process(delta: float) -> void:
	if not visible or not _dirty:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_dirty = false
		_render()


func show_resource(r_name: String) -> void:
	if not ResourceManager.resources.has(r_name):
		return
	subject = r_name
	visible = true
	move_to_front()
	_refresh_timer = 0.0
	_render()


func _on_resource_changed(r_name: String, _c: float, _m: float, _r: float) -> void:
	if r_name == subject:
		_dirty = true


# --- Render ------------------------------------------------------------------

func _render() -> void:
	var def: Dictionary = ResourceManager.get_definition(subject)
	var group: String = String(def.get("group", "raw"))
	glyph_label.text = ResourceManager.glyph(subject)
	glyph_label.add_theme_color_override("font_color", ResourceManager.color(subject))
	name_label.text = ResourceManager.display_name(subject)
	tier_label.text = TIER_LABEL.get(group, group.to_upper())
	tier_label.add_theme_color_override("font_color", TIER_COLOR.get(group, Color.WHITE))
	description_label.text = String(def.get("description", ""))
	description_label.visible = description_label.text != ""

	var current: float = ResourceManager.get_current(subject)
	var maximum: float = ResourceManager.get_max(subject)
	var rate: float = ResourceManager.get_rate(subject)

	var t: String = ""
	t += "[color=%s]STOCK[/color]\n" % COL_MUTED
	var stock_color: String = COL_CAP if current >= maximum else COL_TEXT
	t += "  Stored   [color=%s]%d[/color] [color=%s]/ %d cap%s[/color]\n" % [
		stock_color, int(current), COL_MUTED, int(maximum), "  (full — production wasted)" if current >= maximum else "",
	]
	t += "  Net rate %s\n" % _rate_text(rate)
	if rate < 0.0 and current > 0.0:
		t += "  [color=%s]Empty in %s at this rate[/color]\n" % [COL_DOWN, _minutes_text(current / -rate)]
	elif rate > 0.0 and current < maximum:
		t += "  [color=%s]Full in %s at this rate[/color]\n" % [COL_MUTED, _minutes_text((maximum - current) / rate)]

	t += "\n[color=%s]CURRENT FLOW[/color]\n" % COL_MUTED
	var flow: Array = _live_flow()
	if flow.is_empty():
		t += "  [color=%s]nothing producing or consuming it[/color]\n" % COL_MUTED
	for line in flow:
		t += "  %s  %s\n" % [_rate_text(line[0]), line[1]]

	t += "\n[color=%s]REQUIRED BY[/color]\n" % COL_MUTED
	var needs: Array = _required_by()
	if needs.is_empty():
		t += "  [color=%s]nothing uses it yet[/color]\n" % COL_MUTED
	for line in needs:
		t += "  [color=%s]%s[/color]  %s\n" % [COL_TEXT, line[0], line[1]]

	t += "\n[color=%s]PRODUCED BY[/color]\n" % COL_MUTED
	var sources: Array = _produced_by()
	if sources.is_empty():
		t += "  [color=%s]not produced — landing kit or supply drops only[/color]\n" % COL_MUTED
	for line in sources:
		t += "  [color=%s]%s[/color]  %s\n" % [COL_TEXT, line[0], line[1]]

	body.text = t


## Live contributors right now: [rate_per_min, label]. Buildings by standing
## count, recipes by the rates RecipeProcessor is actually publishing, crew.
func _live_flow() -> Array:
	var out: Array = []
	var counts: Dictionary = {}
	for node in get_tree().get_nodes_in_group("buildings"):
		var key: String = String(node.get("building_key")) if node.has_method("get") else ""
		if key != "":
			counts[key] = counts.get(key, 0) + 1
	for key in counts.keys():
		var def: Dictionary = BuildingDatabase.get_definition(key)
		var label: String = "%s ×%d" % [def.get("display_name", key), counts[key]] if counts[key] > 1 else String(def.get("display_name", key))
		var p: float = float(def.get("produces", {}).get(subject, 0.0)) * counts[key]
		var c: float = float(def.get("consumes", {}).get(subject, 0.0)) * counts[key]
		if p > 0.0:
			out.append([p, label])
		if c > 0.0:
			out.append([-c, label + "  (to run)"])
	var applied: Dictionary = RecipeProcessor.applied_rates()
	for r_key in applied.keys():
		var r: float = float(applied[r_key].get(subject, 0.0))
		if is_zero_approx(r):
			continue
		var recipe: Dictionary = RecipeProcessor.get_recipe(r_key)
		var b_key: String = recipe.get("building", recipe.get("required_building", ""))
		out.append([r, "%s  [color=%s]in %s[/color]" % [
			recipe.get("display_name", r_key), COL_MUTED,
			BuildingDatabase.get_definition(b_key).get("display_name", b_key),
		]])
	var drain: float = ResourceManager.life_support_drain(subject)
	if drain > 0.0:
		out.append([-drain, "Crew life support  [color=%s]%d crew[/color]" % [COL_MUTED, int(ResourceManager.get_current("crew"))]])
	out.sort_custom(func(a, b): return a[0] > b[0])
	return out


## Static demand from data: [what, amount + purpose].
func _required_by() -> Array:
	var out: Array = []
	for b_key in BuildingDatabase.list_keys():
		var def: Dictionary = BuildingDatabase.get_definition(b_key)
		var bname: String = String(def.get("display_name", b_key))
		var cost: float = float(def.get("cost", {}).get(subject, 0.0))
		if cost > 0.0:
			out.append([bname, "[color=%s]%d to build[/color]" % [COL_MUTED, int(cost)]])
		var run: float = float(def.get("consumes", {}).get(subject, 0.0))
		if run > 0.0:
			out.append([bname, "[color=%s]%.0f/min to run[/color]" % [COL_MUTED, run]])
	for r_key in RecipeProcessor.recipe_keys():
		var recipe: Dictionary = RecipeProcessor.get_recipe(r_key)
		var amount: float = float(recipe.get("input", {}).get(subject, 0.0))
		if amount <= 0.0:
			continue
		var b_key: String = recipe.get("building", recipe.get("required_building", ""))
		var bname: String = String(BuildingDatabase.get_definition(b_key).get("display_name", b_key))
		out.append([bname, "[color=%s]%d per cycle → %s  (%s)[/color]" % [
			COL_MUTED, int(amount), _outputs_text(recipe), recipe.get("display_name", r_key),
		]])
	return out


## Static supply from data: [what, amount + how].
func _produced_by() -> Array:
	var out: Array = []
	for b_key in BuildingDatabase.list_keys():
		var def: Dictionary = BuildingDatabase.get_definition(b_key)
		var p: float = float(def.get("produces", {}).get(subject, 0.0))
		if p > 0.0:
			out.append([String(def.get("display_name", b_key)), "[color=%s]+%.0f/min while standing[/color]" % [COL_MUTED, p]])
		var cap: float = float(def.get("raises_cap", {}).get(subject, 0.0))
		if cap > 0.0:
			out.append([String(def.get("display_name", b_key)), "[color=%s]+%d storage cap[/color]" % [COL_MUTED, int(cap)]])
	for r_key in RecipeProcessor.recipe_keys():
		var recipe: Dictionary = RecipeProcessor.get_recipe(r_key)
		var amount: float = float(recipe.get("output", {}).get(subject, 0.0))
		if amount <= 0.0:
			continue
		var b_key: String = recipe.get("building", recipe.get("required_building", ""))
		var bname: String = String(BuildingDatabase.get_definition(b_key).get("display_name", b_key))
		var dur: float = float(recipe.get("duration_seconds", 5.0))
		var from: String = ""
		if recipe.has("input_resource"):
			from = "on a %s deposit" % ResourceManager.display_name(String(recipe["input_resource"]).trim_suffix("_node"))
			var trace: float = float(recipe.get("trace_factor", 0.0))
			if trace > 0.0:
				from += ", ×%s elsewhere" % str(snappedf(trace, 0.01))
		elif not recipe.get("input", {}).is_empty():
			from = "from " + ResourceManager.format_cost(recipe["input"])
		out.append([bname, "[color=%s]+%d per %.0fs (%.1f/min) %s[/color]" % [
			COL_MUTED, int(amount), dur, amount * 60.0 / dur, from,
		]])
	return out


# --- Formatting --------------------------------------------------------------

func _rate_text(rate: float) -> String:
	if is_zero_approx(rate):
		return "[color=%s]±0.0/min[/color]" % COL_MUTED
	if rate > 0.0:
		return "[color=%s]+%.1f/min[/color]" % [COL_UP, rate]
	return "[color=%s]%.1f/min[/color]" % [COL_DOWN, rate]


func _minutes_text(minutes: float) -> String:
	if minutes >= 120.0:
		return "%.1f h" % (minutes / 60.0)
	return "%d min" % int(ceil(minutes))


func _outputs_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	for r in recipe.get("output", {}).keys():
		parts.append("%d %s" % [int(recipe["output"][r]), ResourceManager.display_name(r)])
	return ", ".join(parts)
