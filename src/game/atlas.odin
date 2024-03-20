package game

SpritePosition :: [2]f32


ImageType :: enum {
	Man,
	Goblin,
}


Man :: SpritePosition{25, 0}
Goblin :: SpritePosition{25, 2}
TargetPosition :: SpritePosition{36, 12}
AttackTargetPosition :: SpritePosition{20, 14}


map_position_to_atlas :: proc(atlas: ^AtlasImage, spr_pos: SpritePosition) {
	atlas.src.pos = cast(Vector2)(spr_pos * 16)
	atlas.src.size = Vector2{16, 16}
	atlas.size = Vector2{16, 16}
	atlas.origin = Vector2{8, 8}
}


map_entity_to_atlas :: proc(atlas: ImageHandle, entity: Entity) -> (img: AtlasImage) {
	img.image = atlas
	spr_pos := get_image_type_pos(entity.img_type)
	map_position_to_atlas(&img, spr_pos)
	img.pos = entity.display_pos * 16


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
