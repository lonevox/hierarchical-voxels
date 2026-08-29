extends TextureRect

const HotbarItem = preload("res://blocky_game/player/hotbar_item.gd")

@onready var _block_types = get_node("/root/Main/Game/Blocks")
@onready var _item_db = get_node("/root/Main/Game/Items")


func set_item(data: HotbarItem):
	if data == null:
		texture = null
		
	elif data.type == HotbarItem.TYPE_BLOCK:
		var block = _block_types.get_block(data.id)
		texture = block.base_info.sprite_texture

	elif data.type == HotbarItem.TYPE_ITEM:
		var item = _item_db.get_item(data.id)
		texture = item.base_info.sprite
	
	else:
		assert(false)
