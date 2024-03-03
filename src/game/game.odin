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

Character :: struct {
	position: WorldPosition,
}

EntityHandle :: distinct Handle
Entity :: union {
	Character,
}

Entities :: DataPool(1024, Entity, EntityHandle)

GameMemory :: struct {
	scene_width:       f32,
	scene_height:      f32,
	tile_world_width:  u32,
	tile_world_height: u32,

	// Games
	fonts:             GameFonts,
	entities:          Entities,
	character:         EntityHandle,
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

	g_mem.scene_width = 800
	g_mem.scene_height = 600
	g_mem.tile_world_height = 80
	g_mem.tile_world_width = 60

	e, h, is_ok := data_pool_add_empty(&g_mem.entities)
	if !is_ok {
		panic("Failed to add Character")
	}
	e^ = Character{WorldPosition{1, 1}}
	g_mem.character = h

}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	if input.is_pressed(.D) {
	}
	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	width, height := g_mem.scene_width, g_mem.scene_height
	draw_cmds := &ctx.draw_cmds
	draw_cmds.clear(BLACK)


	a, found := data_pool_get(&g_mem.entities, g_mem.character)
	if found {
		character, ok := a.(Character)
		if ok {
			size := Vector2{10, 10}

			scale_x, scale_y :=
				g_mem.scene_width /
				cast(f32)g_mem.tile_world_width,
				g_mem.scene_height /
				cast(f32)g_mem.tile_world_height

			p := Vector2{cast(f32)character.position.x, cast(f32)character.position.y}
			real_p := p * Vector2{scale_x, scale_y}

			draw_cmds.draw_shape(Rectangle{real_p, size, 0}, RED)

		}
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
