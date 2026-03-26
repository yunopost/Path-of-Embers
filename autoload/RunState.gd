extends Node

## Autoload singleton - Source of truth for game state
## Emits signals when values change for reactive UI updates

signal deck_changed
signal buffs_changed
signal hand_changed
signal draw_pile_changed
signal discard_pile_changed
signal equipment_changed

# Deck
var deck: Dictionary = {}  # instance_id -> DeckCardData (authoritative registry)
var deck_order: Array[String] = []  # Stable ordering for deck view / upgrades UI
# Note: draw_pile, hand, discard_pile are now managed by deck_model only

# Models (architecture rule 4.1, 8.1)
var deck_model: DeckModel = null

# Combat status effects
var haste_next_card: bool = false  # Next card played doesn't advance enemy timer

# Reward pool
var reward_card_pool: Array[CardData] = []  # Merged reward card pool from selected characters

# Rare pity system
var rare_pity_counter: int = -2  # Base chance starts at -2%, increases by +1 for each Common shown

# Pending rewards (set by EncounterScreen, consumed by RewardsScreen)
var pending_rewards: RewardBundle = null

# Buffs list
var buffs: Array = []  # Will contain buff/debuff data

# Settings
var tap_to_play: bool = false

# Equipment state (Phase 6)
## Per-character equipped items: { "char_id": { "SLOT_NAME": "equipment_id" } }
var equipment_slots: Dictionary = {}
## Items in the current run stash (max 9 equipment_ids)
var run_stash: Array[String] = []
const MAX_STASH_SIZE: int = 9

# Boss Rush state (Phase 8)
var is_boss_rush: bool = false          ## True while in a Boss Rush challenge
var boss_rush_boss_id: String = ""      ## Which boss is being challenged
## Combat stats accumulated during a Boss Rush fight for leaderboard scoring.
## Keys: start_time (float), enemy_total_hp (int), cards_played (int)
var boss_rush_stats: Dictionary = {}

func _ready():
	# Initialize with empty values (will be set by character selection)
	deck = {}
	deck_order = []
	haste_next_card = false
	reward_card_pool = []
	rare_pity_counter = -2
	buffs = []
	equipment_slots = {}
	run_stash = []
	
	# Initialize systems
	deck_model = DeckModel.new()

	# Connect model signals to RunState signals
	deck_model.deck_changed.connect(func(): deck_changed.emit())
	deck_model.draw_pile_changed.connect(func(): draw_pile_changed.emit())
	deck_model.hand_changed.connect(func(): hand_changed.emit())
	deck_model.discard_pile_changed.connect(func(): discard_pile_changed.emit())

func add_card_to_deck(card_id: String, owner_character_id: String = "", upgrades: Array[String] = [], transcended: bool = false, transcendent_card_id: String = ""):
	## Add a card to the deck with optional upgrades and owner
	## Creates DeckCardData with instance_id and stores in registry
	# Validate card_id is non-empty
	if card_id.is_empty():
		push_error("RunState.add_card_to_deck: card_id is empty. owner=%s" % owner_character_id)
		return
	
	# Validate CardData exists
	var card_data = DataRegistry.get_card_data(card_id)
	if not card_data:
		push_error("RunState.add_card_to_deck: CardData not found for card_id='%s'. owner=%s" % [card_id, owner_character_id])
		return
	
	var deck_card = DeckCardData.new(card_id, owner_character_id, upgrades, transcended, transcendent_card_id)
	
	# Validate the created card instance
	if not CardValidation.validate_and_log_creation(deck_card, "add_card_to_deck"):
		return
	
	var instance_id = deck_card.instance_id
	
	# Store in registry
	deck[instance_id] = deck_card
	deck_order.append(instance_id)
	
	# Update model
	deck_model.add_card_instance(instance_id)
	draw_pile_changed.emit()
	
	deck_changed.emit()

