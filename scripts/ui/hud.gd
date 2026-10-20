class_name HUD
extends Control
## In-battle HUD: core/gold, wave status, boss bar, hotbar, hero/abilities, info panel,
## crosshair, synergies and toasts. Pure presentation; updated by the game each frame.

var _core_bar: ProgressBar
var _core_label: Label
var _gold_label: Label
var _title: Label
var _wave_label: Label
var _status: Label
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _speed_label: Label
var _syn_label: RichTextLabel
var _hotbar: HBoxContainer
var _slot_nodes: Array[PanelContainer] = []
var _hero_bar: ProgressBar
var _hero_label: Label
var _xp_bar: ProgressBar
var _abilities: Dictionary = {}
var _info: PanelContainer
var _info_text: RichTextLabel
var _crosshair: Control
var _center_label: Label
var _toasts: VBoxContainer
var _hint: Label
var _vignette: ColorRect
var _objective: PanelContainer
var _hurt := 0.0

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.41;
	COLOR = vec4(0.75, 0.02, 0.02, smoothstep(0.45, 1.0, d) * strength);
}
"""


func _ready() -> void:
	theme = UITheme.get_theme()
	UITheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _panel(parent: Control, preset: int, offset := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.set_anchors_and_offsets_preset(preset)
	p.position += offset
	return p


func _build() -> void:
	# Red edge vignette when the hero is hit or low on health (under everything else).
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VIGNETTE_SHADER
	_vignette.material = mat
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Top-left: core and gold.
	var tl := _panel(self, Control.PRESET_TOP_LEFT, Vector2(20, 20))
	var v := VBoxContainer.new()
	tl.add_child(v)
	_core_label = UITheme.label("")
	v.add_child(_core_label)
	_core_bar = UITheme.bar(Color("5ad1ff"), Vector2(300, 20))
	v.add_child(_core_bar)
	_gold_label = UITheme.label("")
	_gold_label.add_theme_color_override("font_color", UITheme.GOLD)
	_gold_label.add_theme_font_size_override("font_size", 28)
	v.add_child(_gold_label)

	# Top-centre: encounter, wave, status, boss.
	var tc := VBoxContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tc)
	tc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tc.position.y = 18
	tc.custom_minimum_size = Vector2(700, 0)
	tc.position.x -= 350
	_title = UITheme.label("", "Header", HORIZONTAL_ALIGNMENT_CENTER)
	tc.add_child(_title)
	_wave_label = UITheme.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	tc.add_child(_wave_label)
	for l: Label in [_title, _wave_label]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 6)
	_status = UITheme.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_color_override("font_color", UITheme.GOLD)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.add_theme_constant_override("outline_size", 6)
	tc.add_child(_status)
	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	tc.add_child(_boss_box)
	_boss_box.add_child(UITheme.label(Texts.enemy_name("golem"), "", HORIZONTAL_ALIGNMENT_CENTER))
	_boss_bar = UITheme.bar(Color("ff7a2a"), Vector2(700, 26))
	_boss_box.add_child(_boss_bar)
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.add_child(_toasts)

	# Top-right: speed and synergies.
	var tr_panel := _panel(self, Control.PRESET_TOP_RIGHT, Vector2(-20, 20))
	tr_panel.custom_minimum_size = Vector2(320, 0)
	tr_panel.position.x -= 320
	var tv := VBoxContainer.new()
	tr_panel.add_child(tv)
	_speed_label = UITheme.label("", "Dim")
	tv.add_child(_speed_label)
	_syn_label = RichTextLabel.new()
	_syn_label.bbcode_enabled = true
	_syn_label.fit_content = true
	_syn_label.scroll_active = false
	_syn_label.custom_minimum_size = Vector2(300, 0)
	_syn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_syn_label)

	# Bottom-centre: hint + hotbar.
	var bc := VBoxContainer.new()
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bc)
	bc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bc.position.y -= 20
	_hint = UITheme.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hint.add_theme_constant_override("outline_size", 6)
	bc.add_child(_hint)
	_hotbar = HBoxContainer.new()
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bc.add_child(_hotbar)

	# Bottom-left: hero.
	var bl := _panel(self, Control.PRESET_BOTTOM_LEFT, Vector2(20, -20))
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var hv := VBoxContainer.new()
	bl.add_child(hv)
	_hero_label = UITheme.label("")
	hv.add_child(_hero_label)
	_hero_bar = UITheme.bar(UITheme.GOOD, Vector2(300, 18))
	hv.add_child(_hero_bar)
	_xp_bar = UITheme.bar(Color("b26bff"), Vector2(300, 8))
	hv.add_child(_xp_bar)
	var ab := HBoxContainer.new()
	hv.add_child(ab)
	for key in ["attack", "ability_1", "ability_2", "dodge"]:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(68, 0)
		var bar := UITheme.bar(Color("8fd1ff"), Vector2(64, 8))
		var name := UITheme.label("", "Small", HORIZONTAL_ALIGNMENT_CENTER)
		var keyl := UITheme.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
		cell.add_child(keyl)
		cell.add_child(bar)
		cell.add_child(name)
		ab.add_child(cell)
		_abilities[key] = {"bar": bar, "name": name, "key": keyl}

	# Right: info panel.
	_info = _panel(self, Control.PRESET_CENTER_RIGHT, Vector2(-20, 0))
	_info.custom_minimum_size = Vector2(340, 0)
	_info.position.x -= 340
	_info_text = RichTextLabel.new()
	_info_text.bbcode_enabled = true
	_info_text.fit_content = true
	_info_text.scroll_active = false
	_info_text.custom_minimum_size = Vector2(320, 0)
	_info_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_info_text)
	_info.visible = false

	# Left: tutorial objective.
	_objective = _panel(self, Control.PRESET_CENTER_LEFT, Vector2(20, -60))
	_objective.custom_minimum_size = Vector2(360, 0)
	var ov := VBoxContainer.new()
	_objective.add_child(ov)
	var ot := UITheme.label("", "Small")
	ot.add_theme_color_override("font_color", UITheme.GOLD)
	ov.add_child(ot)
	var ob := UITheme.label("")
	ob.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ob.custom_minimum_size = Vector2(340, 0)
	ov.add_child(ob)
	_objective.set_meta("title", ot)
	_objective.set_meta("body", ob)
	_objective.visible = false

	# Crosshair and centre messages.
	_crosshair = Crosshair.new()
	add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_label = UITheme.label("", "Header", HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_center_label)
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center_label.position.y += 70


## Tutorial objective card (hidden when `body` is empty).
func set_objective(title: String, body: String) -> void:
	_objective.visible = body != ""
	(_objective.get_meta("title") as Label).text = title
	(_objective.get_meta("body") as Label).text = body


## Pulses the damage vignette; `ratio` is the hit size relative to max health.
func flash_damage(ratio: float) -> void:
	_hurt = clampf(_hurt + 0.45 + ratio * 2.0, 0.0, 1.0)


func _update_vignette(sim: BattleSim) -> void:
	_hurt = maxf(0.0, _hurt - get_process_delta_time() * 1.6)
	var low := 0.0
	if sim.hero.alive and sim.hero.hp < sim.hero.max_hp * 0.3:
		low = 0.25 + 0.12 * sin(Time.get_ticks_msec() / 160.0)
	var s := maxf(_hurt, low)
	_vignette.visible = s > 0.01
	(_vignette.material as ShaderMaterial).set_shader_parameter("strength", s)


func build_hotbar(slots: Array[String]) -> void:
	for c in _hotbar.get_children():
		c.queue_free()
	_slot_nodes.clear()
	for i in slots.size():
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(118, 82)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var key := UITheme.label("", "Small")
		key.name = "key"
		v.add_child(key)
		var name := UITheme.label(Texts.structure_name(slots[i]), "Small", HORIZONTAL_ALIGNMENT_CENTER)
		name.name = "name"
		v.add_child(name)
		var cost := UITheme.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
		cost.name = "cost"
		v.add_child(cost)
		p.set_meta("type", slots[i])
		p.set_meta("key", key)
		p.set_meta("cost", cost)
		_hotbar.add_child(p)
		_slot_nodes.append(p)


func toast(text: String, color: Color = UITheme.TEXT) -> void:
	var l := UITheme.label(text, "", HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	_toasts.add_child(l)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## state: {"title", "wave", "waves", "phase": "build"|"wave"|"idle", "speed": float}
func refresh(sim: BattleSim, state: Dictionary, build: BuildController) -> void:
	_update_vignette(sim)
	_crosshair.visible = state.get("captured", true)
	_core_label.text = "%s  %d / %d" % [tr("HUD_CORE"), int(ceil(sim.core_hp)), int(sim.core_max)]
	_core_bar.max_value = sim.core_max
	_core_bar.value = sim.core_hp
	_gold_label.text = "◆ %d" % sim.gold
	_title.text = state.get("title", "")
	var phase: String = state.get("phase", "idle")
	var waves_total := int(state.get("waves", 0))
	_wave_label.text = tr("HUD_WAVE") % [mini(int(state.get("wave", 0)) + 1, waves_total), waves_total] if waves_total > 0 else ""
	match phase:
		"build":
			_status.text = tr("HUD_BUILD_PHASE") % Settings.action_label("start_wave")
		"wave":
			_status.text = tr("HUD_ENEMIES") % (sim.enemies.size() + sim.spawn_queue.size())
		_:
			_status.text = ""
	var boss: Units.Enemy = null
	for e: Units.Enemy in sim.enemies:
		if e.boss and e.alive:
			boss = e
	_boss_box.visible = boss != null
	if boss:
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
	_speed_label.text = "%s x%.1f  [%s]" % [tr("HUD_SPEED"), float(state.get("speed", 1.0)), Settings.action_label("game_speed")]
	var syn := ""
	for s in sim.mods.active_synergies:
		syn += "[color=#c9a6ff]✦ %s[/color]\n" % Texts.synergy_name(s)
	syn += "[color=#9a9fb0]%s: %d[/color]" % [tr("HUD_UPGRADES"), sim.mods.upgrades.size()]
	_syn_label.text = syn
	_refresh_hotbar(sim, build)
	_refresh_hero(sim)
	_refresh_info(sim, build)
	_hint.text = tr("HUD_HINT") % [Settings.action_label("upgrade"), Settings.action_label("sell"), Settings.action_label("target_mode"), Settings.action_label("show_ranges")]
	if not sim.hero.alive:
		_center_label.text = tr("HUD_RESPAWN") % ceil(sim.hero.respawn_t)
	elif not sim.cache.is_empty() and sim.hero.pos.distance_to(sim.cache.pos) < 3.0:
		_center_label.text = tr("HUD_INTERACT") % Settings.action_label("interact")
	else:
		_center_label.text = ""


func _refresh_hotbar(sim: BattleSim, build: BuildController) -> void:
	for i in _slot_nodes.size():
		var p := _slot_nodes[i]
		var type: String = p.get_meta("type")
		var cost := sim.structure_cost(type)
		(p.get_meta("key") as Label).text = Settings.action_label("slot_%d" % (i + 1))
		var cl: Label = p.get_meta("cost")
		cl.text = "◆ %d" % cost
		cl.add_theme_color_override("font_color", UITheme.GOLD if sim.gold >= cost else UITheme.BAD)
		var selected := build.selected == type
		p.add_theme_stylebox_override("panel", UITheme.box(Color(0.2, 0.17, 0.08, 0.95) if selected else UITheme.PANEL, 8,
			UITheme.GOLD if selected else UITheme.BORDER, 3 if selected else 2, 8))


func _refresh_hero(sim: BattleSim) -> void:
	var h := sim.hero
	_hero_label.text = "%s  %s %d" % [tr(h.def.name_key), tr("HUD_LEVEL"), h.level]
	_hero_bar.max_value = h.max_hp
	_hero_bar.value = h.hp
	var nxt := sim.xp_to_next()
	var curve: Array = h.def.xp_curve
	var prev := 0.0 if h.level <= 1 else float(curve[h.level - 2])
	_xp_bar.max_value = 1.0
	_xp_bar.value = 1.0 if nxt < 0.0 else clampf((h.xp - prev) / maxf(1.0, nxt - prev), 0.0, 1.0)
	var cds := {
		"attack": [h.attack_cd, float(h.def.attack.interval), "AB_SWING" if h.def.attack.get("melee", false) else "AB_ATTACK"],
		"ability_1": [h.rain_cd, sim.ability_cooldown(0), "AB_" + sim.ability_id(0).to_upper()],
		"ability_2": [h.blast_cd, sim.ability_cooldown(1), "AB_" + sim.ability_id(1).to_upper()],
		"dodge": [h.dodge_cd, float(h.def.dodge.cooldown), "AB_DODGE"],
	}
	for k in cds:
		var a: Dictionary = _abilities[k]
		var cd: Array = cds[k]
		(a.bar as ProgressBar).max_value = 1.0
		(a.bar as ProgressBar).value = 1.0 - clampf(float(cd[0]) / maxf(0.01, float(cd[1])), 0.0, 1.0)
		(a.name as Label).text = tr(cd[2])
		(a.key as Label).text = Settings.action_label(k)
		(a.key as Label).modulate = Color.WHITE if float(cd[0]) <= 0.0 else Color(1, 1, 1, 0.4)


func _refresh_info(sim: BattleSim, build: BuildController) -> void:
	var txt := ""
	if build.selected != "":
		var def := DataDB.structure(build.selected)
		txt = "[b][color=#f2c14e]%s[/color][/b]  ◆ %d\n%s" % [Texts.structure_name(build.selected), sim.structure_cost(build.selected), tr(def.desc_key)]
		if not build.last_check.is_empty() and not build.last_check.ok:
			txt += "\n[color=#ff5a4f]%s[/color]" % tr(build.last_check.reason)
		txt += "\n[color=#9a9fb0]%s[/color]" % (tr("HUD_PLACE_HINT") % [Settings.action_label("attack"), Settings.action_label("cancel")])
	elif build.hovered:
		var st := build.hovered
		txt = "[b][color=#f2c14e]%s[/color][/b]  %s %d\n" % [Texts.structure_name(st.type), tr("HUD_LEVEL"), st.level]
		if st.kind == "tower":
			txt += "%s %.0f · %s %.1f · %s %.2f/s\n" % [tr("ST_DAMAGE"), sim.tower_damage(st), tr("ST_RANGE"), sim.tower_range(st), tr("ST_RATE"), sim.tower_rate(st)]
			txt += "%s: %s\n" % [tr("ST_TARGET"), tr("TARGET_" + st.target_mode.to_upper())]
		txt += "%s %d · %s %.0f\n" % [tr("ST_KILLS"), st.kills, tr("ST_DEALT"), st.damage_done]
		if st.disabled_t > 0.0:
			txt += "[color=#b05ad0]%s[/color]\n" % tr("ST_DISABLED")
		var up := sim.upgrade_cost(st)
		if up >= 0:
			txt += "[%s] %s ◆ %d\n" % [Settings.action_label("upgrade"), tr("ACT_UPGRADE"), up]
		txt += "[%s] %s ◆ %d" % [Settings.action_label("sell"), tr("ACT_SELL"), sim.sell_value(st)]
		if st.kind == "tower":
			txt += "\n[%s] %s" % [Settings.action_label("target_mode"), tr("ACT_TARGET")]
	_info.visible = txt != ""
	_info_text.text = txt


class Crosshair:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 24)

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 7.0, 0, TAU, 24, Color(1, 1, 1, 0.85), 2.0, true)
		draw_circle(c, 1.6, Color.WHITE)
