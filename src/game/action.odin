package game

import "core:fmt"

import "./input"

OtherCost :: enum {
	None          = 0,
	FreeAction    = 1,
	// This consumers the reaction of the acting character
	ReactionSelf  = 2,
	// This consumes the reaction of another Character
	ReactionOther = 3,
}

CharacterAction :: struct {
	name:            cstring,
	name_short:      cstring,
	cost:            int,
	additional_cost: OtherCost,
	type:            ActionType,
	traits:          bit_set[ActionTraits],
}

ActionTraits :: enum {
	Move,
	Attack,
	Manipulate,
	Concentrate,
	Exploration,
	Visual,
	Auditory,
	Mental,
	Emotion,
	Feat,
	Linguistic,
	Secret,
}

ActionType :: enum {
	// Combat
	Strike,
	Feint,
	Escape,
	// Combat - Free Hand
	Grapple,
	Shove,
	Trip,
	Disarm,
	// Magical
	CastSpell,
	Dismiss,
	Substain,
	IdentifySpell,
	RecongizeSpell,
	// Defensive Actions
	AvertGaze,
	TakeCover,
	Parry,
	RaiseShield,
	ShieldBlock,
	// Conflict
	Delay,
	Ready,
	CreateDiversion,
	BonMot,
	Demoralize,
	// Clock & Dagger
	Seek,
	PointOut,
	Hide,
	Sneak,
	ConcealObject,
	PalmObject,
	Steal,
	Lie,
	SenseMove,
	// Movement
	Stride,
	Step,
	TumbleThrough,
	// Movement - Prone
	DropProne,
	Crawl,
	Stand,
	// Movement - Vertical
	Leap,
	HighJump,
	Swim,
	Climb,
	Balanace,
	// Movement - In Air
	GrabEdge,
	ArrestFall,
	ManeuverFlight,
	// Object
	Interfact,
	Release,
	Activate,
	DisableDevice,
	PickALock,
	ForceOpen,
	// Medicine
	FirstAid,
	BattleMedcine,
	TreatWound,
	TreatPoison,
	TreatDisease,
	// Other
	Aid,
	RecallKnowledge,
	Request,
	Perform,
	CommandAnimal,
	Mount,
}

UiActionBar :: struct {
	entity_handle:   EntityHandle,
	position:        Vector2,
	bar_size:        Vector2,
	x_start_pointer: f32,
	spell_large_b:   Font,
	action_atlas:    ImageHandle,
}

UiActionMeta :: struct {
	is_selected: bool,
}

get_action :: proc(type: ActionType) -> (action: CharacterAction) {
	#partial switch type {
	case .Strike:
		action.name = "Strike"
		action.name_short = "Strike"
		action.cost = 1
	case .Feint:
		action.name = "Feint"
		action.name_short = "Feint"
		action.cost = 1
	case .Escape:
		action.name = "Escape"
		action.name_short = "Escape"
		action.cost = 1
	case .RaiseShield:
		action.name = "Raise Shield"
		action.name_short = "Raise Shld"
		action.additional_cost = .ReactionSelf
	case .Release:
		action.name = "Release"
		action.name_short = "Release"
		action.additional_cost = .FreeAction
	case .Stride:
		action.name = "Stride"
		action.name_short = "Stride"
		action.cost = 1
	case .Step:
		action.name = "Step"
		action.name_short = "Step"
		action.cost = 1
	case .Aid:
		action.name = "Aid"
		action.name_short = "Aid"
		action.cost = 3
		action.additional_cost = .ReactionOther


	case:
		panic(fmt.tprintf("Unimplemented Case %v", type))
	}
	action.type = type
	return
}

