# Arrow
# Game Narrative Design Tool
# Mor. H. Golkar

# Condition Node Type Console
extends PanelContainer

signal play_forward
signal status_code
# warning-ignore:unused_signal
signal clear_up
# warning-ignore:unused_signal
signal reset_variable

onready var Main = get_tree().get_root().get_child(0)

const AUTO_PLAY_SLOT = -1

const FALSE_SLOT = 0
const TRUE_SLOT  = 1
# Note:
# `True` is the 3rd slot (seemingly index `2`) but ...
# its real index is  `1` due to the 2nd slot being right-disabled and not counted

var _NODE_ID:int
var _NODE_RESOURCE:Dictionary
var _NODE_MAP:Dictionary
var _NODE_SLOTS_MAP:Dictionary
var _VARIABLES_CURRENT:Dictionary

var This = self
var _PLAY_IS_SET_UP:bool = false
var _NODE_IS_READY:bool = false
var _DEFERRED_VIEW_PLAY_SLOT:int = -1
var _AUTOMATIC_EVALUATE_AND_PLAY:bool = true

const UNSET_OR_INVALID_MESSAGE = "Unset !"
onready var ConditionStatement = ConditionSharedClass.Statement.new(Main.Mind)

onready var Statement = get_node("./ConditionPlay/Statement")
onready var TheFalse = get_node("./ConditionPlay/False")
onready var TheTrue = get_node("./ConditionPlay/True")

func _ready() -> void:
	register_connections()
	_NODE_IS_READY = true
	if _PLAY_IS_SET_UP:
		setup_view()
	if _DEFERRED_VIEW_PLAY_SLOT >= 0:
		set_view_played(_DEFERRED_VIEW_PLAY_SLOT)
	if _AUTOMATIC_EVALUATE_AND_PLAY:
		automatic_evaluation_and_play_on_ready()
	pass

func register_connections() -> void:
	TheTrue.connect("pressed", self, "play_forward_from", [TRUE_SLOT], CONNECT_DEFERRED)
	TheFalse.connect("pressed", self, "play_forward_from", [FALSE_SLOT], CONNECT_DEFERRED)
	pass
	
func remap_connections_for_slots(map:Dictionary = _NODE_MAP, this_node_id:int = _NODE_ID) -> void:
	if map.has("io") && map.io is Array:
		for connection in map.io:
			# <connection>[ from_id, from_slot, to_id, to_slot ]
			if connection.size() >= 4 && connection[0] == this_node_id:
				_NODE_SLOTS_MAP[ connection[1] ] = { "id": connection[2], "slot": connection[3] }
	pass

func setup_view() -> void:
	var unset = true
	if _NODE_RESOURCE.has("data"):
		# save a lookup if we have the data already cached
		var the_variable = null
		if _NODE_RESOURCE.data.has("variable") && (_NODE_RESOURCE.data.variable is int) :
			if _NODE_RESOURCE.data.variable >= 0 && _VARIABLES_CURRENT.has(_NODE_RESOURCE.data.variable):
				the_variable = _VARIABLES_CURRENT[_NODE_RESOURCE.data.variable]
		# then parse the statement
		var statement_text = ConditionStatement.parse(_NODE_RESOURCE.data, the_variable)
		if statement_text is String:
			Statement.set_deferred("text", statement_text)
			unset = false
	if unset:
		Statement.set_deferred("text", UNSET_OR_INVALID_MESSAGE)
	pass
	
func setup_play(node_id:int, node_resource:Dictionary, node_map:Dictionary, _playing_in_slot:int = -1, variables_current:Dictionary={}) -> void:
	_NODE_ID = node_id
	_NODE_RESOURCE = node_resource
	_NODE_MAP = node_map
	_VARIABLES_CURRENT = variables_current
	remap_connections_for_slots()
	# update fields and children
	if _NODE_IS_READY:
		setup_view()
	_PLAY_IS_SET_UP = true
	# handle skip in case
	if _NODE_MAP.has("skip") && _NODE_MAP.skip == true:
		skip_play()
	# otherwise auto-play if set
	else: # otherwise ...
		automatic_evaluation_and_play_on_ready()
	pass

func automatic_evaluation_and_play_on_ready() -> void:
	if _NODE_IS_READY:
		play_forward_from(
			TRUE_SLOT if (evaluate_condition() == true) else FALSE_SLOT
		)
		_AUTOMATIC_EVALUATE_AND_PLAY = false
	else:
		_AUTOMATIC_EVALUATE_AND_PLAY = true
	pass

func evaluate_condition() -> bool:
	var result = ConditionStatement.evaluate(_NODE_RESOURCE.data, _VARIABLES_CURRENT)
	if result is bool:
		return result
	else:
		printerr("Evaluation of Condition Failed, therefore considered as `False`.")
		return false

func play_forward_from(slot_idx:int = AUTO_PLAY_SLOT) -> void:
	if slot_idx >= 0:
		if _NODE_SLOTS_MAP.has(slot_idx):
			var next = _NODE_SLOTS_MAP[slot_idx]
			self.emit_signal("play_forward", next.id, next.slot)
		else:
			emit_signal("status_code", CONSOLE_STATUS_CODE.END_EDGE)
		set_view_played_on_ready(slot_idx)
	pass

func set_view_played_on_ready(slot_idx:int) -> void:
	if _NODE_IS_READY:
		set_view_played(slot_idx)
	else:
		_DEFERRED_VIEW_PLAY_SLOT = slot_idx
	pass

func set_view_unplayed() -> void:
	# in case unplayed (i.e. step-back after automatic evaluation)
	# ... let user choose
	TheFalse.set_deferred("visible", true)
	TheFalse.set_deferred("disabled", false)
	TheTrue.set_deferred("visible", true)
	TheTrue.set_deferred("disabled", false)
	pass

func set_view_played(slot_idx:int = AUTO_PLAY_SLOT) -> void:
	TheFalse.set_deferred("visible", (slot_idx == FALSE_SLOT))
	TheFalse.set_deferred("disabled", true)
	TheTrue.set_deferred("visible", (slot_idx == TRUE_SLOT))
	TheTrue.set_deferred("disabled", true)
	pass

func skip_play() -> void:
	# skipped? the convention is to ...
	# react by playing the *False Slot First*
	if _NODE_SLOTS_MAP.has(FALSE_SLOT): # if false slot is connected
		play_forward_from(FALSE_SLOT)
	else: # otherwise playing the *Only Remained [Possibly Connected] True Slot*
		play_forward_from(TRUE_SLOT) # which ...
		# ... will naturally end the plot line if the true slot is not connected
	pass

func step_back() -> void:
	set_view_unplayed()
	pass
	