func remove_card_instance(instance_id: String) -> void:
	## Remove a card instance from the deck and all piles
	if not deck.has(instance_id):
		return
	
	# Remove from registry
	deck.erase(instance_id)
	deck_order.erase(instance_id)
	
	# Remove from model piles
	deck_model.remove_instance_from_piles(instance_id)
	# Signals are emitted by deck_model.remove_instance_from_piles()
	deck_changed.emit()

func transform_card_instance(instance_id: String, new_card_id: String) -> void:
	## Transform a card instance to a different card
	## Clears upgrades (MVP decision)
	if not deck.has(instance_id):
		return
	
	var card_instance = deck[instance_id]
	if not card_instance:
		return
	
	# Validate new_card_id exists
	if new_card_id.is_empty():
		push_error("transform_card_instance: new_card_id is empty. instance_id=%s" % instance_id)
		return
	
	var new_card_data = DataRegistry.get_card_data(new_card_id)
	if not new_card_data:
		push_error("transform_card_instance: CardData not found for new_card_id='%s'. instance_id=%s" % [new_card_id, instance_id])
		return
	
	# Transform the card
	card_instance.card_id = new_card_id
	card_instance.applied_upgrades.clear()  # MVP: clear upgrades on transform
	card_instance.is_transcended = false
	card_instance.transcendent_card_id = ""
	
	# Validate the transformed card
	if not CardValidation.validate_card_instance(card_instance, "transform_card_instance"):
		push_error("transform_card_instance: Transformed card is invalid. instance_id=%s" % instance_id)
	
	# Emit signals
	deck_changed.emit()
	# If card is in hand, emit hand_changed
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()

func get_deck_size() -> int:
	return deck_order.size()

func _initialize_deck_piles():
	## Initialize draw pile with all cards from deck, clear hand and discard
	deck_model.initialize(deck_order.duplicate())


func shuffle_discard_into_draw():
	## Shuffle discard pile into draw pile (when draw is empty)
	## Note: This is handled automatically by deck_model.draw_cards() when draw pile is empty
	deck_model.draw_pile = deck_model.discard_pile.duplicate()
	deck_model.discard_pile.clear()
	deck_model.shuffle_draw_pile()
	deck_model.discard_pile_changed.emit()

func draw_cards(count: int = 5):
	## Draw cards from draw pile into hand
	## If draw pile is empty, shuffle discard into draw first
	deck_model.draw_cards(count)
	# Signals are emitted by deck_model

func discard_hand():
	## Move all cards from hand to discard pile
	deck_model.discard_hand()
	# Signals are emitted by deck_model

func get_draw_pile_count() -> int:
	return deck_model.get_draw_pile_count()

func get_discard_pile_count() -> int:
	return deck_model.get_discard_pile_count()

func get_hand_size() -> int:
	return deck_model.get_hand_size()