ui_action_bar_draw_card_cost :: proc(
	ui: ^UiActionBar,
	action: CharacterAction,
	start, size: Vector2,
) {
	center := Vector2{start.x + size.x * 0.5, start.y}

	cost_height: f32 = 32

	draw_cmds := &ctx.draw_cmds
	draw_cmds.draw_shape(Rectangle{center, Vector2{size.x, cost_height + 8}, 0}, DriftWood)

	cost_atlas := AtlasImage{}
	cost_atlas.image = ui.action_atlas
	cost_atlas.pos = center
	switch action.cost {
	case 1:
		cost_atlas.src.size = Vector2{1, 1} * 16
		cost_atlas.src.pos = Vector2{1, 0} * 16
		cost_atlas.origin = Vector2{1, 1} * cost_height * 0.5
		cost_atlas.size = Vector2{1, 1} * cost_height
	case 2:
		cost_atlas.src.size = Vector2{2, 1} * 16
		cost_atlas.src.pos = Vector2{4, 0} * 16
		cost_atlas.origin = Vector2{1.2, 1} * cost_height * 0.5
		cost_atlas.size = Vector2{2, 1} * cost_height
	case 3:
		cost_atlas.src.size = Vector2{2, 1} * 16
		cost_atlas.src.pos = Vector2{6, 0} * 16
		cost_atlas.origin = Vector2{1.5, 1} * cost_height * 0.5
		cost_atlas.size = Vector2{2, 1} * cost_height
	}

	if action.cost > 0 {
		if action.additional_cost != .None {
			cost_atlas.pos -= Vector2{1, 0} * 24

			atlas := AtlasImage{}
			atlas.image = ui.action_atlas
			atlas.pos = center + Vector2{1, 0} * 24
			atlas.src.size = Vector2{1, 1} * 16
			atlas.origin = Vector2{1, 1} * cost_height * 0.5
			atlas.size = Vector2{1, 1} * cost_height
			color := JudgeGrey

			#partial switch action.additional_cost {
			case .ReactionOther:
				color = Ferra
				atlas.src.pos = Vector2{3, 0} * 16
			case .ReactionSelf:
				atlas.src.pos = Vector2{3, 0} * 16
			case .FreeAction:
				atlas.src.pos = Vector2{2, 0} * 16
			}

			draw_cmds.draw_img(atlas, color)
		}

		draw_cmds.draw_img(cost_atlas, JudgeGrey)
	} else {
		atlas := AtlasImage{}
		atlas.image = ui.action_atlas
		atlas.pos = center
		atlas.src.size = Vector2{1, 1} * 16
		atlas.origin = Vector2{1, 1} * cost_height * 0.5
		atlas.size = Vector2{1, 1} * cost_height
		color := JudgeGrey

		#partial switch action.additional_cost {
		case .ReactionOther:
			color = Ferra
			atlas.src.pos = Vector2{3, 0} * 16
		case .ReactionSelf:
			atlas.src.pos = Vector2{3, 0} * 16
		case .FreeAction:
			atlas.src.pos = Vector2{2, 0} * 16
		}
		draw_cmds.draw_img(atlas, color)
	}
}

ui_action_bar_draw_card :: proc(ui: ^UiActionBar, action: CharacterAction, meta: UiActionMeta) {
	// TODO: Auto Resize this if the text is too big to fit
	font_size: f32 = 24
	font := ui.spell_large_b
	draw_cmds := &ctx.draw_cmds

	id := get_action_id(action)

	pos :=
		ui.position - Vector2{ui.bar_size.x * 0.5 - 75 * 0.5, 0} + Vector2{ui.x_start_pointer, 0}
	if meta.is_selected {
		pos += Vector2{0, -8}
	}
	size := Vector2{100, 100}
	line_padding := Vector2{8, 0}

	text_dims := draw_cmds.text.measure_text(font, action.name_short, font_size, 0)
	size_diff: f32 = 0
	if text_dims.x > size.x {
		size_diff = text_dims.x - size.x
		size.x = text_dims.x + 8
		pos.x += size_diff * 0.5
	}
	text_start := pos - Vector2{0, size.y * 0.5} + Vector2{0, 16}

	line_start := text_start + Vector2{-size.x * 0.5, 24} + line_padding
	line_end := line_start + Vector2{size.x, 0} - line_padding * 2

	draw_cmds.draw_shape(Rectangle{pos + Vector2{6, 6}, size, 0.0}, BrownRust)
	draw_cmds.draw_shape(Rectangle{pos, size, 0.0}, Fawn)

	txt_settings := FancyTextDefaults
	txt_settings.color = JudgeGrey
	txt_settings.alignment = .Middle
	draw_text_fancy(font, action.name_short, text_start, font_size, txt_settings)
	draw_cmds.draw_shape(Line{line_start, line_end, 4}, JudgeGrey)

	ui_action_bar_draw_card_cost(ui, action, pos + Vector2{-size.x * 0.5, 24}, size.x)
	ui.x_start_pointer += size.x + 16
}

