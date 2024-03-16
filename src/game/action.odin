package game

import "core:fmt"

import "./input"

CombinedCostOperator :: enum {
	None = 0,
	And,
	Or,
}

OtherCost :: enum {
	FreeAction    = 0,
	// This consumers the reaction of the acting character
	ReactionSelf  = 1,
	// This consumes the reaction of another Character
	ReactionOther = 2,
}

CharacterAction :: struct {
	name:             cstring,
	name_short:       cstring,
	cost:             int,
	additional_cost:  bit_set[OtherCost],
	combine_operator: CombinedCostOperator,
	traits:           bit_set[ActionTraits],
}

ActionTraits :: enum {
	Move,
	Attack,
	Manipulate,
	Concentrate,
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
		action.additional_cost = {.ReactionSelf}
	case .Release:
		action.name = "Release"
		action.name_short = "Release"
		action.additional_cost = {.FreeAction}

	case:
		panic(fmt.tprintf("Unimplemented Case %v", type))
	}
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
		draw_cmds.draw_img(cost_atlas, JudgeGrey)
	} else {
		if .ReactionSelf in action.additional_cost {
			atlas := AtlasImage{}
			atlas.image = ui.action_atlas
			atlas.pos = center
			atlas.src.size = Vector2{1, 1} * 16
			atlas.src.pos = Vector2{3, 0} * 16
			atlas.origin = Vector2{1, 1} * cost_height * 0.5
			atlas.size = Vector2{1, 1} * cost_height
			draw_cmds.draw_img(atlas, JudgeGrey)
		}
		if .FreeAction in action.additional_cost {
			atlas := AtlasImage{}
			atlas.image = ui.action_atlas
			atlas.pos = center
			atlas.src.size = Vector2{1, 1} * 16
			atlas.src.pos = Vector2{2, 0} * 16
			atlas.origin = Vector2{1, 1} * cost_height * 0.5
			atlas.size = Vector2{1, 1} * cost_height
			draw_cmds.draw_img(atlas, JudgeGrey)

		}
	}
}

ui_action_bar_draw_card :: proc(ui: ^UiActionBar, action: CharacterAction) {
	// TODO: Auto Resize this if the text is too big to fit
	font_size: f32 = 24
	font := ui.spell_large_b
	draw_cmds := &ctx.draw_cmds


	pos :=
		ui.position - Vector2{ui.bar_size.x * 0.5 - 75 * 0.5, 0} + Vector2{ui.x_start_pointer, 0}
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

	// atlas_size := Vector2{16, 16} * 2

	// atlas := AtlasImage{}
	// atlas.image = ui.action_atlas
	// atlas.pos = pos + Vector2{0, 16}

	// switch k in action.type {
	// case ActionCost:
	// 	switch k {
	// 	case 1:
	// 		atlas.src.size = Vector2{16, 16}
	// 		atlas.src.pos = Vector2{16, 0}
	// 		atlas.origin = atlas_size * 0.5
	// 		atlas.size = atlas_size
	// 	case 2:
	// 		atlas.src.size = Vector2{32, 16}
	// 		atlas.src.pos = Vector2{64, 0}
	// 		atlas.origin = atlas_size * 0.5
	// 		atlas.size = Vector2{32, 16} * 2
	// 	case 3:
	// 		atlas.src.size = Vector2{32, 16}
	// 		atlas.src.pos = Vector2{64 + 32, 0}
	// 		atlas.origin = atlas_size * 0.5 + Vector2{8, 0}
	// 		atlas.size = Vector2{32, 16} * 2
	// 	case:
	// 		panic("Unhandle Action Cost")

	// 	}
	// case NonCostAction:
	// 	switch k {
	// 	case .Reaction:
	// 		atlas.src.size = Vector2{16, 16}
	// 		atlas.src.pos = Vector2{48, 0}
	// 		atlas.origin = atlas_size * 0.5
	// 		atlas.size = Vector2{16, 16} * 2
	// 	case .FreeAction:
	// 		atlas.src.size = Vector2{16, 16}
	// 		atlas.src.pos = Vector2{32, 0}
	// 		atlas.origin = atlas_size * 0.5
	// 		atlas.size = Vector2{16, 16} * 2
	// 	}

	// }


	// draw_cmds.draw_img(atlas, JudgeGrey)
	ui.x_start_pointer += size.x + 16
}

ui_action_bar_reset :: proc(ui: ^UiActionBar) {
	ui.x_start_pointer = 32
}

ui_action_bar_begin_draw :: proc(ui: ^UiActionBar) {
	width, height := input.frame_query_dimensions(g_input)
	ui.position = Vector2{width / 2, height - ui.bar_size.y * 0.5 - 8}


	ctx.draw_cmds.draw_shape(Rectangle{ui.position, ui.bar_size + Vector2{8, 8}, 0}, JudgeGrey)
	ctx.draw_cmds.draw_shape(Rectangle{ui.position, ui.bar_size, 0}, Ferra)
}

ui_action_bar_end_draw :: proc(ui: ^UiActionBar) {}