func generate_starter_deck(character_data_list: Array[CharacterData]):
	## Generate starter deck from selected characters
	## character_data_list must be exactly 3 CharacterData resources
	if character_data_list.size() != 3:
		push_error("generate_starter_deck requires exactly 3 characters, got %d" % character_data_list.size())
		return
	
	deck.clear()
	deck_order.clear()
	reward_card_pool.clear()

	# Seed shared HP pool from sum of all party members' hp_base
	var party_max_hp: int = 0
	for char_data in character_data_list:
		party_max_hp += char_data.hp_base
	if ResourceManager:
		ResourceManager.reset_resources_for_party(party_max_hp)

	# Generate deck: 3 generic + 2 unique per character = 15 cards total
	for char_data in character_data_list:
		# Add 3 generic cards based on role
		var generic_card_ids = RoleStarterSet.get_generic_starters_for_role(char_data.role)
		for card_id in generic_card_ids:
			# Validate card_id exists before creating
			if card_id.is_empty():
				push_error("generate_starter_deck: Empty card_id for generic starter. character=%s" % char_data.id)
				continue
			var card_data = DataRegistry.get_card_data(card_id)
			if not card_data:
				push_error("generate_starter_deck: CardData not found for generic card_id='%s'. character=%s" % [card_id, char_data.id])
				continue
			
			var deck_card = DeckCardData.new(card_id, char_data.id)
			if not CardValidation.validate_and_log_creation(deck_card, "generate_starter_deck (generic)"):
				continue
			var instance_id = deck_card.instance_id
			deck[instance_id] = deck_card
			deck_order.append(instance_id)
		
		# Add 2 unique cards
		for unique_card in char_data.starter_unique_cards:
			if not unique_card or not unique_card.id:
				push_error("generate_starter_deck: Invalid unique_card. character=%s" % char_data.id)
				continue
			var card_id = unique_card.id
			if card_id.is_empty():
				push_error("generate_starter_deck: Empty card_id for unique card. character=%s" % char_data.id)
				continue
			
			var deck_card = DeckCardData.new(card_id, char_data.id)
			if not CardValidation.validate_and_log_creation(deck_card, "generate_starter_deck (unique)"):
				continue
			var instance_id = deck_card.instance_id
			deck[instance_id] = deck_card
			deck_order.append(instance_id)
		
		# Inject cards from equipped items (Phase 6)
		var char_equip_slots: Dictionary = equipment_slots.get(char_data.id, {})
		for slot_name in char_equip_slots:
			var equipment_id: String = char_equip_slots[slot_name]
			if equipment_id.is_empty():
				continue
			var equip_data = DataRegistry.get_equipment(equipment_id) if DataRegistry else null
			if equip_data:
				for card_id in equip_data.injected_cards:
					add_card_to_deck(card_id, char_data.id)

		# Merge reward card pool (22 cards per character = 66 total)
		for reward_card in char_data.reward_card_pool:
			if reward_card:
				reward_card_pool.append(reward_card)

	# Initialize deck piles
	_initialize_deck_piles()
	deck_changed.emit()
	
	# Initialize rare pity counter (starts at -2%)
	rare_pity_counter = -2

func rebuild_reward_pool_from_party():
	## Rebuild reward_card_pool from the current party's CharacterData.
	## Called after loading a save so the pool reflects the saved party's cards.
	reward_card_pool.clear()
	var party_ids = PartyManager.party_ids if PartyManager else []
	for char_id in party_ids:
		var char_data: CharacterData = DataRegistry.get_character(char_id) if DataRegistry else null
		if not char_data:
			push_warning("RunState.rebuild_reward_pool_from_party: no CharacterData for '%s'" % char_id)
			continue
		for reward_card in char_data.reward_card_pool:
			if reward_card:
				reward_card_pool.append(reward_card)

func set_pending_rewards(bundle: RewardBundle):
	## Set pending rewards (called by EncounterScreen)
	pending_rewards = bundle
	
	# Force save when pending rewards are set (so crash mid-rewards is recoverable)
	if AutoSaveManager:
		AutoSaveManager.force_save("pending_rewards_set")

func clear_pending_rewards():
	## Clear pending rewards (called by RewardsScreen after completion)
	pending_rewards = null

func apply_reward_bundle(bundle: RewardBundle):
	## Apply all rewards from a bundle to RunState
	## This is called by RewardsScreen after player makes choices
	## Uses ResourceManager for resource updates
	if not bundle:
		return
	
	# Apply gold (uses ResourceManager)
	if bundle.gold > 0 and ResourceManager:
		ResourceManager.set_gold(ResourceManager.gold + bundle.gold)
	
	# Apply healing (uses ResourceManager)
	if bundle.heal_amount > 0 and ResourceManager:
		var new_hp = min(ResourceManager.current_hp + bundle.heal_amount, ResourceManager.max_hp)
		ResourceManager.set_hp(new_hp, ResourceManager.max_hp)
	
	# Card rewards are handled separately by RewardsScreen (player chooses which card)
	# Relic and upgrade rewards are also handled separately by RewardsScreen
	
	# Note: We don't apply cards/relics/upgrades here because player must choose
	# RewardsScreen calls add_card_to_deck/add_relic/etc. individually

