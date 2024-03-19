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

DirectCommand :: enum {
	BeginWait,
}

StartMoving :: struct {
	cost: int,
	path: []Step,
}

MoveCommandOutOfRange :: struct {
	entity:     EntityHandle,
	total_cost: int,
	kind:       MovementKind,
}

EncounterEvent :: union {
	StartMoving,
	MoveCommandOutOfRange,
	DirectCommand,
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
EntityTags :: enum {
	Pc,
	Npc,
}

EntityHandle :: distinct Handle
Entity :: struct {
	pos:            WorldPosition,
	display_pos:    Vector2,
	img_type:       ImageType,
	color:          Color,
	movement_speed: int,
	action:         EntityAction,
	tags:           bit_set[EntityTags],
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

EncounterUi :: struct {
	select_pulse_time: f32,
}

// Likely will include other kinds like Fly, Swim, ect.
MovementKind :: enum {
	Step,
	Stride,
}

WaitingMovement :: struct {
	// TempAllocator, remove for every frame
	path_t: []Step,
	cost:   int,
	kind:   MovementKind,
}

PerformingMovement :: struct {
	// StdAlloxator, needs to be cleaned up when removed
	path:         []Step,
	current_step: int,
	percentage:   f32,
}

OtherState :: enum {
	OutOfActions,
}

EncounterState :: union {
	PerformingMovement,
	WaitingMovement,
	OtherState,
}

Encounter :: struct {
	active_entity:   int,
	combat_queue:    [dynamic]EntityHandle,
	display_actions: [dynamic]CharacterAction,
	event_queue:     RingBuffer(32, EncounterEvent),
	ui:              EncounterUi,
	state:           EncounterState,
	actions_left:    int,
	active_action:   int,
}

encounter_begin :: proc(encounter: ^Encounter) {
	encounter.active_entity = -1
	encounter.combat_queue = make([dynamic]EntityHandle, 0, 32)
	encounter.display_actions = make([dynamic]CharacterAction, 0, 32)
}

encounter_end :: proc(encounter: ^Encounter) {
	delete(encounter.combat_queue)
	delete(encounter.display_actions)
}

encounter_begin_wait :: proc(encounter: ^Encounter, action: CharacterAction) {
	if !encounter_waiting_for_input(encounter) {
		return
	}
	if action.cost > encounter.actions_left {
		encounter.state = OtherState.OutOfActions
		return
	}
	#partial switch action.type {
	case .Stride:
		wait := WaitingMovement{}
		wait.kind = .Stride
		wait.cost = action.cost
		encounter.state = wait
	case .Step:
		wait := WaitingMovement{}
		wait.kind = .Step
		wait.cost = action.cost
		encounter.state = wait
	}
}


encounter_get_active_handle :: proc(encounter: ^Encounter) -> EntityHandle {
	if (encounter.active_entity < 0 || len(encounter.combat_queue) == 0) {
		return EntityHandle{}
	}
	return encounter.combat_queue[encounter.active_entity]
}

encounter_waiting_for_input :: proc(encounter: ^Encounter) -> bool {
	#partial switch v in encounter.state {
	case PerformingMovement:
		return false
	case:
		return true
	}
}

encounter_get_active_ptr :: proc(encounter: ^Encounter) -> (ent: ^Entity) {
	handle := encounter_get_active_handle(encounter)
	if handle == 0 {
		return
	}
	return data_pool_get_ptr(&g_mem.entities, handle)
}

// This is a Multi-Frame Action, So this needs to be cleaned up for that later
encounter_next_character :: proc(encounter: ^Encounter) {
	// TODO: This shouldn't be cleared, but an event, so we can abnimate this out
	clear(&encounter.display_actions)
	encounter.active_entity = (encounter.active_entity + 1) % len(encounter.combat_queue)
	encounter.actions_left = 3
	encounter.active_action = 0
	entity := encounter_get_active_ptr(encounter)
	assert(entity != nil, "The Entity should always exists here")
	if .Pc in entity.tags {
		// TODO: this should be an event, so we can animate them onto the board
		append(&encounter.display_actions, get_action(.Stride))
		append(&encounter.display_actions, get_action(.Step))
	}
}

encounter_preview_next_action :: proc(encounter: ^Encounter) {
	num_of_actions := len(encounter.display_actions)
	if num_of_actions == 0 {
		return
	}
	encounter.active_action += 1
	if encounter.active_action >= num_of_actions {
		encounter.active_action = 0
	}
}

encounter_preview_previous_action :: proc(encounter: ^Encounter) {
	num_of_actions := len(encounter.display_actions)
	if num_of_actions == 0 {
		return
	}
	encounter.active_action -= 1
	if encounter.active_action < 0 {
		encounter.active_action = num_of_actions - 1
	}
}

