extends CanvasLayer

var items = {}

func _ready():
	visible = false

func _input(event):
	if event.is_action_pressed("inventory"):
		visible = !visible

func add_item(item_name, qty = 1):
	items[item_name] = items.get(item_name, 0) + qty
	refresh_display()

func refresh_display():
	var text = ""
	for item in items:
		text += "  " + item + "   x" + str(items[item]) + "
"
	$Panel/VBoxContainer/ItemList.text = text if text != "" else "  (empty)"
