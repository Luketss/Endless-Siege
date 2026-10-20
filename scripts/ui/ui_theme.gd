class_name UITheme
extends RefCounted
## Shared UI theme and small widget helpers.

const BG := Color("0f1116")
const PANEL := Color(0.09, 0.1, 0.13, 0.92)
const PANEL_LIGHT := Color("232734")
const BORDER := Color("3a3f52")
const TEXT := Color("ece6da")
const DIM := Color("9a9fb0")
const GOLD := Color("f2c14e")
const GOOD := Color("5ad17a")
const BAD := Color("ff5a4f")
const RARITY := {"common": Color("b9c0cc"), "rare": Color("4fa3ff"), "epic": Color("b26bff"), "legendary": Color("ffb23f")}
const NODE_COLORS := {"combat": Color("d4d8e0"), "elite": Color("ff6a4f"), "shop": Color("f2c14e"),
	"event": Color("8fd1ff"), "rest": Color("5ad17a"), "boss": Color("ff3b3b")}

static var _theme: Theme


static func box(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, bw: int = 0, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL_LIGHT, 8, BORDER, 2, 12))
	t.set_stylebox("hover", "Button", box(PANEL_LIGHT.lightened(0.1), 8, GOLD.darkened(0.3), 2, 12))
	t.set_stylebox("pressed", "Button", box(PANEL_LIGHT.darkened(0.2), 8, GOLD, 2, 12))
	t.set_stylebox("hover_pressed", "Button", box(PANEL_LIGHT.darkened(0.2), 8, GOLD, 2, 12))
	t.set_stylebox("disabled", "Button", box(Color(0.12, 0.12, 0.15), 8, Color(0.2, 0.2, 0.24), 2, 12))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, 8, GOLD, 2, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 12, BORDER, 2, 18))
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", box(GOLD.darkened(0.15), 8, GOLD, 2, 14))
	t.set_stylebox("hover", "Primary", box(GOLD, 8, Color.WHITE, 2, 14))
	t.set_stylebox("pressed", "Primary", box(GOLD.darkened(0.3), 8, GOLD, 2, 14))
	t.set_color("font_color", "Primary", BG)
	t.set_color("font_hover_color", "Primary", BG)
	t.set_color("font_pressed_color", "Primary", BG)
	t.set_font_size("font_size", "Primary", 26)
	t.set_type_variation("Title", "Label")
	t.set_font_size("font_size", "Title", 72)
	t.set_color("font_color", "Title", GOLD)
	t.set_color("font_outline_color", "Title", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Title", 14)
	t.set_type_variation("Header", "Label")
	t.set_font_size("font_size", "Header", 34)
	t.set_color("font_color", "Header", GOLD)
	t.set_type_variation("Dim", "Label")
	t.set_color("font_color", "Dim", DIM)
	t.set_font_size("font_size", "Dim", 18)
	t.set_type_variation("Small", "Label")
	t.set_font_size("font_size", "Small", 16)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_font_size("bold_font_size", "RichTextLabel", 20)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.6), 6, BORDER, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(GOOD, 6, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("panel", "TabContainer", box(PANEL, 8, BORDER, 2, 16))
	t.set_stylebox("tab_selected", "TabContainer", box(PANEL_LIGHT, 6, GOLD, 2, 10))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.1, 0.11, 0.14), 6, BORDER, 1, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL_LIGHT, 6, BORDER, 1, 10))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	_theme = t
	return t


static func label(text: String, variation: String = "", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l


static func button(text: String, primary: bool = false, min_size := Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if primary:
		b.theme_type_variation = "Primary"
	b.pressed.connect(func(): Sfx.play("ui"))
	return b


static func bar(color: Color, min_size := Vector2(260, 22)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = min_size
	p.show_percentage = false
	p.add_theme_stylebox_override("fill", box(color, 6, Color.TRANSPARENT, 0, 0))
	return p


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func dimmer() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.55)
	full_rect(d)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d
