package game


import sa "core:container/small_array"
import "core:fmt"
import "core:io"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"

import "./input"

import mu "../microui"

WorldPosition :: distinct [2]int

KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

MovementCell :: struct {
	point:  WorldPosition,
	offset: [2]int,
}

SearchNode :: struct {
	pos:        WorldPosition,
	g:          f32,
	h:          f32,
	connection: ^SearchNode,
}

GameFonts :: struct {
	kenney_block:  Font,
	kenney_future: Font,
}

GameAtlasList :: struct {
	transparent_color: ImageHandle,
	trail:             ImageHandle,
}

EntityHandle :: distinct Handle
Entity :: struct {
	world_pos: WorldPosition,
	img_type:  ImageType,
	color:     Color,
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

movement_grid: [dynamic]MovementCell

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
	e^ = Entity{WorldPosition{}, .Man, WHITE}
	g_mem.character = h

	goblin_pos := [4]WorldPosition{{-4, -5}, {-3, 3}, {4, 3}, {4, -2}}
	for pos in goblin_pos {
		data_pool_add(&g_mem.entities, Entity{pos, .Goblin, GREEN})
	}

	image, img_load_err := ctx.draw_cmds.load_img("assets/textures/colored_transparent_packed.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.atlas_list.transparent_color = image.handle

	image, img_load_err = ctx.draw_cmds.load_img("assets/textures/kenny_trail.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.atlas_list.trail = image.handle

}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	g_input = frame_input

	movement_grid = make([dynamic]MovementCell, 0, 1024, context.temp_allocator)

	dt := input.frame_query_delta(frame_input)
	character := data_pool_get_ptr(&g_mem.entities, g_mem.character)
	camera := &g_mem.camera

	if character == nil {
		panic("The player should always be in the game")
	}
	for x in -3 ..= 3 {
		for y in -3 ..= 3 {
			if x == 0 && y == 0 {
				continue
			}
			append(&movement_grid, MovementCell{character.world_pos + WorldPosition{x, y}, {x, y}})
		}
	}

	if input.was_just_released(frame_input, .D) {
		character.world_pos += WorldPosition{1, 0}
	}
	if input.was_just_released(frame_input, .A) {
		character.world_pos -= WorldPosition{1, 0}
	}
	if input.was_just_released(frame_input, .W) {
		character.world_pos -= WorldPosition{0, 1}
	}
	if input.was_just_released(frame_input, .S) {
		character.world_pos += WorldPosition{0, 1}
	}
	char_world_pos := world_pos_to_vec(character.world_pos) * 16
	camera_dist := math.length2(char_world_pos - camera.target)

	if camera_dist > 25 {
		camera.target = math.lerp(camera.target, char_world_pos, 2 * dt)
	}

	return ctx.cmds.should_close_game()
}

@(export)
game_draw :: proc() {
	game := g_mem
	draw_cmds := &ctx.draw_cmds
	draw_camera := &ctx.draw_cmds.camera
	draw_cmds.clear(BLACK)

	{
		draw_camera.begin_drawing_2d(game.camera)
		defer draw_camera.end_drawing_2d()

		draw_cmds.draw_grid(100, 16, Vector2{4, 4} * 50)

		for cell in movement_grid {
			draw_cmds.draw_shape(
				Rectangle{world_pos_to_vec(cell.point) * 16, Vector2{8, 8}, 0.0},
				Color{.2, .21, .28, 0.3},
			)
		}

		character := data_pool_get_ptr(&g_mem.entities, g_mem.character)

		screen_pos := draw_camera.screen_to_world_2d(game.camera, input.mouse_position(g_input))
		world_pos := world_pos_from_space_as_vec(screen_pos)
		world_pos_int := world_pos_from_space(screen_pos)

		// path := find_path_t(world_pos_int, character.world_pos)
		// for p in path {
		// 	draw_cmds.draw_shape(
		// 		Rectangle{world_pos_to_vec(p) * 16, Vector2{14, 14}, 0},
		// 		Color{1, 0, 0, 0.5},
		// 	)
		// }

		// draw_cmds.draw_shape(Rectangle{world_pos * 16, Vector2{14, 14}, 0}, Color{1, 0, 0, 0.5})
		draw_cmds.draw_text(
			fmt.ctprintf("%v", world_pos),
			cast(i32)screen_pos.x,
			cast(i32)screen_pos.y + 10,
			8,
			RED,
		)


		entity_iter := data_pool_new_iter(&game.entities)
		for entity in data_pool_iter(&entity_iter) {
			atlas_example := map_entity_to_atlas(g_mem.atlas_list.transparent_color, entity)
			draw_cmds.draw_img(atlas_example, entity.color)
		}
	}

	draw_mouse()
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

draw_mouse :: proc() {
	draw_cmds := &ctx.draw_cmds

	mouse_pos := input.mouse_position(g_input)
	mouse_atl := AtlasImage{}
	mouse_atl.image = g_mem.atlas_list.transparent_color
	mouse_atl.pos = mouse_pos
	mouse_atl.size = Vector2{32, 32}
	mouse_atl.src = Rectangle{Vector2{38, 10} * 16, Vector2{16, 16}, 0}
	draw_cmds.draw_img(mouse_atl, WHITE)

}

world_pos_to_vec :: #force_inline proc(pos: WorldPosition) -> Vector2 {
	return Vector2{cast(f32)pos.x, cast(f32)pos.y}
}

world_pos_from_space :: #force_inline proc(pos: Vector2) -> WorldPosition {
	v := world_pos_from_space_as_vec(pos)
	return WorldPosition{cast(int)v.x, cast(int)v.y}
}

