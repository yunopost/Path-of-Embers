extends RefCounted

## Shared drag-and-drop plumbing for equipment tiles (Card-Clock Spec Addendum
## B §2/§5). Every equipment tile in the game (Loadout stash, Loadout equip
## slots, the map-screen backpack panel) is built in code with no custom
## Control subclass, so this uses Control.set_drag_forwarding() rather than
## overriding _get_drag_data/_can_drop_data/_drop_data on a subclass -- the
## same "no class_name, preload as a const" pattern as DebugPanel.gd / PreRunChrome.gd.
##
## Drag payload shape: {"type": "equipment", "equipment_id": String,
##   "source": "stash"|"backpack"|"slot", "index": int (backpack only),
##   "char_id": String (slot only), "slot_name": String (slot only)}
##
## Rule (spec §5): an illegal drop must tell the player why, not silently
## snap back. So can_drop_data() always accepts our payload type -- the real
## legality check happens inside drop_data(), which shows a message on failure
## instead of performing the move.

const TYPE_EQUIPMENT := "equipment"

static func make_drag_preview(text: String) -> Control:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A1F2BEE")
	style.set_border_width_all(2)
	style.border_color = Color("#E8A020")
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate = Color(1, 1, 1, 0.9)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("#F0E6C8"))
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	return panel

static func attach_source(control: Control, payload: Dictionary, preview_text: String) -> void:
	## Makes `control` draggable, carrying `payload` (an equipment drag payload,
	## see module doc). Preserves any existing drop-target behaviour already
	## set via set_drag_forwarding by only touching the get_drag_data slot.
	var get_data := func(_pos: Vector2):
		control.set_drag_preview(make_drag_preview(preview_text))
		return payload
	control.set_drag_forwarding(get_data, Callable(), Callable())

static func attach_target(control: Control, can_drop: Callable, do_drop: Callable) -> void:
	## Makes `control` a drop target. `can_drop(pos, data)` should just check
	## the payload TYPE (always true for our equipment payloads -- see module
	## doc); `do_drop(pos, data)` performs the move and is responsible for
	## showing a message if the specific item/slot combination is illegal.
	var can_drop_wrapped := func(_pos: Vector2, data):
		return data is Dictionary and data.get("type", "") == TYPE_EQUIPMENT and can_drop.call(_pos, data)
	control.set_drag_forwarding(Callable(), can_drop_wrapped, do_drop)

static func attach_source_and_target(control: Control, payload: Dictionary, preview_text: String, can_drop: Callable, do_drop: Callable) -> void:
	## Combined helper for tiles that are both a drag source and a drop target
	## (e.g. a backpack slot: you can drag gear OUT of it, and drop gear INTO it).
	var get_data := func(_pos: Vector2):
		control.set_drag_preview(make_drag_preview(preview_text))
		return payload
	var can_drop_wrapped := func(_pos: Vector2, data):
		return data is Dictionary and data.get("type", "") == TYPE_EQUIPMENT and can_drop.call(_pos, data)
	control.set_drag_forwarding(get_data, can_drop_wrapped, do_drop)
