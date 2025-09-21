extends Node


## The terrain view distance in chunks. Each chunk is 32 by 32 by 32 voxels.
@export_range(0, 16) var view_distance := 16:
	set(value):
		assert(view_distance >= 0)
		assert(view_distance <= 16)
		view_distance = value