encounter_selected_action :: proc(encounter: ^Encounter) -> (CharacterAction, bool) {
	num_of_actions := len(encounter.display_actions)
	if num_of_actions > 0 && encounter.active_action < num_of_actions {
		action := encounter.display_actions[encounter.active_action]
		return action, true
	}
	return CharacterAction{}, false
}

encounter_process_events :: proc(encounter: ^Encounter) {
	for evt in ring_buffer_pop(&encounter.event_queue) {
		switch v in evt {
		case StartMoving:
			encounter.state = PerformingMovement{v.path, 0, 0}
			encounter.actions_left -= v.cost
		case MoveCommandOutOfRange:
			// TODO: Toast the error
			fmt.printf("Out of Range: %v", v)
		case DirectCommand:
			switch v {
			case .BeginWait:
				entity := encounter_get_active_ptr(encounter)
				entity.display_pos = world_pos_to_vec(entity.pos)
				encounter.state = nil
			}
		}
	}
}

encounter_perform_movement :: proc(encounter: ^Encounter, state: ^PerformingMovement) {
	dt := input.frame_query_delta(g_input)
	entity := encounter_get_active_ptr(encounter)


	state.percentage += dt * 5
	if state.percentage >= 1 {
		if state.current_step < len(state.path) - 2 {
			left := state.percentage - 1
			state.percentage = left
			state.current_step += 1
		} else {
			ring_buffer_append(&encounter.event_queue, DirectCommand.BeginWait)
			delete(state.path)
			return
		}
	}

	step := state.current_step
	last_step := world_pos_to_vec(state.path[step].position)
	next_step := world_pos_to_vec(state.path[step + 1].position)

	entity.pos = state.path[step + 1].position
	entity.display_pos = math.lerp(last_step, next_step, state.percentage)
}

Exploration :: struct {}
Downtime :: struct {}

GameMode :: union {
	Encounter,
	Exploration,
	Downtime,
}