world_pos_from_space_as_vec :: #force_inline proc(pos: Vector2) -> Vector2 {
	return math.round(pos / 16)
}


get_neighbors :: proc(search_node: SearchNode) -> [4]SearchNode {
	offsets := [4]WorldPosition{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	nodes := [4]SearchNode{}

	for node, i in &nodes {
		node.pos = search_node.pos + offsets[i]
		node.g = search_node.g + 1
	}
	return nodes
}

max_walk_count := 128

find_path_t :: proc(src_pos: WorldPosition, t_pos: WorldPosition) -> []WorldPosition {
	if src_pos == t_pos {
		return []WorldPosition{}
	}
	start := SearchNode{}
	start.pos = src_pos

	target := SearchNode{}
	target.pos = t_pos

	to_search := make(map[WorldPosition]SearchNode, 32, context.temp_allocator)
	to_search[start.pos] = start

	processed := make(map[WorldPosition]SearchNode, 32, context.temp_allocator)

	for i := 0; i < max_walk_count; i += 1 {
		current: SearchNode
		current.h = max(f32)

		for _, t in to_search {
			target_f := t.h + t.g
			current_f := current.h + current.g

			if (target_f < current_f || target_f == current_f && t.h < current.h) {
				current = t
			}
		}

		processed[current.pos] = current
		delete_key(&to_search, current.pos)

		if current.pos == target.pos {
			path := make([dynamic]WorldPosition, 0, 32, context.temp_allocator)
			next := current.connection
			for next != nil {
				fmt.println(next)
				append(&path, next.pos)
				next = next.connection
			}
			return path[:]
		}

		neighbors := get_neighbors(current)
		for neighbor in &neighbors {
			if neighbor.pos in processed {
				continue
			}

			in_search := neighbor.pos in to_search
			cost_to_neighbor := current.g + 1

			if !in_search || cost_to_neighbor < neighbor.g {
				neighbor.connection = &processed[current.pos]
				neighbor.g = cost_to_neighbor

				if !in_search {
					neighbor.h = math.floor(math.length(world_pos_to_vec(neighbor.pos)) * 10)
					to_search[neighbor.pos] = neighbor
				}
			}
		}
	}

	return []WorldPosition{}
}
