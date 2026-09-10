extends Node
## Headless layout check for ShopScreen at two window sizes.
func _ready():
	PartyManager.party_ids = ["warrior_1", "witch", "golemancer"]
	ResourceManager.set_gold(500)
	for sz in [Vector2(1920, 1080), Vector2(1280, 720)]:
		var host := Control.new()
		host.size = sz
		add_child(host)
		var shop = load("res://scenes/screens/ShopScreen.tscn").instantiate()
		host.add_child(shop)
		shop.size = sz
		await get_tree().process_frame
		await get_tree().process_frame
		print("--- window ", sz)
		_dump(shop, 0, sz)
		host.queue_free()
		await get_tree().process_frame
	get_tree().quit()

func _dump(c: Control, depth: int, win: Vector2):
	var r := c.get_global_rect()
	var off := r.position.x < 0 or r.position.y < 0 or r.end.x > win.x or r.end.y > win.y
	if depth <= 9 and (c is Button or c is PanelContainer or c is ScrollContainer or c is Label):
		print("  ".repeat(depth), c.get_class(), " '", (c.text if "text" in c else ""), "' rect=", r, (" OFFSCREEN" if off else ""))
	for ch in c.get_children():
		if ch is Control:
			_dump(ch, depth + 1, win)
