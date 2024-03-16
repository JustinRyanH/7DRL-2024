package game

import "./input"

NonCostAction :: enum {
	FreeAction = 0,
	Reaction   = 1,
}
ActionCost :: distinct int
ActionExpense :: union {
	ActionCost,
	NonCostAction,
}

CharacterAction :: struct {
	name:       cstring,
	name_short: cstring,
	type:       ActionExpense,
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

	atlas_size := Vector2{16, 16} * 2

	atlas := AtlasImage{}
	atlas.image = ui.action_atlas
	atlas.pos = pos + Vector2{0, 16}

	switch k in action.type {
	case ActionCost:
		switch k {
		case 1:
			atlas.src.size = Vector2{16, 16}
			atlas.src.pos = Vector2{16, 0}
			atlas.origin = atlas_size * 0.5
			atlas.size = atlas_size
		case 2:
			atlas.src.size = Vector2{32, 16}
			atlas.src.pos = Vector2{64, 0}
			atlas.origin = atlas_size * 0.5
			atlas.size = Vector2{32, 16} * 2
		case 3:
			atlas.src.size = Vector2{32, 16}
			atlas.src.pos = Vector2{64 + 32, 0}
			atlas.origin = atlas_size * 0.5 + Vector2{8, 0}
			atlas.size = Vector2{32, 16} * 2
		case:
			panic("Unhandle Action Cost")

		}
	case NonCostAction:
		switch k {
		case .Reaction:
			atlas.src.size = Vector2{16, 16}
			atlas.src.pos = Vector2{48, 0}
			atlas.origin = atlas_size * 0.5
			atlas.size = Vector2{16, 16} * 2
		case .FreeAction:
			atlas.src.size = Vector2{16, 16}
			atlas.src.pos = Vector2{32, 0}
			atlas.origin = atlas_size * 0.5
			atlas.size = Vector2{16, 16} * 2
		}

	}


	draw_cmds.draw_img(atlas, JudgeGrey)

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