ui_action_bar_reset :: proc(ui: ^UiActionBar) {
	ui.x_start_pointer = 32
}

ui_action_bar_begin_draw :: proc(ui: ^UiActionBar, handle: EntityHandle) {
	width, height := input.frame_query_dimensions(g_input)
	ui.position = Vector2{width / 2, height - ui.bar_size.y * 0.5 - 8}
	ui.entity_handle = handle

	ctx.draw_cmds.draw_shape(Rectangle{ui.position, ui.bar_size + Vector2{8, 8}, 0}, JudgeGrey)
	ctx.draw_cmds.draw_shape(Rectangle{ui.position, ui.bar_size, 0}, Ferra)
}

ui_action_bar_draw_cost :: proc(ui: ^UiActionBar, actions_left: int) {
	entity := data_pool_get_ptr(&g_mem.entities, ui.entity_handle)
	assert(entity != nil, "Programmer Error: This should never been nil")

	size := Vector2{16 * 10, 48}
	pos := ui.position + Vector2{ui.bar_size.x * 0.5, -ui.bar_size.y * 0.5} - Vector2{64, 0}

	ctx.draw_cmds.draw_shape(Rectangle{pos + Vector2{1, 1}, size + Vector2{8, 8}, 0.0}, JudgeGrey)
	ctx.draw_cmds.draw_shape(Rectangle{pos, size, 0.0}, Ferra)


	padding := Vector2{16, 0}

	start_pos := pos - Vector2{1, 0} * size.x * 0.5 + Vector2{32, 0}

	available_action_pos := Vector2{2, 1} * 16
	used_action_pos := Vector2{1, 1} * 16
	for i := 1; i <= 3; i += 1 {
		atlas := AtlasImage{}
		atlas.image = ui.action_atlas
		atlas.pos = start_pos
		atlas.src.pos = available_action_pos if i <= actions_left else used_action_pos
		atlas.src.size = Vector2{1, 1} * 16
		atlas.origin = Vector2{1, 1} * 40 * 0.5
		atlas.size = Vector2{1, 1} * 40
		color := JudgeGrey

		ctx.draw_cmds.draw_img(atlas, JudgeGrey)
		start_pos += padding + Vector2{32, 0}
	}
}
ui_action_bar_draw_turn_btn :: proc(ui: ^UiActionBar) {
	font_size: f32 = 32
	size := Vector2{120, 80}
	font := ui.spell_large_b
	pos :=
		ui.position + Vector2{ui.bar_size.x * 0.5, 0} - Vector2{size.x * 0.5, 0} + Vector2{-16, 16}


	ctx.draw_cmds.draw_shape(Rectangle{pos, size, 0}, JudgeGrey)
	ctx.draw_cmds.draw_shape(Rectangle{pos - Vector2{0, 4}, size - Vector2{4, 4}, 0}, Fawn)

	// text_dims := ctx.draw_cmds.text.measure_text(
	// 	font,
	// 	"Does that complete your turn?",
	// 	font_size,
	// 	0,
	// )

	txt_settings := FancyTextDefaults
	txt_settings.color = JudgeGrey
	txt_settings.alignment = .Middle
	draw_text_fancy(font, "Complete", pos - Vector2{0, font_size * 0.5}, font_size, txt_settings)
	draw_text_fancy(font, "Turn", pos + Vector2{0, font_size * 0.5}, font_size, txt_settings)
}

ui_action_bar_end_draw :: proc(ui: ^UiActionBar) {}

@(private = "file")
get_action_id :: proc(action: CharacterAction) -> u64 {
	return generate_u64_from_cstring(action.name)
}
