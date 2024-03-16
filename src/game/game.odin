package game


import sa "core:container/small_array"
import "core:fmt"
import "core:io"
import math "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:slice"

import "./input"

import mu "../microui"

KbKey :: input.KeyboardKey
MouseBtn :: input.MouseButton

StartMoving :: struct {
	entity: EntityHandle,
	path:   []Step,
}

BeginWait :: struct {
	entity: EntityHandle,
}

MoveCommandOutOfRange :: struct {
	entity:     EntityHandle,
	total_cost: int,
}

GameEvent :: union {
	StartMoving,
	BeginWait,
	MoveCommandOutOfRange,
}

MovementCell :: struct {
	point:  WorldPosition,
	offset: [2]int,
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
	pos:            WorldPosition,
	display_pos:    Vector2,
	img_type:       ImageType,
	color:          Color,
	movement_speed: int,
	action:         EntityAction,
}

// The Entity is waiting for command
EntityWait :: struct {}

// The Entity has been commanded to move
EntityMove :: struct {
	path:         []Step,
	current_step: int,
	percentage:   f32,
}

EntityAction :: union {
	EntityWait,
	EntityMove,
}

Entities :: DataPool(128, Entity, EntityHandle)

GameMemory :: struct {
	scene_size:    Vector2,

	// Assets
	fonts:         GameFonts,
	atlas_list:    GameAtlasList,


	// Game
	event_queue:   RingBuffer(32, GameEvent),
	entities:      Entities,
	character:     EntityHandle,
	camera:        Camera2D,
	ui_action_bar: UiActionBar,
}

UiActionBar :: struct {
	position:        Vector2,
	bar_size:        Vector2,
	x_start_pointer: f32,
	spell_large_b:   Font,
	action_atlas:    ImageHandle,
}


ctx: ^Context
g_input: input.FrameInput
g_mem: ^GameMemory

