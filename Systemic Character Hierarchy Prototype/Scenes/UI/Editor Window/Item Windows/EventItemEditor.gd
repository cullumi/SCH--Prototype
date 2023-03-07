class_name EventItemEditor

extends ItemEditor

@onready var ev_id:LineEdit = $"Top Row/EvID"
@onready var ev_type:MenuButton = $"Top Row/Type"
@onready var ev_role:MenuButton = $"Top Row/Role"
@onready var ev_anim:MenuButton = $"Top Row/Animation"
@onready var ev_fx:MenuButton = $"Top Row/Effects"
@onready var ev_iCIDs:MenuButton = $"Bottom Row/InCharIDs"
@onready var ev_oEIDs:MenuButton = $"Bottom Row/OutEventIDs"
@onready var ev_excl:Button = $"Bottom Row/Exclusive?"
@onready var events = Resources.event_settings

signal apply_filter

var fields = []
var ev_structure = Resources.event_structure
var event
var index
var id
var has_been_initialized = false

func _ready():
	initialize()

func initialize():
	if (index != null):
		# Find the event tied to this event editor
		if (index < events.size() and index >= 0):
			event = events[index]
		else:
			event = Resources.new_event(id)
			Resources.add_event(event)
		
		# Initialization of individual fields and buttons
		fields.append(ev_id)
		recursive_append_menu_buttons(self, fields)
		ev_id.text_submitted.connect(change_event.bind("EvID", ev_id))
		ev_id.focus_exited.connect(change_event.bind(null, "EvID", ev_id))
		for idx in range(1, ev_structure.size()-1):
			var popup:PopupMenu = fields[idx].get_popup()
			var signal_info = [ev_structure[idx], fields[idx]]
			popup.index_pressed.connect(change_event.bind(signal_info))
		ev_excl.toggled.connect(change_event.bind("Exclusive", ev_excl))
	
		update_contents()
		has_been_initialized = true

## For keeping track of menu buttons in the 'fields' array
#func recursive_append_menu_buttons(node:Node, array:Array):
#	for child in node.get_children():
#		if (child is MenuButton):
#			array.append(child)
#		recursive_append_menu_buttons(child, array)

func update_contents():
	var type = event["Type"]
	
	for idx in range(0, ev_structure.size()-1):
		fields[idx].text = event[ev_structure[idx]]
	ev_excl.button_pressed = bool(event["Exclusive"])

	for idx in range(1, ev_structure.size()-1):
		var button = fields[idx]
		var setting = ev_structure[idx]
		populate(button, Resources.find_restricted_choices(type, setting))

# For populating menu button popups
func populate(button : MenuButton, choices : Array):
	var popup:PopupMenu = button.get_popup()
	popup.clear()
	for option in choices:
		popup.add_item(option)

# Sends values to Resources for any needed adjustments when editing the event.
# Updates checkbox and checkbutton values to with those adjustments.
func change_event(value, setting, signaler):
	if (value == null):
		value = signaler.text
	if (signaler is MenuButton):
		value = signaler.get_popup().get_item_text(value) # Treat value as a popup index
	var adjusted_value = Resources.edit_event(event, setting, value)
	if ((not signaler is CheckBox) and (not signaler is CheckButton)):
		signaler.text = adjusted_value
	elif (adjusted_value != value):
		signaler.button_pressed = adjusted_value
	update_contents()

func move_up():
	index -= 1
	Resources.move_event(index, event)

func move_down():
	index += 1
	Resources.move_event(index, event)

func delete():
	Resources.remove_event(event)

# Applies filters to this item editor
func list_update(filters = null):
	if (filters != null):
		var final_filtered
		var fltr_results = []
		var fltr_andor = []
		for filter in filters:
			if (filter.enabled):
				var filtered = key_filtered(event, filter)
				if (filtered and filter.include_derivatives and event["OutEventIDs"] != ""):
					var ev = Resources.get_event_by_id(event["OutEventIDs"])
					filtered = key_filtered(ev, filter)
				# Allows for and/or functionality
				if (not filter.is_or_filter and key_filtered):
					final_filtered = true
					break
				else:
					fltr_results.append(!filtered)
		if (final_filtered == null):
			final_filtered = !exists(fltr_results)
		apply_filter.emit(final_filtered)
	populate(ev_oEIDs, Resources.find_restricted_choices(event["Type"], "OutEventIDs"))

# Determines whether this item editor should be filtered out based on the given filter.
func key_filtered(_event, filter:Filter) -> bool:
	for key in filter.filtered_keys:
		if (filter.filtered_keys[key]):
			if (should_be_filtered_out(_event, key, filter)):
				return true
	return false


# The bool and string comparison step of key filtering.
# Includes 'inclusive' and 'type_value' implemenations
func should_be_filtered_out(_event, key, filter):
	var invalid_bool = (_event[key] is bool and filter.boolean_value != _event[key])
	var invalid_string = _event[key] is String
	var invalid_type = false
	if (filter.inclusive):
		invalid_string = (invalid_string and not filter.string_value in _event[key])
	else:
		invalid_string = (invalid_string and not filter.string_value == _event[key])
	if (filter.type_value != "" and filter.type_value != _event["Type"]):
		invalid_type = true
	if (invalid_bool or invalid_string or invalid_type):
		return true
	return false

# Does there exist a true case?
func exists(arr : Array):
	for elem in arr:
		if (elem == true):
			return true
	return false
