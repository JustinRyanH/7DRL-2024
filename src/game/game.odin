package game


import sa "core:container/small_array"
import "core:fmt"
import "core:io"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "./input"

import mu "../microui"


WorldPosition :: [2]u32
KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

GameFonts :: struct {
	kenney_block:  Font,
	kenney_future: Font,
}

GameAtlasList :: struct {
	transparent_color: ImageHandle,
}

EntityHandle :: distinct Handle
Entity :: struct {
	position: Vector2,
	img_type: ImageType,
	color:    Color,
}

Entities :: DataPool(1024, Entity, EntityHandle)

GameMemory :: struct {
	scene_size: Vector2,

	// Assets
	fonts:      GameFonts,
	atlas_list: GameAtlasList,


	// Game
	entities:   Entities,
	character:  EntityHandle,
	camera:     Camera2D,
}


ctx: ^Context
g_input: input.FrameInput
g_mem: ^GameMemory

current_input :: #force_inline proc() -> input.UserInput {
	return g_input.current_frame
}

@(export)
game_init :: proc() {
	g_mem = new(GameMemory)
}

@(export)
game_setup :: proc() {
	// We're doing hard reset. This will clear out any lingering handles between frame
	g_mem^ = GameMemory{}

	g_mem.scene_size.x = 800
	g_mem.scene_size.y = 600

	camera := Camera2D{}
	camera.target = Vector2{}
	camera.offset = (g_mem.scene_size / 2) - Vector2{16, 16}
	camera.rotation = 0
	camera.zoom = 3.5

	g_mem.camera = camera

	e, h, is_ok := data_pool_add_empty(&g_mem.entities)
	if !is_ok {
		panic("Failed to add Character")
	}
	e^ = Entity{Vector2{}, .Man, WHITE}
	g_mem.character = h

	goblin_pos := [4]Vector2{{-4, -5}, {-3, 3}, {4, 3}, {4, -2}}
	for pos in goblin_pos {
		data_pool_add(&g_mem.entities, Entity{pos * 16, .Goblin, GREEN})
	}


	transparent_color, img_load_err := ctx.draw_cmds.load_img(
		"assets/textures/colored_transparent_packed.png",
	)
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.atlas_list.transparent_color = transparent_color.handle

}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	dt := input.frame_query_delta(frame_input)
	character := data_pool_get_ptr(&g_mem.entities, g_mem.character)
	camera := &g_mem.camera

	if character == nil {
		panic("The player should always be in the game")
	}
	if input.was_just_released(frame_input, .D) {
		character.position += Vector2{16, 0}
	}
	if input.was_just_released(frame_input, .A) {
		character.position -= Vector2{16, 0}
	}
	if input.was_just_released(frame_input, .W) {
		character.position -= Vector2{0, 16}
	}
	if input.was_just_released(frame_input, .S) {
		character.position += Vector2{0, 16}
	}
	camera_dist := math.length2(character.position - camera.target)

	if camera_dist > 100 {
		camera.target = math.lerp(camera.target, character.position, 2 * dt)
	}

	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	draw_cmds.begin_drawing_2d(game.camera)
	defer draw_cmds.end_drawing_2d()

	entity_iter := data_pool_new_iter(&game.entities)
	for entity in data_pool_iter(&entity_iter) {
		atlas_example := map_entity_to_atlas(g_mem.atlas_list.transparent_color, entity)
		draw_cmds.draw_img(atlas_example, entity.color)
	}
}


@(export)
game_shutdown :: proc() {
	free(g_mem)
}

@(export)
game_memory :: proc() -> rawptr {
	return g_mem
}

@(export)
game_hot_reloaded :: proc(mem: ^GameMemory) {
	g_mem = mem
}

@(export)
game_save_to_stream :: proc(stream: io.Stream) -> io.Error {
	_, err := io.write_ptr(stream, g_mem, size_of(GameMemory))
	return err
}

@(export)
game_load_from_stream :: proc(stream: io.Stream) -> io.Error {
	_, err := io.read_ptr(stream, g_mem, size_of(GameMemory))
	return err
}

@(export)
game_mem_size :: proc() -> int {
	return size_of(GameMemory)
}