maybe_path: []Step

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

	g_mem.scene_size.x = 1280
	g_mem.scene_size.y = 800

	camera := Camera2D{}
	camera.target = Vector2{}
	camera.offset = (g_mem.scene_size / 2) - Vector2{16, 16} - Vector2{0, 64}
	camera.rotation = 0
	camera.zoom = 2.5

	g_mem.camera = camera

	e, h, is_ok := data_pool_add_empty(&g_mem.entities)
	if !is_ok {
		panic("Failed to add Character")
	}
	e^ = Entity{WorldPosition{}, Vector2{}, .Man, WHITE, 6, EntityWait{}}
	g_mem.character = h

	goblin_pos := [4]WorldPosition{{-4, -5}, {-3, 3}, {4, 3}, {4, -2}}
	for pos in goblin_pos {
		data_pool_add(
			&g_mem.entities,
			Entity{pos, world_pos_to_vec(pos), .Goblin, GREEN, 4, EntityWait{}},
		)
	}

	image, img_load_err := ctx.draw_cmds.load_img("assets/textures/colored_transparent_packed.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.atlas_list.transparent_color = image.handle

	image, img_load_err = ctx.draw_cmds.load_img("assets/textures/kenney_trail.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.atlas_list.trail = image.handle

	g_mem.ui_action_bar.spell_large_b = ctx.draw_cmds.text.load_font(
		"assets/fonts/spellbook_large_bold.ttf",
	)
	g_mem.ui_action_bar.bar_size = Vector2{900, 160}
	image, img_load_err = ctx.draw_cmds.load_img("assets/textures/pf2e_action_icons.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.ui_action_bar.action_atlas = image.handle
}

@(export)
game_update_context :: proc(new_ctx: ^Context) {
	ctx = new_ctx
}

@(export)
game_update :: proc(frame_input: input.FrameInput) -> bool {
	ui_action_bar_reset(&g_mem.ui_action_bar)
	g_input = frame_input

	maybe_path = []Step{}

	dt := input.frame_query_delta(frame_input)
	character: ^Entity = data_pool_get_ptr(&g_mem.entities, g_mem.character)
	camera := &g_mem.camera
	assert(character != nil, "The player should always be in the game")

	game_process_events(g_mem)

	draw_camera := &ctx.draw_cmds.camera
	screen_pos := draw_camera.screen_to_world_2d(g_mem.camera, input.mouse_position(g_input))
	world_pos := world_pos_from_space_as_vec(screen_pos)
	world_pos_int := world_pos_from_space(screen_pos)


	switch action in &character.action {
	case EntityWait:
		character.display_pos = world_pos_to_vec(character.pos)

		wpf := WorldPathfinder{}
		world_path_finder_init(&wpf, g_mem.character, world_pos_int)
		path_new, path_status := world_path_finder_get_path_t(wpf)
		if path_status == .PathFound {
			maybe_path = path_new
		}

		if input.was_just_released(frame_input, .D) {
			character.pos += WorldPosition{1, 0}
		}
		if input.was_just_released(frame_input, .A) {
			character.pos -= WorldPosition{1, 0}
		}
		if input.was_just_released(frame_input, .W) {
			character.pos -= WorldPosition{0, 1}
		}
		if input.was_just_released(frame_input, .S) {
			character.pos += WorldPosition{0, 1}
		}

		if input.was_just_released(frame_input, input.MouseButton.LEFT) {
			game_order_entity_move(g_mem, g_mem.character, maybe_path)
		}
	case EntityMove:
		game_entity_handle_move_command(g_mem.character, character, &action)
	}

	char_world_pos := world_pos_to_vec(character.pos) * 16
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
	draw_cmds.clear(Liver)

	width, height := input.frame_query_dimensions(g_input)

	{
		draw_camera.begin_drawing_2d(game.camera)
		defer draw_camera.end_drawing_2d()

		draw_cmds.draw_grid(100, 16, Vector2{4, 4} * 50)

		character: ^Entity = data_pool_get_ptr(&g_mem.entities, g_mem.character)
		assert(character != nil, "Character should always exists")

		total_cost := 0
		#reverse for step in maybe_path {
			p := step.position
			total_cost += step.step_cost
			color := Color{1, 0, 0, 0.5}
			if total_cost > character.movement_speed {
				color.a = 0.2
			}

			draw_cmds.draw_shape(Rectangle{world_pos_to_vec(p) * 16, Vector2{14, 14}, 0}, color)
		}
		if len(maybe_path) > 0 {
			total_cost := step_total_cost(maybe_path)

			screen_pos := draw_camera.screen_to_world_2d(
				game.camera,
				input.mouse_position(g_input),
			)
			draw_cmds.draw_text(
				fmt.ctprintf("%dft", total_cost * 5),
				cast(i32)screen_pos.x,
				cast(i32)screen_pos.y + 10,
				8,
				RED,
			)
		}


		entity_iter := data_pool_new_iter(&game.entities)
		for entity in data_pool_iter(&entity_iter) {
			atlas_example := map_entity_to_atlas(g_mem.atlas_list.transparent_color, entity)
			draw_cmds.draw_img(atlas_example, entity.color)
		}
	}

	{
		action_bar := &g_mem.ui_action_bar
		ui_action_bar_begin_draw(action_bar)
		ui_action_bar_end_draw(action_bar)

		// ui_action_bar_draw_card(action_bar, CharacterAction{"Strike", "Strike", 1})
		// ui_action_bar_draw_card(action_bar, CharacterAction{"First Aid", "F. Aid", 2})
		// ui_action_bar_draw_card(action_bar, CharacterAction{"Lie", "Lie", 3})
		// ui_action_bar_draw_card(
		// 	action_bar,
		// 	CharacterAction{"Grab an Edge", "Grab Edge", .Reaction},
		// )
		// ui_action_bar_draw_card(
		// 	action_bar,
		// 	CharacterAction{"Drop Weapon", "Dp. Weapon", .FreeAction},
		// )
	}


	// offset: f32 = 0
	// space := draw_action_card(Vector2{100 + offset, 100}, "Feint")
	// offset += space.x + 16
	// space = draw_action_card(Vector2{100 + offset, 100}, "Strike")
	// offset += space.x + 16
	// draw_action_card(Vector2{100 + offset, 100}, "Escape")

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

// TODO: This is a gross N multiplier, we should keep a hash of entities at tiles
game_entity_at_pos :: proc(game: ^GameMemory, pos: WorldPosition) -> (EntityHandle, bool) {
	iter := data_pool_new_iter(&game.entities)
	for entity, handle in data_pool_iter(&iter) {
		if entity.pos == pos {
			return handle, true
		}
	}
	return EntityHandle{}, false
}

can_entity_move_into_position :: proc(
	game: ^GameMemory,
	entity: EntityHandle,
	pos: WorldPosition,
) -> bool {
	ent_at_pos, exists := game_entity_at_pos(game, pos)
	if (!exists) {
		return true
	}
	return ent_at_pos == entity
}

game_order_entity_move :: proc(mem: ^GameMemory, handle: EntityHandle, path: []Step) {
	if len(path) == 0 {
		// TODO: This should have a warning log
		return
	}
	entity := data_pool_get_ptr(&mem.entities, handle)
	if entity == nil {
		return
	}

	total_cost := step_total_cost(maybe_path)
	if total_cost > entity.movement_speed {
		ring_buffer_append(&mem.event_queue, MoveCommandOutOfRange{handle, total_cost})
		return
	}
	next_evt := StartMoving{}
	next_evt.entity = g_mem.character
	next_evt.path = make([]Step, len(maybe_path))
	copy(next_evt.path, maybe_path)
	slice.reverse(next_evt.path)
	ring_buffer_append(&g_mem.event_queue, next_evt)
}

game_process_events :: proc(mem: ^GameMemory) {
	for event in ring_buffer_pop(&mem.event_queue) {
		switch evt in event {
		case StartMoving:
			entity := data_pool_get_ptr(&mem.entities, evt.entity)
			// TODO: Warn when we give command to non-existant entity
			if entity != nil {
				move := EntityMove{}

				move.path = evt.path
				entity.action = move

				assert(len(move.path) > 0, "we shouldn't have zero paths moves")
			}
		case BeginWait:
			entity := data_pool_get_ptr(&mem.entities, evt.entity)
			// TODO: Warn when we give command to non-existant entity
			if entity != nil {
				entity.action = EntityWait{}
			}
		case MoveCommandOutOfRange:
			// TODO: Let's make a little Toast
			e, found := data_pool_get(&mem.entities, evt.entity)
			if found {
				fmt.printf(
					"Out of Range, Max of %dft but tried to travel %dft\n",
					e.movement_speed * 5,
					evt.total_cost * 5,
				)
			}

		}
	}


}

game_entity_handle_move_command :: proc(
	handle: EntityHandle,
	entity: ^Entity,
	action: ^EntityMove,
) {
	mem := g_mem
	dt := input.frame_query_delta(g_input)

	action.percentage += dt * 5
	if action.percentage >= 1 {
		if action.current_step < len(action.path) - 2 {
			left := action.percentage - 1
			action.percentage = left
			action.current_step += 1
		} else {
			action.percentage = 1
			ring_buffer_append(&mem.event_queue, BeginWait{handle})
			delete(action.path)
			return
		}
	}

	step := action.current_step
	last_step := world_pos_to_vec(action.path[step].position)
	next_step := world_pos_to_vec(action.path[step + 1].position)

	entity.pos = action.path[step + 1].position
	entity.display_pos = math.lerp(last_step, next_step, action.percentage)
}

max_walk_count := 128