GameMemory :: struct {
	scene_size:    Vector2,

	// Assets
	fonts:         GameFonts,
	atlas_list:    GameAtlasList,


	// Game
	entities:      Entities,
	character:     EntityHandle,
	camera:        Camera2D,
	game_mode:     GameMode,
	ui_action_bar: UiActionBar,
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
	e^ = Entity{WorldPosition{}, Vector2{}, .Man, WHITE, 6, EntityWait{}, {.Pc}}
	g_mem.character = h

	goblin_pos := [4]WorldPosition{{-4, -5}, {-3, 3}, {4, 3}, {4, -2}}
	for pos in goblin_pos {
		data_pool_add(
			&g_mem.entities,
			Entity{pos, world_pos_to_vec(pos), .Goblin, GREEN, 4, EntityWait{}, {.Npc}},
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
	g_mem.ui_action_bar.bar_size = Vector2{900, 130}
	image, img_load_err = ctx.draw_cmds.load_img("assets/textures/pf2e_action_icons.png")
	if img_load_err != .NoError {
		panic(fmt.tprintf("Bad Image Load: %v", img_load_err))
	}
	g_mem.ui_action_bar.action_atlas = image.handle

	encounter := Encounter{}
	encounter_begin(&encounter)
	append(&encounter.combat_queue, g_mem.character)
	entity_iter := data_pool_new_iter(&g_mem.entities)
	for _, handle in data_pool_iter(&entity_iter) {
		if handle == g_mem.character {
			continue
		}
		append(&encounter.combat_queue, handle)
	}
	g_mem.game_mode = encounter
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

	draw_camera := &ctx.draw_cmds.camera

	#partial switch mode in &g_mem.game_mode {
	case Encounter:
		assert(len(mode.combat_queue) > 0, "Hey you need a combat queue idiot")

		encounter_process_events(&mode)
		if mode.active_entity < 0 {
			encounter_next_character(&mode)
		}

		if input.was_just_released(frame_input, input.KeyboardKey.SPACE) {
			encounter_next_character(&mode)
		}

		if input.was_just_released(frame_input, input.KeyboardKey.D) {
			encounter_preview_next_action(&mode)
		}
		if input.was_just_released(frame_input, input.KeyboardKey.A) {
			encounter_preview_previous_action(&mode)
		}

		entity := encounter_get_active_ptr(&mode)
		// TODO: Only do this we are not actually acting
		action, exists := encounter_selected_action(&mode)
		if exists {
			encounter_begin_wait(&mode, action)
		}

		#partial switch state in &mode.state {
		case WaitingMovement:
			screen_pos := draw_camera.screen_to_world_2d(
				g_mem.camera,
				input.mouse_position(g_input),
			)
			world_pos := world_pos_from_space_as_vec(screen_pos)
			world_pos_int := world_pos_from_space(screen_pos)

			wpf := WorldPathfinder{}
			world_path_finder_init(&wpf, g_mem.character, world_pos_int)
			path_new, path_status := world_path_finder_get_path_t(wpf)
			if path_status == .PathFound {
				state.path_t = path_new
			}

			if input.was_just_released(frame_input, input.MouseButton.LEFT) {
				is_within_range := draw_is_within_range(state.path_t, state.kind, entity)
				e_handle := encounter_get_active_handle(&mode)
				if is_within_range {
					path_copy := make([]Step, len(state.path_t))
					copy(path_copy, state.path_t)
					slice.reverse(path_copy)
					ring_buffer_append(&mode.event_queue, StartMoving{state.cost, path_copy})
				} else {
					cost := step_total_cost(state.path_t)
					ring_buffer_append(
						&mode.event_queue,
						MoveCommandOutOfRange{e_handle, cost, state.kind},
					)
				}
			}
		case PerformingMovement:
			encounter_perform_movement(&mode, &state)
		case OtherState:
			switch state {
			case .OutOfActions:
			}
		}
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
	dt := input.frame_query_delta(g_input)

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

		#partial switch mode in &g_mem.game_mode {
		case Encounter:
			entity := encounter_get_active_ptr(&mode)
			assert(entity != nil, "Entity Should not be despawned")
			if mode.active_entity >= 0 && len(mode.combat_queue) > 0 {
				mode.ui.select_pulse_time += dt * 4
				if mode.ui.select_pulse_time > math.TAU {
					mode.ui.select_pulse_time = 0
				}
				low_factor: f32 = 1.2
				high_factor: f32 = 1.4

				target_atlas := AtlasImage{}
				target_atlas.image = g_mem.atlas_list.transparent_color
				map_position_to_atlas(&target_atlas, TargetPosition)
				target_atlas.pos = entity.display_pos * 16
				old_size := target_atlas.size


				k := pulse_value(mode.ui.select_pulse_time)
				target_atlas.size = math.lerp(old_size * low_factor, old_size * high_factor, k)
				target_atlas.origin = target_atlas.size * 0.5

				draw_cmds.draw_img(target_atlas, WHITE)
			}

			#partial switch state in &mode.state {
			case WaitingMovement:
				draw_proposed_path(state.path_t, state.kind, entity)

			}
		}
	}


	#partial switch mode in &g_mem.game_mode {
	case Encounter:
		{
			entity := encounter_get_active_handle(&mode)
			action_bar := &g_mem.ui_action_bar
			ui_action_bar_begin_draw(action_bar, entity)
			ui_action_bar_end_draw(action_bar)

			for action, idx in mode.display_actions {
				meta := UiActionMeta{mode.active_action == idx}
				ui_action_bar_draw_card(action_bar, action, meta)
			}
			ui_action_bar_draw_cost(action_bar, mode.actions_left)
			ui_action_bar_draw_turn_btn(action_bar)
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

max_walk_count := 128

pulse_value :: proc(v: f32) -> f32 {
	return (math.sin(v) + 1) / 2
}

draw_is_within_range :: proc(path: []Step, movemnt_kind: MovementKind, entity: ^Entity) -> bool {
	if len(path) == 0 {
		return false
	}
	total_cost := 0
	#reverse for step in path {
		p := step.position
		if p == entity.pos {
			continue
		}
		total_cost += step.step_cost

		switch movemnt_kind {
		case .Step:
			if total_cost > 1 {
				return false
			}
		case .Stride:
			if total_cost > entity.movement_speed {
				return false
			}
		}

	}
	return true
}

draw_proposed_path :: proc(path: []Step, movemnt_kind: MovementKind, entity: ^Entity) {
	draw_cmds := ctx.draw_cmds
	draw_camera := &ctx.draw_cmds.camera

	total_cost := 0
	#reverse for step in path {
		p := step.position
		if p == entity.pos {
			continue
		}
		total_cost += step.step_cost

		color := Color{1, 0, 0, 0.5}
		switch movemnt_kind {
		case .Step:
			if total_cost > 1 {
				color.a = 0.2
			}
		case .Stride:
			if total_cost > entity.movement_speed {
				color.a = 0.2
			}
		}

		draw_cmds.draw_shape(Rectangle{world_pos_to_vec(p) * 16, Vector2{14, 14}, 0}, color)
	}
	if len(path) > 0 {
		total_cost := step_total_cost(path)

		screen_pos := draw_camera.screen_to_world_2d(g_mem.camera, input.mouse_position(g_input))
		draw_cmds.draw_text(
			fmt.ctprintf("%dft", total_cost * 5),
			cast(i32)screen_pos.x,
			cast(i32)screen_pos.y + 10,
			8,
			RED,
		)
	}
}