func add_card_to_deck_from_reward(card_id: String, owner_character_id: String = ""):
	## Add a card to deck from reward.
	## If owner_character_id is empty, the owner is derived from CardData.owner_character_id
	## so that stat scaling (STR/DEF/SPIRIT) works correctly for reward cards.
	var resolved_owner = owner_character_id
	if resolved_owner.is_empty():
		var card_data = DataRegistry.get_card_data(card_id) if DataRegistry else null
		if card_data and not card_data.owner_character_id.is_empty():
			resolved_owner = card_data.owner_character_id
	add_card_to_deck(card_id, resolved_owner)

func can_upgrade_instance(instance_id: String) -> bool:
	## Check if a card instance can be upgraded
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	
	# Check if card has available upgrades
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if pool.is_empty():
		return false
	
	# Check if there are any available upgrades (not already applied)
	var available = []
	for upgrade_id in pool:
		if not card_instance.applied_upgrades.has(upgrade_id):
			available.append(upgrade_id)
	
	return not available.is_empty()

func apply_upgrade_to_instance(instance_id: String, upgrade_id: String) -> bool:
	## Apply an upgrade to a card instance by instance_id
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	
	# Check if upgrade is already applied (no duplicates)
	if card_instance.applied_upgrades.has(upgrade_id):
		return false
	
	# Check if upgrade is valid for this card
	var pool = DataRegistry.get_upgrade_pool_for_card(card_instance.card_id)
	if not pool.has(upgrade_id):
		return false
	
	# Apply upgrade (directly mutates the object in deck registry)
	card_instance.applied_upgrades.append(upgrade_id)
	
	# Emit signals (no need to sync piles - they reference the same object via instance_id lookup)
	deck_changed.emit()
	# If card is in hand, emit hand_changed
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()
	
	# Quest event: card upgraded
	if QuestManager:
		QuestManager.emit_game_event("CARD_UPGRADED", {})

	# Autosave after upgrade
	if AutoSaveManager:
		AutoSaveManager.force_save("card_upgraded")

	return true

func get_upgradeable_instance_ids() -> Array[String]:
	## Get all instance_ids of cards that can be upgraded
	var instance_ids: Array[String] = []
	for instance_id in deck_order:
		if can_upgrade_instance(instance_id):
			instance_ids.append(instance_id)
	return instance_ids

func get_effective_cost(instance_id: String) -> int:
	## Get the effective cost of a card after upgrades (delegates to CardRules)
	## Returns the base cost minus cost reduction upgrades (min 0)
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return 1  # Default fallback
	
	var card_data = DataRegistry.get_card_data(card_instance.card_id)
	if not card_data:
		return 1  # Default fallback
	
	return CardRules.get_effective_cost(card_data, card_instance)

func has_upgrade(instance_id: String, upgrade_id: String) -> bool:
	## Check if a card instance has a specific upgrade
	var card_instance = deck.get(instance_id)
	if not card_instance:
		return false
	return card_instance.applied_upgrades.has(upgrade_id)

func get_timer_tick_amount_for_card(instance_id: String) -> int:
	## Get the timer tick amount for a card
	## Returns 0 if has Haste or haste_next_card status, 2 if has Slow keyword, 1 otherwise
	
	# Check for haste_next_card status (from Shoulder Tackle or similar effects)
	# This applies to the CURRENT card being played (which was granted haste by the previous card)
	if haste_next_card:
		# Clear the status after using it (it only applies once)
		haste_next_card = false
		return 0
	
	# Check for Haste upgrade
	if has_upgrade(instance_id, "upgrade_haste"):
		return 0
	
	# Check for Slow keyword on card (using CardRules to account for upgrades that remove keywords)
	var card_instance = deck.get(instance_id)
	if card_instance:
		var keywords = CardRules.get_card_keywords(card_instance)
		if keywords.has("Slow"):
			return 2
	
	return 1

