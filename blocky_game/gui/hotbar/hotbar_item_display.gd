extends TextureRect

const HotbarItem = preload("res://blocky_game/player/hotbar_item.gd")

@onready var _item_db = get_node("/root/Main/Game/Items")


func set_item(data: HotbarItem):
	if data == null:
		texture = null
		
	elif data.type == HotbarItem.TYPE_MATERIAL:
		# TODO: Material preview icons have not been made yet. They'll probably be
		# created programatically, maybe rendered as a 3D cube within the slot.
		texture = null

	elif data.type == HotbarItem.TYPE_ITEM:
		var item = _item_db.get_item(data.id)
		texture = item.base_info.sprite
	
	else:
		assert(false)
