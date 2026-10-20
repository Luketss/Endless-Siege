class_name Panels
extends RefCounted
## Overlay panels used between encounters. Each is a full-screen Control returned by a
## static builder; callers connect to the callbacks they pass in.


static func _overlay() -> Control:
	var root := Control.new()
	root.theme = UITheme.get_theme()
	UITheme.full_rect(root)
	root.add_child(UITheme.dimmer())
	return root


static func _center_panel(root: Control, min_width: float = 640.0) -> VBoxContainer:
	var center := CenterContainer.new()
	UITheme.full_rect(center)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	return v


static func _rich(text: String, width: float = 600.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(width, 0)
	r.text = text
	return r


# ---------------------------------------------------------------- upgrade cards

static func upgrade_card(id: String, mods: RunMods, footer: Control = null) -> PanelContainer:
	var u := DataDB.upgrade(id)
	var rarity: String = u.rarity
	var col: Color = UITheme.RARITY[rarity]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(330, 420)
	card.add_theme_stylebox_override("panel", UITheme.box(Color(0.08, 0.09, 0.12, 0.97), 14, col, 3, 20))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var r := UITheme.label(Texts.rarity_name(rarity).to_upper(), "Small", HORIZONTAL_ALIGNMENT_CENTER)
	r.add_theme_color_override("font_color", col)
	v.add_child(r)
	var name := UITheme.label(Texts.upgrade_name(id), "Header", HORIZONTAL_ALIGNMENT_CENTER)
	name.add_theme_color_override("font_color", col.lightened(0.2))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size = Vector2(290, 0)
	v.add_child(name)
	var desc := _rich(Texts.upgrade_desc(id), 290)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var tags := UITheme.label(Texts.tags_text(u.get("tags", [])), "Dim", HORIZONTAL_ALIGNMENT_CENTER)
	tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags.custom_minimum_size = Vector2(290, 0)
	v.add_child(tags)
	if mods:
		var syns := mods.synergies_unlocked_by(u.get("tags", []))
		for s in syns:
			var l := UITheme.label("✦ %s %s" % [TranslationServer.translate("CARD_ACTIVATES"), Texts.synergy_name(s)], "Small", HORIZONTAL_ALIGNMENT_CENTER)
			l.add_theme_color_override("font_color", Color("c9a6ff"))
			v.add_child(l)
	if footer:
		v.add_child(footer)
	return card


static func reward(choices: Array, mods: RunMods, title: String, on_pick: Callable, on_skip: Callable, skip_gold: int) -> Control:
	var root := _overlay()
	var center := CenterContainer.new()
	UITheme.full_rect(center)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	center.add_child(v)
	v.add_child(UITheme.label(title, "Title", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UITheme.label(TranslationServer.translate("REWARD_SUB"), "Dim", HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	v.add_child(row)
	for i in choices.size():
		var id: String = choices[i]
		var b := UITheme.button("%s  [%d]" % [TranslationServer.translate("CARD_TAKE"), i + 1], true)
		b.pressed.connect(func(): on_pick.call(id))
		b.name = "take_%d" % i
		row.add_child(upgrade_card(id, mods, b))
	if on_skip.is_valid():
		var skip := UITheme.button(TranslationServer.translate("REWARD_SKIP") % skip_gold)
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skip.pressed.connect(func(): on_skip.call())
		v.add_child(skip)
	return root


# ---------------------------------------------------------------- shop

static func shop(run: RunState, offer: Dictionary, on_change: Callable, on_leave: Callable) -> Control:
	var root := _overlay()
	var center := CenterContainer.new()
	UITheme.full_rect(center)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)
	v.add_child(UITheme.label(TranslationServer.translate("NODE_SHOP"), "Title", HORIZONTAL_ALIGNMENT_CENTER))
	var gold := UITheme.label("", "Header", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(gold)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	var buttons := []
	var refresh := func():
		gold.text = "◆ %d    %s %d/%d" % [run.gold, TranslationServer.translate("HUD_CORE"), int(run.core_hp), int(run.core_max())]
		for pair in buttons:
			var b: Button = pair[0]
			var item: Dictionary = pair[1]
			if item.is_empty():
				b.disabled = run.gold < int(offer.repair_cost) or run.core_hp >= run.core_max()
			else:
				var owned := run.upgrades.has(item.id)
				b.disabled = owned or run.gold < int(item.price)
				b.text = TranslationServer.translate("SHOP_OWNED") if owned else "◆ %d" % int(item.price)
	for item in offer.items:
		var b := UITheme.button("", true)
		b.pressed.connect(func():
			if RunFlow.buy(run, item):
				Sfx.play("gold")
				refresh.call()
				on_change.call())
		buttons.append([b, item])
		row.add_child(upgrade_card(item.id, run.mods(), b))
	var repair := UITheme.button(TranslationServer.translate("SHOP_REPAIR") % [int(offer.repair_amount), int(offer.repair_cost)])
	repair.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	repair.pressed.connect(func():
		if RunFlow.repair(run, int(offer.repair_cost), float(offer.repair_amount)):
			Sfx.play("upgrade")
			refresh.call()
			on_change.call())
	buttons.append([repair, {}])
	v.add_child(repair)
	var leave := UITheme.button(TranslationServer.translate("CONTINUE"), false, Vector2(260, 56))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func(): on_leave.call())
	v.add_child(leave)
	refresh.call()
	return root


# ---------------------------------------------------------------- generic dialog (events, rest, results)

## options: [{"text": String, "disabled": bool, "callback": Callable}]
static func dialog(title: String, body: String, options: Array) -> Control:
	var root := _overlay()
	var v := _center_panel(root, 720)
	v.add_child(UITheme.label(title, "Header", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_rich(body, 680))
	for o in options:
		var b := UITheme.button(o.text)
		b.disabled = o.get("disabled", false)
		var cb: Callable = o.callback
		b.pressed.connect(func(): cb.call())
		v.add_child(b)
	return root


static func cost_text(choice: Dictionary) -> String:
	var parts := []
	var cost: Dictionary = choice.get("cost", {})
	if cost.has("gold"):
		parts.append("◆ %d" % int(cost.gold))
	if cost.has("core_hp"):
		parts.append("-%d %s" % [int(cost.core_hp), TranslationServer.translate("HUD_CORE")])
	return "" if parts.is_empty() else "  (%s)" % ", ".join(parts)