func transcend_card(instance_id: String, new_card_id: String) -> bool:
	## Transform a card instance into a transcendent card
	## Replaces the card_id and marks as transcended
	if instance_id.is_empty() or new_card_id.is_empty():
		push_error("transcend_card: instance_id or new_card_id is empty")
		return false
	
	var card_instance = deck.get(instance_id)
	if not card_instance:
		push_error("transcend_card: Card instance not found. instance_id=%s" % instance_id)
		return false
	
	# Validate new_card_id exists
	var new_card_data = DataRegistry.get_card_data(new_card_id)
	if not new_card_data:
		push_error("transcend_card: CardData not found for new_card_id='%s'. instance_id=%s" % [new_card_id, instance_id])
		return false
	
	# Update card instance
	card_instance.card_id = new_card_id
	card_instance.is_transcended = true
	card_instance.transcendent_card_id = new_card_id
	
	# Validate the transcended card
	if not CardValidation.validate_card_instance(card_instance, "transcend_card"):
		push_error("transcend_card: Transcended card is invalid. instance_id=%s" % instance_id)
		return false
	
	# Emit signals (instance_id remains the same, so piles don't need updating)
	deck_changed.emit()
	if deck_model and deck_model.hand.has(instance_id):
		deck_model.hand_changed.emit()
	
	# Autosave after transcendence
	if AutoSaveManager:
		AutoSaveManager.force_save("card_transcended")
	
	return true

func get_rare_chance(node_type: MapNodeData.NodeType) -> float:
	## Calculate current Rare chance including Elite bonus
	## Deck penalty is applied per-card during selection, not to overall Rare chance
	var base_chance = rare_pity_counter / 100.0  # Convert counter to percentage
	
	# Apply Elite bonus (+10% for Elite nodes)
	var elite_bonus = 0.0
	if node_type == MapNodeData.NodeType.ELITE:
		elite_bonus = 0.10
	
	var final_chance = base_chance + elite_bonus
	return clamp(final_chance, 0.0, 1.0)  # Clamp between 0% and 100%

func get_rare_cards_in_deck() -> Array[String]:
	## Get array of card_ids for Rare cards currently in deck
	var rare_card_ids: Array[String] = []
	for instance_id in deck_order:
		var card_instance = deck.get(instance_id)
		if card_instance:
			var card_data = DataRegistry.get_card_data(card_instance.card_id)
			if card_data and card_data.rarity == CardData.Rarity.RARE:
				if not rare_card_ids.has(card_instance.card_id):
					rare_card_ids.append(card_instance.card_id)
	return rare_card_ids

func update_rare_pity_from_rewards(card_choices: Array[String]) -> void:
	## Update pity counter based on cards shown in rewards
	## Each Common increases counter by +1, Rare resets to -2
	var had_rare = false
	var common_count = 0
	
	for card_id in card_choices:
		var card_data = DataRegistry.get_card_data(card_id)
		if card_data:
			if card_data.rarity == CardData.Rarity.RARE:
				had_rare = true
			elif card_data.rarity == CardData.Rarity.COMMON:
				common_count += 1
	
	if had_rare:
		# Reset to -2 when Rare appears
		rare_pity_counter = -2
	else:
		# Increase by 1 for each Common shown
		rare_pity_counter += common_count

func reset_rare_pity() -> void:
	## Reset pity counter to -2
	rare_pity_counter = -2

func reset_run() -> void:
	## Reset all run state to initial values (for New Game)
	## Clears deck, relics, buffs, and delegates to managers for their state
	
	# Clear party (delegates to PartyManager)
	if PartyManager:
		PartyManager.clear_party()
	
	# Clear deck
	deck.clear()
	deck_order.clear()
	if deck_model:
		deck_model.draw_pile.clear()
		deck_model.hand.clear()
		deck_model.discard_pile.clear()
	deck_changed.emit()
	draw_pile_changed.emit()
	hand_changed.emit()
	discard_pile_changed.emit()
	
	# Clear quests (delegates to QuestManager)
	if QuestManager:
		QuestManager.clear_quests()

	# Reset resources (delegates to ResourceManager)
	if ResourceManager:
		ResourceManager.reset_resources()
	
	haste_next_card = false
	
	# Reset map/progress (delegates to MapManager)
	if MapManager:
		MapManager.reset_map_state()
	
	# Clear pending rewards
	pending_rewards = null
	
	# Clear reward pool
	reward_card_pool.clear()
	
	# Reset rare pity counter
	rare_pity_counter = -2
	
	# Clear buffs
	buffs.clear()
	buffs_changed.emit()
	
	# Reset settings
	tap_to_play = false

	# Reset equipment state
	equipment_slots.clear()
	run_stash.clear()
	equipment_changed.emit()

	# Reset boss rush state
	is_boss_rush = false
	boss_rush_boss_id = ""
	boss_rush_stats = {}

	# Clear active difficulty modifiers
	if ModifierManager:
		ModifierManager.end_run()

