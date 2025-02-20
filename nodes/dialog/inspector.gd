# Arrow
# Game Narrative Design Tool
# Mor. H. Golkar

# Dialog Node Type Inspector
extends ScrollContainer

onready var Main = get_tree().get_root().get_child(0)

var ListHelpers = Helpers.ListHelpers

const ANONYMOUS_CHARACTER = DialogSharedClass.ANONYMOUS_CHARACTER
const DEFAULT_NODE_DATA = DialogSharedClass.DEFAULT_NODE_DATA

const SAVE_UNOPTIMIZED = DialogSharedClass.SAVE_UNOPTIMIZED

const ALLOW_ANONYMOUS_DIALOGS = true
const ANONYMOUS_UID_CONTROL_VALUE = (-254)

var _OPEN_NODE_ID
var _OPEN_NODE

var _PROJECT_CHARACTERS_CACHE = {}

const RESOURCE_NAME_EXPOSURE = Settings.RESOURCE_NAME_EXPOSURE

var This = self

onready var Character = get_node("./Dialog/Character/Selection")
onready var Line = get_node("./Dialog/Line/Edit")
onready var Tools = get_node("./Dialog/Line/Tools")
onready var ToolsPopup = Tools.get_popup()
onready var LinesList = get_node("./Dialog/Lines/List")
onready var Playable = get_node("./Dialog/Playable")

const TOOLS_MENU_BUTTON_POPUP = { # <id>:int { label:string, action:string<function-ident-to-be-called> }
	0: { "label": "Append New Line", "action": "append_new_line" },
	1: null, # separator
	2: { "label": "Extract Selected Line", "action": "extract_selected_line" },
	3: { "label": "Replace Selected Line", "action": "replace_selected_line" },
	4: { "label": "Remove Selected Line(s)", "action": "remove_selected_lines" },
	5: null,
	6: { "label": "Sort Lines (Alphabetical)", "action": "sort_items_alphabetical" },
	7: { "label": "Move Selected Top", "action": "move_selected_top" },
}
var _TOOLS_ITEM_INDEX_BY_ACTION = {}

func _ready() -> void:
	load_tools_menu()
	register_connections()
	pass

func register_connections() -> void:
	ToolsPopup.connect("id_pressed", self, "_on_tools_popup_menu_id_pressed", [], CONNECT_DEFERRED)
	Line.connect("text_changed", self, "_toggle_available_tools_smartly", [], CONNECT_DEFERRED)
	Line.connect("text_entered", self, "append_new_line", [], CONNECT_DEFERRED)
	LinesList.connect("multi_selected", self, "_toggle_available_tools_smartly", [], CONNECT_DEFERRED)
	LinesList.connect("item_rmb_selected", self, "_on_right_click_item_selection", [], CONNECT_DEFERRED)
	pass
	
func load_tools_menu() -> void:
	ToolsPopup.clear()
	for item_id in TOOLS_MENU_BUTTON_POPUP:
		var item = TOOLS_MENU_BUTTON_POPUP[item_id]
		if item == null: # separator
			ToolsPopup.add_separator()
		else:
			ToolsPopup.add_item(item.label, item_id)
			_TOOLS_ITEM_INDEX_BY_ACTION[item.action] = ToolsPopup.get_item_index(item_id)
	self.call_deferred("_toggle_available_tools_smartly")
	pass

func _on_tools_popup_menu_id_pressed(pressed_item_id:int) -> void:
	var the_action = TOOLS_MENU_BUTTON_POPUP[pressed_item_id].action
	if the_action is String && the_action.length() > 0 :
		self.call_deferred(the_action)
	pass

