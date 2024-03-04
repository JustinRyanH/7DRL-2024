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

EntityHandle :: distinct Handle
Entity :: struct {
	position: WorldPosition,
}

Entities :: DataPool(1024, Entity, EntityHandle)

GameMemory :: struct {
	scene_size:        Vector2,
	tile_world_width:  u32,
	tile_world_height: u32,

	// Games
	fonts:             GameFonts,
	entities:          Entities,
	character:         EntityHandle,
	test_img:          Image,
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
	g_mem.tile_world_width = 80
	g_mem.tile_world_height = 60

	e, h, is_ok := data_pool_add_empty(&g_mem.entities)
	if !is_ok {
		panic("Failed to add Character")
	}
	e^ = Entity{WorldPosition{1, 1}}
	g_mem.character = h

	test_img, img_load_err := ctx.draw_cmds.load_img(
		"assets/textures/colored_transparent_packed.png",
	)
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.test_img = test_img

}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	if input.is_pressed(frame_input, .D) {
		a := data_pool_get_ptr(&g_mem.entities, g_mem.character)
		if a != nil {
			a.position += WorldPosition{1, 0}
		}
	}
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)

	camera := Camera2D{}
	camera.target = Vector2{}
	camera.offset = g_mem.scene_size / 2
	camera.rotation = 0
	camera.zoom = 1

	// draw_cmds.begin_drawing_2d(camera)
	// defer draw_cmds.end_drawing_2d()

	// draw_cmds.draw_grid(100, 50)

	atlas_example := AtlasImage {
		g_mem.test_img.handle,
		Vector2{},
		Vector2{16, 16},
		Vector2{},
		Rectangle{Vector2{16, 16}, Vector2{16, 16}, 0.0},
		0,
	}
	draw_cmds.draw_img(atlas_example, WHITE)
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
