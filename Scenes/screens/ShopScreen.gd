extends Control

## Shop screen — sells cards, upgrade point bundles, transcendence, and equipment.
##
## Stock is generated once when the screen opens (or read from RunState.pending_rewards
## if the node stored a pre-built bundle). All items are priced and purchased with gold.
##
## Layout (all built in code):
##   Title | Gold label
##   ── Cards (5, mixed rarity) ──────────────────────────────────────────
##   ── Upgrade bundles (2) + Transcendence (1) ─────────────────────────
##   ── Equipment (2) ────────────────────────────────────────────────────
##   Leave button

# ── Prices ───────────────────────────────────────────────────────────────────
const CARD_PRICE: Dictionary = {
	CardData.Rarity.COMMON:   30,
	CardData.Rarity.UNCOMMON: 45,
	CardData.Rarity.RARE:     60,
}
# Three upgrade bundle tiers: { pts, price }
const UPGRADE_BUNDLES: Array = [
	{ "pts": 5,  "price": 10 },
	{ "pts": 10, "price": 20 },
	{ "pts": 20, "price": 40 },
]
const TRANSCENDENCE_PRICE: int = 130
const EQUIP_PRICE: Dictionary = {
	EquipmentData.Rarity.COMMON:   80,
	EquipmentData.Rarity.UNCOMMON: 120,
	EquipmentData.Rarity.RARE:     160,
}
## Drop-weight table: Common 50%, Uncommon 35%, Rare 15%.
const EQUIP_DROP_WEIGHT: Dictionary = {
	EquipmentData.Rarity.COMMON:   50,
	EquipmentData.Rarity.UNCOMMON: 35,
	EquipmentData.Rarity.RARE:     15,
}

# ── Persistent stock (kept for current node visit only) ───────────────────────
# Each entry: { "type": "card"/"upgrade_bundle"/"transcendence"/"equipment",
#               "id": String, "price": int, "sold": bool }
var _stock: Array = []

# ── UI refs ───────────────────────────────────────────────────────────────────
var _gold_label: Label = null
var _stock_container: VBoxContainer = null

func _ready():
	initialize()

func initialize():
	_generate_stock()
	_build_ui()
	refresh_from_state()

func refresh_from_state():
	if _gold_label and ResourceManager:
		_gold_label.text = "Gold: %d" % ResourceManager.gold
	_refresh_stock_buttons()

# ── Stock generation ──────────────────────────────────────────────────────────

func _generate_stock():
	_stock.clear()

	# 5 cards (mixed rarity using reward pool + pity system)
	var card_pool = RunState.reward_card_pool if RunState else []
	if not card_pool.is_empty():
		var used_ids: Array[String] = []
		for _i in range(5):
			var available = card_pool.filter(func(c): return not used_ids.has(c.id))
			if available.is_empty():
				break
			var picked: CardData = available[randi() % available.size()]
			used_ids.append(picked.id)
			var price = CARD_PRICE.get(picked.rarity, 50)
			_stock.append({ "type": "card", "id": picked.id, "price": price, "sold": false })

	# 3 upgrade point bundles (small / medium / large)
	for bundle in UPGRADE_BUNDLES:
		_stock.append({ "type": "upgrade_bundle", "id": "", "pts": bundle["pts"], "price": bundle["price"], "sold": false })

	# 1 transcendence upgrade
	_stock.append({ "type": "transcendence", "id": "", "price": TRANSCENDENCE_PRICE, "sold": false })

	# 2 equipment items — weighted by rarity (Common 50% / Uncommon 35% / Rare 15%)
	var all_equip = DataRegistry.get_all_equipment() if DataRegistry else []
	if not all_equip.is_empty():
		var picked_ids: Array[String] = []
		var attempts: int = 0
		while picked_ids.size() < 2 and attempts < 100:
			attempts += 1
			var chosen = _pick_weighted_equipment(all_equip, picked_ids)
			if chosen:
				picked_ids.append(chosen.id)
				var price = EQUIP_PRICE.get(chosen.rarity, 100)
				_stock.append({ "type": "equipment", "id": chosen.id, "price": price, "sold": false })

func _pick_weighted_equipment(pool: Array, exclude_ids: Array[String]):
	## Pick a random EquipmentData from pool using EQUIP_DROP_WEIGHT rarity weights.
	## Excludes any IDs already in exclude_ids. Returns null if no eligible item found.
	var eligible: Array = []
	for equip in pool:
		if not exclude_ids.has(equip.id):
			eligible.append(equip)
	if eligible.is_empty():
		return null
	# Build cumulative weight table
	var total_weight: int = 0
	var weights: Array[int] = []
	for equip in eligible:
		var w: int = EQUIP_DROP_WEIGHT.get(equip.rarity, 50)
		total_weight += w
		weights.append(total_weight)
	# Roll
	var roll: int = randi() % total_weight
	for i in eligible.size():
		if roll < weights[i]:
			return eligible[i]
	return eligible[-1]


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui():
	# Clear any existing children (e.g. the placeholder Label from the .tscn)
	for child in get_children():
		child.queue_free()

	var root_vbox = VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	add_child(root_vbox)

	# Header row
	var header = HBoxContainer.new()
	root_vbox.add_child(header)

	var title = Label.new()
	title.text = "Shop"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 0"
	_gold_label.add_theme_font_size_override("font_size", 18)
	header.add_child(_gold_label)

	# Scrollable stock area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_stock_container = VBoxContainer.new()
	_stock_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_stock_container)

	# Leave button
	var leave_btn = Button.new()
	leave_btn.text = "Leave Shop"
	leave_btn.custom_minimum_size = Vector2(160, 44)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.pressed.connect(_on_leave_pressed)
	root_vbox.add_child(leave_btn)