# Note: it needs `x,y,z` nulls, because it's connected to different signals with different number of passed arguments
func _toggle_available_tools_smartly(x=null, y=null, z=null) -> void:
	var new_string_is_blank = ( Line.get_text().length() == 0 )
	var selection_size = LinesList.get_selected_items().size()
	var all_items_count = LinesList.get_item_count()
	ToolsPopup.set_item_disabled( _TOOLS_ITEM_INDEX_BY_ACTION["append_new_line"], new_string_is_blank )
	ToolsPopup.set_item_disabled( _TOOLS_ITEM_INDEX_BY_ACTION["extract_selected_line"], (selection_size != 1 || all_items_count == 1 ) )
	ToolsPopup.set_item_disabled( _TOOLS_ITEM_INDEX_BY_ACTION["replace_selected_line"], (selection_size != 1 || new_string_is_blank) )
	ToolsPopup.set_item_disabled( _TOOLS_ITEM_INDEX_BY_ACTION["remove_selected_lines"], ( selection_size == 0 || selection_size >= all_items_count || all_items_count == 1 ) )
	pass

func move_item(to_final_idx:int = 0, from:int = -1) -> void:
	var current_list_size = LinesList.get_item_count()
	if current_list_size > 1 :
		if to_final_idx < current_list_size && from < current_list_size:
			if from < 0 : # if no item is selected to be moved
				from = (current_list_size - 1) # move the last one by default
			LinesList.move_item(from, to_final_idx)
	pass

func move_selected_top(selected_lines_idxs:Array = []) -> void:
	if LinesList.get_item_count() > 1 :
		if selected_lines_idxs.size() == 0:
			selected_lines_idxs = LinesList.get_selected_items()
		if selected_lines_idxs.size() >= 1:
			# we shall move from the first element in order, so they keep staying in order
			selected_lines_idxs.sort()
			while selected_lines_idxs.size() > 0 :
				var the_first_item = selected_lines_idxs.pop_front()
				move_item(0, the_first_item)
	pass

func sort_items_alphabetical() -> void:
	LinesList.sort_items_by_text()
	pass

func append_new_line(text:String = "") -> void:
	var new_line = ( text if text.length() > 0 else Line.get("text") )
	LinesList.add_item( new_line )
	Line.clear()
	# select the last/newly created item
	LinesList.select(( LinesList.get_item_count() - 1) , true) 
	# and make sure it's visible
	LinesList.ensure_current_is_visible()
	pass

func extract_selected_line(selected_lines_idxs:Array = []) -> void:
	if selected_lines_idxs.size() == 0:
		selected_lines_idxs = LinesList.get_selected_items()
	if selected_lines_idxs.size() >= 1:
		var item_idx_to_extract = selected_lines_idxs[0]
		var item_text = LinesList.get_item_text(item_idx_to_extract)
		Line.set_text(item_text)
		LinesList.remove_item(item_idx_to_extract)
	# refresh tools manually, because set_text won't fire input event
	_toggle_available_tools_smartly()
	pass
	
func replace_selected_line(selected_lines_idxs:Array = []) -> void:
	if selected_lines_idxs.size() == 0:
		selected_lines_idxs = LinesList.get_selected_items()
	if selected_lines_idxs.size() >= 1:
		var to_idx_for_replacement = selected_lines_idxs[0]
		remove_selected_lines(selected_lines_idxs)
		var new_line = Line.get("text")
		LinesList.add_item( new_line )
		Line.clear()
		move_item(to_idx_for_replacement) # by default moves the last item
	pass

func remove_selected_lines(selected_lines_idxs:Array = []) -> void:
	if selected_lines_idxs.size() == 0:
		selected_lines_idxs = LinesList.get_selected_items()
	# we shall remove items from the last one because 
	# removal of a preceding item will change indices for others and you may remove innocent items!
	if selected_lines_idxs.size() >= 1:
		selected_lines_idxs.sort()
		while selected_lines_idxs.size() > 0 :
			var the_last_item = selected_lines_idxs.pop_back()
			LinesList.remove_item(the_last_item)
	pass

