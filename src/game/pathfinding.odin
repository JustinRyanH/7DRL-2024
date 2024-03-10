package game

import pq "core:container/priority_queue"
import math "core:math/linalg"

WorldPosition :: distinct [2]int

SearchNode :: struct {
	pos:        WorldPosition,
	g:          f32,
	h:          f32,
	connection: Connection,
}

Connection :: union {
	WorldPosition,
}

find_path_t :: proc(s_pos: WorldPosition, t_pos: WorldPosition) -> []WorldPosition {
	to_search := make([dynamic]SearchNode, 0, 128, context.temp_allocator)
	processed := make(map[WorldPosition]SearchNode, 128, context.temp_allocator)

	start := SearchNode{}
	start.pos = s_pos
	start.h = math.length(world_pos_to_vec(s_pos - t_pos))
	append(&to_search, start)

	for len(to_search) > 0 {
		current := to_search[0]
		current_index: int

		for maybe, index in to_search {
			maybe_f := get_f(maybe)
			current_f := get_f(current)
			if (maybe_f < current_f || maybe_f == current_f && maybe.h < current.h) {
				current = maybe
				current_index = index
			}
		}

		unordered_remove(&to_search, current_index)
		processed[current.pos] = current

		if current.pos == t_pos {
			path := make([dynamic]WorldPosition, context.temp_allocator)
			append(&path, current.pos)

			count := 0
			next := current.connection
			for {
				pos, is_pos := next.(WorldPosition)
				if !is_pos {
					return path[:]
				}
				append(&path, pos)
				next = processed[pos].connection
			}

			panic("Found Path")
		}

		neighbors := get_neighbors(current, t_pos)
		for n in neighbors {
			if n.pos in processed {
				continue
			}
			found_index := -1
			for t, index in to_search {
				if t.pos == n.pos {
					found_index = index
				}
			}
			if found_index >= 0 {
				existing := to_search[found_index]
				if n.g < existing.g {
					to_search[found_index] = n
				}
			} else {
				append(&to_search, n)
			}
		}
	}

	return []WorldPosition{}
}

get_f :: proc(n: SearchNode) -> f32 {
	return n.h + n.g
}

get_neighbors :: proc(search_node: SearchNode, target: WorldPosition) -> [4]SearchNode {
	offsets := [4]WorldPosition{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	nodes := [4]SearchNode{}

	for node, i in &nodes {
		node.pos = search_node.pos + offsets[i]
		node.g = search_node.g + 1
		node.h = math.length(world_pos_to_vec(node.pos - target))
		node.connection = search_node.pos
	}
	return nodes
}
