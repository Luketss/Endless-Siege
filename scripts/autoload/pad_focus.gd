extends Node
## Gamepad menu navigation: when a pad button or stick moves and no control has focus,
## or the focused control sits on a screen covered by a newer one (and the mouse is not
## captured by the game camera), focus the first button of the top-most open screen,
## so every menu works with the d-pad and A/B. Overlays mark themselves with the
## "screen" meta so they count as their own screen.


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	var vp := get_viewport()
	var owner := vp.gui_get_focus_owner()
	var target := first_button(get_tree().root)
	if target == null:
		return
	if owner != null and owner.is_visible_in_tree():
		var top := _screen_of(target, get_tree().root)
		if top == owner or top.is_ancestor_of(owner):
			return
	target.grab_focus()
	vp.set_input_as_handled()


## First focusable button of the most recently added screen under `root`.
static func first_button(root: Node) -> BaseButton:
	var all: Array[BaseButton] = []
	for n in root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			all.append(b)
	if all.is_empty():
		return null
	var top := _screen_of(all[-1], root)
	for b in all:
		if _screen_of(b, root) == top:
			return b
	return all[-1]


## The ancestor that represents one "screen": the child of a CanvasLayer, of the
## current scene or of the tree root.
static func _screen_of(n: Node, root: Node) -> Node:
	var scene := root.get_tree().current_scene if root.is_inside_tree() else null
	while n.get_parent() and n.get_parent() != root and n.get_parent() != scene and not (n.get_parent() is CanvasLayer) \
			and not n.has_meta("screen"):
		n = n.get_parent()
	return n