func _refresh_stock_buttons():
	if not _stock_container:
		return
	for child in _stock_container.get_children():
		_stock_container.remove_child(child)
		child.queue_free()

	for i in range(_stock.size()):
		var item: Dictionary = _stock[i]
		var row = _build_stock_row(item, i)
		_stock_container.add_child(row)

func _build_stock_row(item: Dictionary, index: int) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Left: item description label
	var desc_lbl = Label.new()
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	match item["type"]:
		"card":
			var cd = DataRegistry.get_card_data(item["id"]) if DataRegistry else null
			var rarity_str = _rarity_name(cd.rarity if cd else CardData.Rarity.COMMON)
			desc_lbl.text = "[Card] %s (%s)" % [cd.name if cd else item["id"], rarity_str]
		"upgrade_bundle":
			desc_lbl.text = "[Upgrade] +%d Upgrade Points" % item.get("pts", 5)
		"transcendence":
			desc_lbl.text = "[Transcendence] 1 Transcendence Upgrade"
		"equipment":
			var ed = DataRegistry.get_equipment(item["id"]) if DataRegistry else null
			var rarity_str = _equip_rarity_name(ed.rarity if ed else EquipmentData.Rarity.COMMON)
			var slot_str = EquipmentData.slot_name(ed.slot_type) if ed else "?"
			desc_lbl.text = "[Equipment] %s — %s (%s)" % [ed.name if ed else item["id"], slot_str, rarity_str]

	hbox.add_child(desc_lbl)

	# Right: buy button
	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(120, 0)
	if item["sold"]:
		buy_btn.text = "Sold"
		buy_btn.disabled = true
	else:
		var gold = ResourceManager.gold if ResourceManager else 0
		buy_btn.text = "Buy (%dg)" % item["price"]
		buy_btn.disabled = gold < item["price"]
		buy_btn.pressed.connect(_on_buy_pressed.bind(index))

	hbox.add_child(buy_btn)
	return hbox

# ── Purchase logic ────────────────────────────────────────────────────────────

func _on_buy_pressed(index: int):
	if index < 0 or index >= _stock.size():
		return
	var item: Dictionary = _stock[index]
	if item["sold"]:
		return
	var gold = ResourceManager.gold if ResourceManager else 0
	if gold < item["price"]:
		return

	# Deduct gold
	ResourceManager.set_gold(gold - item["price"])
	item["sold"] = true

	match item["type"]:
		"card":
			RunState.add_card_to_deck_from_reward(item["id"], "")
		"upgrade_bundle":
			if ResourceManager:
				ResourceManager.add_upgrade_points(item.get("pts", 5))
		"transcendence":
			# Grant 1 transcendence upgrade via pending rewards (handled by RewardsScreen).
			# Mark node completed first so returning to map works correctly.
			MapManager.mark_current_node_completed()
			var bundle = RewardBundle.new()
			bundle.upgrade_count = 1
			bundle.is_transcendence_upgrade = true
			RunState.set_pending_rewards(bundle)
			ScreenManager.go_to_rewards()
			return  # RewardsScreen navigates back to map
		"equipment":
			RunState.add_to_run_stash(item["id"])
			# Also add to persistent stash
			if SaveManager:
				SaveManager.add_to_persistent_stash(item["id"])

	# Quest event: gold spent
	if QuestManager:
		QuestManager.emit_game_event("GOLD_SPENT", {"amount": item["price"]})

	# Auto-save after purchase
	if AutoSaveManager:
		AutoSaveManager.force_save("shop_purchase")

	refresh_from_state()

func _on_leave_pressed():
	## Mark node completed and return to map.
	MapManager.mark_current_node_completed()
	ScreenManager.go_to_map()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _rarity_name(rarity: CardData.Rarity) -> String:
	match rarity:
		CardData.Rarity.COMMON:   return "Common"
		CardData.Rarity.UNCOMMON: return "Uncommon"
		CardData.Rarity.RARE:     return "Rare"
	return "Common"

func _equip_rarity_name(rarity: EquipmentData.Rarity) -> String:
	match rarity:
		EquipmentData.Rarity.COMMON:   return "Common"
		EquipmentData.Rarity.UNCOMMON: return "Uncommon"
		EquipmentData.Rarity.RARE:     return "Rare"
	return "Common"
