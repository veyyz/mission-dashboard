extends PanelContainer
## Middle-left scrollable log. Subscribes to EventBus.log_message.
## Filter tabs deferred — Phase 8 polish.

const MAX_ENTRIES: int = 80

@onready var vbox: VBoxContainer = $Margin/VBox/Scroll/MessageList
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll


func _ready() -> void:
	EventBus.log_message.connect(_on_log_message)


func _on_log_message(message: String, category: String) -> void:
	var lbl := Label.new()
	lbl.text = "[%s] %s" % [category, message]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", _color_for_category(category))
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)
	# Cap the message list so we don't grow unbounded.
	while vbox.get_child_count() > MAX_ENTRIES:
		var first: Node = vbox.get_child(0)
		vbox.remove_child(first)
		first.queue_free()
	# Auto-scroll to bottom on new message.
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _color_for_category(category: String) -> Color:
	match category:
		"selection": return Color(0.36, 0.71, 0.84)
		"build":     return Color(0.95, 0.71, 0.30)
		"alert":     return Color(0.92, 0.40, 0.45)
		_:           return Color(0.85, 0.88, 0.92)
