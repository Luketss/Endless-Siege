class_name JourneyPanel
extends Control
## Journey map: layered encounter graph drawn left-to-right. Reachable nodes are buttons;
## visited path highlighted; tooltips preview the encounter type and likely reward.
## Side panel shows the run (core, gold, upgrades, synergies).

signal node_chosen(id: String)
signal save_and_quit

var run: RunState
var _buttons := {}
var _graph: Control
var _info: RichTextLabel


func setup(p_run: RunState) -> void:
	run = p_run
	theme = UITheme.get_theme()
	UITheme.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.72)
	UITheme.full_rect(dim)
	add_child(dim)
	var margin := MarginContainer.new()
	UITheme.full_rect(margin)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	margin.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UITheme.label(tr("JOURNEY_TITLE"), "Title"))
	left.add_child(UITheme.label(tr("JOURNEY_SUB"), "Dim"))
	_graph = Control.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.draw.connect(_draw_links)
	_graph.resized.connect(_layout_nodes)
	left.add_child(_graph)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	h.add_child(side)
	var sv := VBoxContainer.new()
	side.add_child(sv)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.custom_minimum_size = Vector2(380, 0)
	sv.add_child(_info)
	var quit := UITheme.button(tr("JOURNEY_SAVE_QUIT"))
	quit.pressed.connect(func(): save_and_quit.emit())
	sv.add_child(quit)
	_build_nodes()
	refresh()


func refresh() -> void:
	var txt := "[font_size=28][color=#f2c14e]%s[/color][/font_size]\n" % tr("JOURNEY_STATUS")
	txt += "%s: %d / %d\n◆ %d\n%s: %d\n\n" % [tr("HUD_CORE"), int(run.core_hp), int(run.core_max()), run.gold, tr("HUD_LEVEL"), run.hero_level]
	var mods := run.mods()
	if not mods.active_synergies.is_empty():
		txt += "[color=#c9a6ff]%s[/color]\n" % tr("JOURNEY_SYNERGIES")
		for s in mods.active_synergies:
			txt += "✦ %s\n[color=#9a9fb0]%s[/color]\n" % [Texts.synergy_name(s), Texts.synergy_desc(s)]
		txt += "\n"
	txt += "[color=#f2c14e]%s (%d)[/color]\n" % [tr("HUD_UPGRADES"), run.upgrades.size()]
	for id in run.upgrades:
		var col: Color = UITheme.RARITY[DataDB.upgrade(id).rarity]
		txt += "[color=#%s]• %s[/color]\n" % [col.to_html(false), Texts.upgrade_name(id)]
	if not run.modifiers.is_empty():
		txt += "\n[color=#ff6a4f]%s[/color]\n" % tr("MENU_CHALLENGES")
		for m in run.modifiers:
			txt += "• %s\n" % tr(DataDB.modifiers()[m].name_key)
	_info.text = txt
	var choices := Journey.choices(run.journey, run.current_node)
	var ids := choices.map(func(n): return n.id)
	for id in _buttons:
		var b: Button = _buttons[id]
		b.disabled = not ids.has(id)
		var visited := run.visited.has(id)
		var node := Journey.find(run.journey, id)
		var col: Color = UITheme.NODE_COLORS[node.type]
		var bw := 4 if ids.has(id) else 2
		var bg := col.darkened(0.55) if visited else Color(0.08, 0.09, 0.12)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UITheme.box(bg if st != "hover" else col.darkened(0.3), 40, col if (ids.has(id) or visited) else col.darkened(0.5), bw, 6))
		b.modulate = Color.WHITE if (ids.has(id) or visited) else Color(1, 1, 1, 0.5)
	_graph.queue_redraw()


func _build_nodes() -> void:
	for layer in run.journey.layers:
		for node in layer:
			var b := Button.new()
			b.custom_minimum_size = Vector2(124, 70)
			b.text = Texts.node_name(node.type)
			b.add_theme_font_size_override("font_size", 18)
			b.tooltip_text = "%s\n%s" % [Texts.node_name(node.type), Texts.node_reward(node.type)]
			var id: String = node.id
			b.pressed.connect(func():
				Sfx.play("ui")
				node_chosen.emit(id))
			_graph.add_child(b)
			_buttons[id] = b
	_layout_nodes.call_deferred()


func _node_pos(node: Dictionary) -> Vector2:
	var layers: Array = run.journey.layers
	var n_layers := layers.size()
	var count: int = layers[node.layer].size()
	var w := _graph.size.x
	var h := _graph.size.y
	var x := 70.0 + (w - 140.0) * float(node.layer) / maxf(1, n_layers - 1)
	var y := h * 0.5 if count == 1 else 80.0 + (h - 160.0) * float(node.index) / (count - 1)
	return Vector2(x, y)


func _layout_nodes() -> void:
	for layer in run.journey.layers:
		for node in layer:
			var b: Button = _buttons[node.id]
			b.position = _node_pos(node) - b.custom_minimum_size * 0.5
	_graph.queue_redraw()


func _draw_links() -> void:
	for layer in run.journey.layers:
		for node in layer:
			var a := _node_pos(node)
			for link in node.links:
				var other := Journey.find(run.journey, link)
				var b := _node_pos(other)
				var walked: bool = run.visited.has(node.id) and run.visited.has(link)
				var next: bool = node.id == run.current_node
				var col := UITheme.GOLD if walked else (Color(1, 1, 1, 0.55) if next else Color(1, 1, 1, 0.15))
				_graph.draw_line(a, b, col, 4.0 if walked or next else 2.0, true)
