extends Node

## Autoload singleton - Handles automatic saving with debouncing and force-save on critical events
## Prevents save storms while ensuring important state is saved

var debounce_seconds := 0.75

var _dirty := false
var _save_queued := false
var _is_saving := false
var _last_reason := ""
var _timer: Timer

func _ready():
	# Create and configure one-shot Timer for debouncing
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = debounce_seconds
	_timer.timeout.connect(_on_debounce_timeout)
	add_child(_timer)
	
	# Connect RunState signals for debounced saves (deck/relics/buffs only)
	if RunState:
		RunState.deck_changed.connect(func(): request_save("deck_changed"))
		RunState.equipment_changed.connect(func(): request_save("equipment_changed"))
		RunState.buffs_changed.connect(func(): request_save("buffs_changed"))
		# Optional: pile changes (can be noisy but fine with debounce)
		RunState.hand_changed.connect(func(): request_save("piles_changed"))
		RunState.draw_pile_changed.connect(func(): request_save("piles_changed"))
		RunState.discard_pile_changed.connect(func(): request_save("piles_changed"))
	
	# Connect ResourceManager signals
	if ResourceManager:
		ResourceManager.gold_changed.connect(func(): request_save("gold_changed"))
		ResourceManager.hp_changed.connect(func(): request_save("hp_changed"))
		ResourceManager.block_changed.connect(func(): request_save("block_changed"))
		ResourceManager.energy_changed.connect(func(): request_save("energy_changed"))
	
	# Connect QuestManager signals
	if QuestManager:
		QuestManager.quests_changed.connect(func(): request_save("quests_changed"))
	
	# Connect MapManager signals
	if MapManager:
		MapManager.map_changed.connect(func(): request_save("map_changed"))
		MapManager.node_position_changed.connect(func(): request_save("node_position_changed"))
	
	# Connect ScreenManager for force-save on screen transitions
	if ScreenManager:
		ScreenManager.screen_changed.connect(_on_scene_changed)

func request_save(reason: String):
	## Mark dirty and (re)start debounce timer
	_dirty = true
	_last_reason = reason
	
	# Stop existing timer and restart
	if _timer:
		_timer.stop()
		_timer.start()

func _on_debounce_timeout():
	## Called when debounce timer expires - save if dirty
	if _dirty:
		_do_save("debounced:" + _last_reason)

func force_save(reason: String):
	## Force immediate save (bypasses debounce)
	# Stop timer to prevent debounced save from firing
	if _timer:
		_timer.stop()
	
	_dirty = true
	_do_save("force:" + reason)

func _do_save(reason: String):
	## Internal save implementation with guardrails
	# Guard: prevent overlapping saves
	if _is_saving:
		# Already saving, mark dirty for next attempt
		_dirty = true
		return
	
	# Guard: optional check for invalid/empty state (don't skip, just allow it)
	# Saving during empty state is okay (e.g., after reset_run)
	
	_is_saving = true
	
	# Call SaveManager.save_game()
	var success = false
	if SaveManager:
		success = SaveManager.save_game()
	
	_is_saving = false
	
	if success:
		# Clear dirty flag on success
		_dirty = false
		print("AutoSave: saved (" + reason + ")")
	else:
		# Keep dirty true on failure, will retry on next request
		_dirty = true
		push_warning("AutoSave: save failed (" + reason + ")")

func _on_scene_changed(scene_name: String):
	## Force save on every scene transition
	force_save("scene_changed:" + scene_name)