# ── Boss Rush helpers (Phase 8) ───────────────────────────────────────────────

func load_from_build_data(build: BuildData) -> void:
	## Populate RunState from a BuildData snapshot for a Boss Rush challenge.
	## Clears existing run state first (does not affect meta save).
	reset_run()

	is_boss_rush = true

	# Restore party
	if PartyManager:
		PartyManager.set_party(build.party_ids)

	# Restore deck
	for entry in build.deck:
		if entry is Dictionary:
			var upgrades: Array[String] = []
			for u in entry.get("upgrades", []):
				upgrades.append(str(u))
			add_card_to_deck(
				str(entry.get("id", "")),
				str(entry.get("owner", "")),
				upgrades
			)

	# Restore equipment
	equipment_slots = {}
	for char_id in build.equipment_slots:
		equipment_slots[str(char_id)] = {}
		for slot_name in build.equipment_slots[char_id]:
			equipment_slots[str(char_id)][str(slot_name)] = str(build.equipment_slots[char_id][slot_name])
	run_stash = build.run_stash.duplicate()
	equipment_changed.emit()

# ── Equipment helpers (Phase 6) ───────────────────────────────────────────────

func get_equipped_item(char_id: String, slot_name: String) -> String:
	## Get the equipment_id in the given slot for a character, or "" if empty.
	return equipment_slots.get(char_id, {}).get(slot_name, "")

func equip_item(char_id: String, slot_name: String, equipment_id: String) -> bool:
	## Equip an item into a character slot.
	## If the slot is already occupied the old item is returned to the run stash.
	## Returns false if the item is not in the run stash.
	if not run_stash.has(equipment_id):
		push_warning("RunState.equip_item: '%s' is not in run stash" % equipment_id)
		return false
	if not equipment_slots.has(char_id):
		equipment_slots[char_id] = {}
	var old_id: String = equipment_slots[char_id].get(slot_name, "")
	if not old_id.is_empty():
		run_stash.append(old_id)  # Return displaced item to stash
	equipment_slots[char_id][slot_name] = equipment_id
	run_stash.erase(equipment_id)
	equipment_changed.emit()
	return true

func unequip_item(char_id: String, slot_name: String) -> void:
	## Remove the item from a character slot and return it to the run stash.
	if not equipment_slots.has(char_id):
		return
	var equipment_id: String = equipment_slots[char_id].get(slot_name, "")
	if equipment_id.is_empty():
		return
	equipment_slots[char_id].erase(slot_name)
	add_to_run_stash(equipment_id)

func add_to_run_stash(equipment_id: String) -> bool:
	## Add an equipment_id to the run stash (max 9).
	## Returns false if the stash is full.
	if equipment_id.is_empty():
		return false
	if run_stash.size() >= MAX_STASH_SIZE:
		push_warning("RunState: Run stash is full (%d/%d), cannot add '%s'" % [run_stash.size(), MAX_STASH_SIZE, equipment_id])
		return false
	run_stash.append(equipment_id)
	equipment_changed.emit()
	return true

func remove_from_run_stash(equipment_id: String) -> void:
	## Remove an equipment_id from the run stash (e.g. after equipping it).
	run_stash.erase(equipment_id)
	equipment_changed.emit()