func _on_right_click_item_selection(item_idx:int, _click_position:Vector2) -> void:
	var all_items_count = LinesList.get_item_count()
	if all_items_count > 1 :
		extract_selected_line([item_idx])
	pass

func a_node_is_open() -> bool :
	if (
		(_OPEN_NODE_ID is int) && (_OPEN_NODE_ID >= 0) &&
		(_OPEN_NODE is Dictionary) &&
		_OPEN_NODE.has("data") && (_OPEN_NODE.data is Dictionary)
	):
		return true
	else:
		return false

func refresh_character_list(select_by_res_id:int = -1) -> void:
	Character.clear()
	if ALLOW_ANONYMOUS_DIALOGS == true:
		# (Our conventional `-1` conflicts with the default behavior of `add_item` method, so we use a `..._CONTROLL_VALUE`)
		Character.add_item(ANONYMOUS_CHARACTER.name, ANONYMOUS_UID_CONTROL_VALUE)
	_PROJECT_CHARACTERS_CACHE = Main.Mind.clone_dataset_of("characters")
	for character_id in _PROJECT_CHARACTERS_CACHE:
		var the_character = _PROJECT_CHARACTERS_CACHE[character_id]
		Character.add_item(the_character.name, character_id)
	if select_by_res_id >= 0 :
		var character_item_index = Character.get_item_index( select_by_res_id )
		Character.select(character_item_index )
	else:
		if a_node_is_open() && _OPEN_NODE.data.has("character") && ( _OPEN_NODE.data.character in _PROJECT_CHARACTERS_CACHE ):
			var character_item_index_from_id = Character.get_item_index( _OPEN_NODE.data.character )
			Character.select( character_item_index_from_id )
	pass

func update_lines_list(lines:Array = [], clear:bool = false) -> void:
	if clear:
		LinesList.clear()
	for line in lines:
		if line is String && line.length() > 0 :
			LinesList.add_item(line)
	pass

func _update_parameters(node_id:int, node:Dictionary) -> void:
	# first cache the node
	_OPEN_NODE_ID = node_id
	_OPEN_NODE = node
	refresh_character_list()
	Line.clear()
	if node.has("data") && node.data is Dictionary:
		if node.data.has("lines") && node.data.lines is Array:
			update_lines_list(node.data.lines, true)
		else:
			update_lines_list(DEFAULT_NODE_DATA.lines, true)
		if node.data.has("playable") && node.data.playable is bool:
			Playable.set_deferred("pressed", node.data.playable)
		else:
			Playable.set_deferred("pressed", DEFAULT_NODE_DATA.playable)
	pass

func find_exposed_resources(lines:Array, return_ids:bool = true) -> Array:
	var exposed_resources = []
	for resource_set in RESOURCE_NAME_EXPOSURE:
		var _CACHE = Main.Mind.clone_dataset_of(resource_set)
		var _CACHE_NAME_TO_ID = {}
		if _CACHE.size() > 0 : 
			for resource_id in _CACHE:
				_CACHE_NAME_TO_ID[ _CACHE[resource_id].name ] = resource_id
		# ...
		var _NAME_GROUP_ID = RESOURCE_NAME_EXPOSURE[resource_set].NAME_GROUP_ID
		var _EXPOSURE_PATTERN = RegEx.new()
		_EXPOSURE_PATTERN.compile( RESOURCE_NAME_EXPOSURE[resource_set].PATTERN )
		# ...
		for line in lines:
			if line is String:
				for regex_match in _EXPOSURE_PATTERN.search_all( line ):
					var possible_exposure = regex_match.get_string(_NAME_GROUP_ID)
					# print_debug("Possible Resource Exposure: ", possible_exposure)
					if _CACHE_NAME_TO_ID.has( possible_exposure ):
						var exposed = _CACHE_NAME_TO_ID[possible_exposure] if return_ids else possible_exposure
						if exposed_resources.has(exposed) == false:
							exposed_resources.append(exposed)
	return exposed_resources

