package game

import "core:hash"
import "core:strings"

import "./input"

FancyTextDefaults :: FancyText{WHITE, .Left, 0}

FancyText :: struct {
	color:     Color,
	alignment: TextAlignment,
	spacing:   f32,
}

TextAlignment :: enum {
	Left,
	Middle,
	Right,
}

draw_text_fancy :: proc(
	font: Font,
	txt: cstring,
	pos: Vector2,
	size: f32,
	settings := FancyTextDefaults,
) {
	text_cmds := &ctx.draw_cmds.text

	switch settings.alignment {
	case .Left:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(
			font,
			txt,
			pos - Vector2{0, dims.y * 0.5},
			size,
			settings.spacing,
			settings.color,
		)
	case .Right:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(
			font,
			txt,
			pos - Vector2{dims.x, dims.y * 0.5},
			size,
			settings.spacing,
			settings.color,
		)
	case .Middle:
		dims := text_cmds.measure_text(g_mem.fonts.kenney_future, txt, size, settings.spacing)

		text_cmds.draw(font, txt, pos - dims * 0.5, size, settings.spacing, settings.color)
	}
}

get_frame_id :: proc(frame_input: input.FrameInput) -> int {
	return frame_input.current_frame.meta.frame_id
}

generate_u64_from_string :: proc(s: string) -> u64 {
	return hash.murmur64b(transmute([]u8)s)
}


generate_u64_from_cstring :: proc(cs: cstring) -> u64 {
	s := strings.clone_from_cstring(cs, context.temp_allocator)
	return hash.murmur64b(transmute([]u8)s)
}
