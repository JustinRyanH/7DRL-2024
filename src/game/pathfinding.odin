package game

import pq "core:container/priority_queue"
import "core:fmt"
import math "core:math/linalg"

WorldPosition :: distinct [2]int

Step :: struct {
	position:  WorldPosition,
	step_cost: int,
}

SearchNode :: struct {
	pos:        WorldPosition,
	g:          f32,
	h:          f32,
	step_cost:  int,
	connection: Connection,
}

Connection :: union {
	WorldPosition,
}

SearchNodePQueue :: pq.Priority_Queue(SearchNode)

search_node_less :: proc(a, b: SearchNode) -> bool {
	a_f := get_f(a)
	b_f := get_f(b)
	return a_f < b_f || a_f == b_f && a.h < b.h
}

search_node_swap :: proc(q: []SearchNode, i, j: int) {
	q[i], q[j] = q[j], q[i]
}

find_path_t :: proc(s_pos: WorldPosition, t_pos: WorldPosition) -> []Step {
	to_search := SearchNodePQueue{}
	pq.init(&to_search, search_node_less, search_node_swap, 128, context.temp_allocator)
	processed := make(map[WorldPosition]SearchNode, 128, context.temp_allocator)

	start := SearchNode{}
	start.pos = s_pos
	start.h = math.length(world_pos_to_vec(s_pos - t_pos))

	pq.push(&to_search, start)

	for pq.len(to_search) > 0 {
		current := pq.pop(&to_search)
		if current.pos in processed {
			continue
		}

		processed[current.pos] = current

		if current.pos == t_pos {
			path := make([dynamic]Step, context.temp_allocator)
			append(&path, Step{current.pos, current.step_cost})

			count := 0
			next := current.connection
			for {
				pos, is_pos := next.(WorldPosition)
				if !is_pos {
					return path[:]
				}
				node := processed[pos]
				append(&path, Step{pos, node.step_cost})
				next = node.connection
			}

			panic("Bad Branch")
		}

		neighbors := get_neighbors(current, t_pos)
		for n in neighbors {
			if n.pos in processed {
				continue
			}
			pq.push(&to_search, n)
		}
	}

	return []Step{}
}

get_f :: proc(n: SearchNode) -> f32 {
	return n.h + n.g
}

get_neighbors :: proc(search_node: SearchNode, target: WorldPosition) -> [4]SearchNode {
	offsets := [4]WorldPosition{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
	nodes := [4]SearchNode{}

	for node, i in &nodes {
		node.pos = search_node.pos + offsets[i]
		node.g = search_node.g + 10
		node.h = math.length(world_pos_to_vec(node.pos - target)) * 10
		node.step_cost = 1
		node.connection = search_node.pos
	}
	return nodes
}

step_total_cost :: proc(steps: []Step) -> int {
	total: int = 0
	for step in steps {
		total += step.step_cost
	}
	return total
}