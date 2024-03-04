package game

SpritePosition :: [2]f32


ImageType :: enum {
	Man,
	Goblin,
}


Man :: SpritePosition{25, 0}
Goblin :: SpritePosition{25, 2}


map_entity_to_atlas :: proc(atlas: ImageHandle, entity: Entity) -> (img: AtlasImage) {
	img.image = atlas
	spr_pos := get_image_type_pos(entity.img_type)
	img.src.pos = cast(Vector2)(spr_pos * 16)
	img.src.size = Vector2{16, 16}
	img.size = Vector2{16, 16}
	img.pos = entity.position
	img.origin = Vector2{8, 8}


	return img

}

@(private = "file")
get_image_type_pos :: proc(img_type: ImageType) -> (pos: SpritePosition) {
	switch img_type {
	case .Man:
		pos = Man
	case .Goblin:
		pos = Goblin
	}
	return
}
