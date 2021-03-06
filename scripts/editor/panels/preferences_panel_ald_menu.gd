# Arrow
# Game Narrative Design Tool
# Mor. H. Golkar

# Preferences Panel :: App Local / Work Directory (Reset) Menu-button 
extends MenuButton

signal item_selected_value

onready var popup = self.get_popup()

var _MENU_ITEMS = ["USER", "RES"]
var _MENU_ITEMS_DATA = [
	{ "text": "OS Default App Local Directory", "value": "user://" },
	{ "text": "Relative to Arrow's executable", "value": "res://" },
]
# items listed by key to ...
var _IDX = {} # index
var _ID = {} # id

func _ready() -> void:
	self.create_menu_items()
	popup.connect("id_pressed", self, "_on_self_popup_item_id_pressed", [], CONNECT_DEFERRED)
	pass

func create_menu_items() -> void:
	popup.clear()
	var item_id = 0; # here, id is the same as order of the item
	for item in _MENU_ITEMS:
		if item != null:
			_ID[item] = item_id
			popup.add_item(_MENU_ITEMS_DATA[item_id].text, item_id)
			_IDX[item] = popup.get_item_index(item_id)
		else:
			popup.add_separator();
		item_id += 1
	pass

func _on_self_popup_item_id_pressed(item_id) -> void:
	print_debug("app local dir reset menu popup item selected: ", _MENU_ITEMS_DATA[item_id].value)
	self.emit_signal("item_selected_value", _MENU_ITEMS_DATA[item_id].value)
	pass