func create_use_command(parameters:Dictionary) -> Dictionary:
	var use = { "drop": [], "refer": [] }
	# reference for any character as the dialog's owner?
	if parameters.character != _OPEN_NODE.data.character: # if new != already used
		if parameters.character >= 0:
			use.refer.append(parameters.character)
		if _OPEN_NODE.data.character >= 0:
			use.drop.append(_OPEN_NODE.data.character)
	# or any resource parsed ?
	var exposed_resources_by_uid = find_exposed_resources(parameters.lines, true)
	# ... remove the reference if any resource is not exposed anymore
	if _OPEN_NODE.has("ref") && _OPEN_NODE.ref is Array:
		for currently_referred_resource in _OPEN_NODE.ref:
			if (
				exposed_resources_by_uid.has( currently_referred_resource ) == false &&
				currently_referred_resource != parameters.character &&
				currently_referred_resource != _OPEN_NODE.data.character
			):
				use.drop.append( currently_referred_resource )
	# ... and add new ones
	if exposed_resources_by_uid.size() > 0 :
		var may_exist = (_OPEN_NODE.has("ref") && _OPEN_NODE.ref is Array)
		for newly_exposed in exposed_resources_by_uid:
			if may_exist == false || _OPEN_NODE.ref.has( newly_exposed ) == false:
				use.refer.append( newly_exposed )
	return use

func _read_parameters() -> Dictionary:
	var parameters = {
		"character": Character.get_selected_id(),
		"lines": ListHelpers.get_item_list_as_text_array(LinesList),
	}
	# Optionals (to avoid bloat:)
	# > playable (otherwise randomly auto-played)
	var playable = Playable.is_pressed()
	parameters["playable"] = playable if SAVE_UNOPTIMIZED || playable != DEFAULT_NODE_DATA.playable else null
	# ...
	# NOTE:
	# To avoid conflict with `add_item` default `-1` behavior, we used ANONYMOUS_UID_CONTROL_VALUE instead.
	# Here we adjust it to our conventional `-1` for unset/anonymous:
	if parameters.character == ANONYMOUS_UID_CONTROL_VALUE:
		parameters.character = -1
	# We should also handle dependencies if it relies on any other resource:
	var _use = create_use_command(parameters)
	if _use.drop.size() > 0 || _use.refer.size() > 0 :
		parameters._use = _use
	return parameters

func _create_new(new_node_id:int = -1) -> Dictionary:
	var data = DEFAULT_NODE_DATA.duplicate(true)
	return data

func _translate_internal_ref(data: Dictionary, translation: Dictionary) -> void:
	if translation.ids.has(data.character):
		data.character = translation.ids[data.character]
	for resource_set in RESOURCE_NAME_EXPOSURE:
		var _NAME_GROUP_ID = RESOURCE_NAME_EXPOSURE[resource_set].NAME_GROUP_ID
		var _EXPOSURE_PATTERN = RegEx.new()
		_EXPOSURE_PATTERN.compile( RESOURCE_NAME_EXPOSURE[resource_set].PATTERN )
		for idx in range(0, data.lines.size()):
			var revised = {}
			for matched in _EXPOSURE_PATTERN.search_all( data.lines[idx] ):
				var exposure = [matched.get_string(), matched.get_start(), matched.get_end()] 
				var exposed = [matched.get_string(_NAME_GROUP_ID), matched.get_start(_NAME_GROUP_ID), matched.get_end(_NAME_GROUP_ID)]
				if translation.names.has( exposed[0] ):
					var cut = [exposed[1] - exposure[1], exposed[2] - exposure[1]]
					var new_name = translation.names[exposed[0]]
					revised[exposure[0]] = (exposure[0].substr(0, cut[0]) + new_name + exposure[0].substr(cut[1], -1))
			for exposure in revised:
				data.lines[idx] = data.lines[idx].replace(exposure, revised[exposure])
	pass
