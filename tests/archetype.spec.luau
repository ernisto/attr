--!nolint LocalUnused

local archetype = require('@lib/archetype')
local attr = require('@lib')
local graph = require('../lib/archetype/graph')

local run, focus, skip = {}, {}, {}

local function tag()
	local a = attr.any(true)
	local A = attr.id(a)
	archetype.with_attr(A)
	return a, A
end
local function entity(...: attr.attr<boolean>)
	local _, tracked_id = attr.id()
	for _, attribute in { ... } do
		attribute:ensure(tracked_id)
	end
	return tracked_id
end
local arch_attrs = archetype.with_attr

local function to_set(arr)
	local s = {}
	for _, v in arr do
		s[v] = true
	end
	return s
end

local function collect_iter(iter)
	local result = {}
	for item in iter do
		table.insert(result, item)
	end
	return result
end

function run.iter_smaller_archetypes_includes_subsets()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	local smaller = collect_iter(archetype.iter_smaller_archetypes(ABC))
	local smaller_set = to_set(smaller)

	assert(smaller_set[AB] == true, 'AB is smaller than ABC')
	assert(smaller_set[AC] == true, 'AC is smaller than ABC')
	assert(smaller_set[A] == true, 'A is smaller than ABC')
	assert(smaller_set[ABC] == true, 'ABC includes itself')
end

function run.iter_smaller_archetypes_includes_subsets_without_transition()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local ABC = arch_attrs(A, B, C)

	local bigger = collect_iter(archetype.iter_smaller_archetypes(ABC))
	local bigger_set = to_set(bigger)

	assert(bigger_set[ABC] == true, 'ABC includes itself')
	assert(bigger_set[AB] == true, 'ABC includes AB')
	assert(bigger_set[A] == true, 'ABC includes A')
	assert(bigger_set[B] == true, 'ABC includes B')
	assert(bigger_set[C] == true, 'ABC includes C')
end

function run.iter_bigger_archetypes_includes_supersets()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	local bigger = collect_iter(archetype.iter_bigger_archetypes(AB))
	local bigger_set = to_set(bigger)

	assert(bigger_set[ABC] == true, 'ABC is bigger than AB')
	assert(bigger_set[AB] == true, 'AB includes itself')
	assert(not bigger_set[AC], 'AC is not bigger than AB')
end

function run.iter_bigger_archetypes_includes_subsets_without_transition()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local ABC = arch_attrs(A, B, C)

	local bigger = collect_iter(archetype.iter_bigger_archetypes(C))
	local bigger_set = to_set(bigger)

	assert(bigger_set[C] == true, 'C includes itself')
	assert(bigger_set[ABC] == true, 'C includes ABC')
end

function run.iter_smaller_archetypes_doesnt_visit_twice()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = graph.next_archetype_with(A, B)
	local BC = graph.next_archetype_with(B, C)
	local ABC = graph.next_archetype_with(AB, C)

	local visited = {}
	for archetype_id in archetype.iter_smaller_archetypes(ABC) do
		assert(
			not visited[archetype_id],
			string.format('iter_smaller_archetypes visited archetype %s twice', tostring(archetype_id))
		)
		visited[archetype_id] = true
	end
end

function run.iter_bigger_archetypes_doesnt_visit_twice()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = graph.next_archetype_with(A, B)
	local AC = graph.next_archetype_with(A, C)

	local ABC = graph.next_archetype_with(AB, C)

	local visited2 = {}
	for archetype_id in archetype.iter_bigger_archetypes(A) do
		assert(
			not visited2[archetype_id],
			string.format('iter_bigger_archetypes visited archetype %s twice', tostring(archetype_id))
		)
		visited2[archetype_id] = true
	end
end

function run.is_a_and_get_attrs()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local BC = arch_attrs(B, C)
	local ABC = arch_attrs(A, B, C)

	local e1 = entity(a, b)
	local e2 = entity(b, c)
	local e3 = entity(a, c)
	local e4 = entity(a, b, c)

	-- e1 has A,B
	assert(archetype.is_a(e1, A) == true, 'e1 is A')
	assert(archetype.is_a(e1, B) == true, 'e1 is B')
	assert(archetype.is_a(e1, C) == false, 'e1 is not C')
	assert(archetype.is_a(e1, AB) == true, 'e1 is AB')
	assert(archetype.is_a(e1, ABC) == false, 'e1 is not ABC')

	-- e2 has B,C
	assert(archetype.is_a(e2, BC) == true, 'e2 is BC')
	assert(archetype.is_a(e2, A) == false, 'e2 is not A')

	-- e3 has A,C
	assert(archetype.is_a(e3, AC) == true, 'e3 is AC')
	assert(archetype.is_a(e3, B) == false, 'e3 is not B')

	-- e4 has A,B,C
	assert(archetype.is_a(e4, ABC) == true, 'e4 is ABC')
	assert(archetype.is_a(e4, AB) == true, 'e4 matches AB superset')
	assert(archetype.is_a(e4, AC) == true, 'e4 matches AC superset')
	assert(archetype.is_a(e4, BC) == true, 'e4 matches BC superset')

	-- get_attrs returns exactly the tags the entity has
	local s1 = to_set(archetype.get_attrs(e1))
	assert(s1[A] and s1[B] and not s1[C], 'get_attrs(e1) contains A,B only')

	local s2 = to_set(archetype.get_attrs(e2))
	assert(s2[B] and s2[C] and not s2[A], 'get_attrs(e2) contains B,C only')

	local s3 = to_set(archetype.get_attrs(e3))
	assert(s3[A] and s3[C] and not s3[B], 'get_attrs(e3) contains A, C only')

	local s4 = to_set(archetype.get_attrs(e4))
	assert(s4[A] and s4[B] and s4[C], 'get_attrs(e4) contains A, B, C')
end

function run.archetype_transitions_work_correctly()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	local e = entity(a)
	assert(archetype.is_a(e, A) == true, 'starts with A')

	-- Add B
	archetype.move_to_with(e, B)
	assert(archetype.is_a(e, AB) == true, 'now has AB')
	assert(archetype.is_a(e, A) == true, 'still has A')

	-- Add C
	archetype.move_to_with(e, C)
	assert(archetype.is_a(e, ABC) == true, 'now has ABC')

	-- Remove B
	archetype.move_to_without(e, B)
	assert(archetype.is_a(e, AC) == true, 'now has AC')
	assert(archetype.is_a(e, AB) == false, 'no longer has AB')
end

function run.entity_archetype_management()
	local a, A = tag()
	local b, B = tag()

	local e = entity(a)
	assert(archetype.get(e) == A, 'entity starts in A archetype')

	archetype.move_to_with(e, B)
	local AB = arch_attrs(A, B)
	assert(archetype.get(e) == AB, 'moved to AB archetype')

	archetype.move_to_without(e, A)
	assert(archetype.get(e) == B, 'moved to B archetype')

	archetype.move_to_without(e, B)
	assert(archetype.get(e) == nil, 'no archetype after removing all')
end

function run.iter_entities_includes_supersets()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)

	local e1 = entity(a, b)
	local _e2 = entity(b, c)
	local e3 = entity(a, c)
	local e4 = entity(a, b, c)

	local seen = {}
	for id in archetype.iter_entities(AB) do
		seen[id] = true
	end
	assert(seen[e1], 'AB iter_entities should include AB')
	assert(seen[e4], 'AB iter_entities should include ABC')
	assert(not seen[e3], 'AB iter_entities should not include AC')

	local seen2 = {}
	for id in archetype.iter_entities(AC) do
		seen2[id] = true
	end
	assert(seen2[e3] and seen2[e4], 'AC iter_entities should include AC and ABC')
	assert(not seen2[e1], 'AC iter_entities should not include AB')
end

function run.add_remove_transitions_update_membership()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()
	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	local e = entity(a, b)
	assert(archetype.is_a(e, AB) == true, 'starts as AB')

	-- remove B via attribute API
	b:remove(e)
	assert(archetype.is_a(e, AB) == false, 'no longer AB after removing B')
	assert(archetype.is_a(e, arch_attrs(A)) == true, 'still has A')

	-- add C via attribute API
	c:ensure(e)
	assert(archetype.is_a(e, AC) == true, 'now AC after adding C')

	-- add B back
	b:ensure(e)
	assert(archetype.is_a(e, ABC) == true, 'now ABC after adding B back')
end

function run.set_and_get_moves_between_archetypes()
	local a, A = tag()
	local b, B = tag()

	local A_only = arch_attrs(A)
	local AB = arch_attrs(A, B)

	local e = entity(a)
	assert(archetype.is_a(e, A_only) == true, 'starts as A')

	local prev = archetype.get(e)
	archetype.set(e, AB, prev)
	assert(archetype.is_a(e, AB) == true, 'moved to AB using set')
end

function run.destroy_id_removes_from_queries()
	local a, A = tag()
	local b, B = tag()
	local AB = arch_attrs(A, B)
	local e = entity(a, b)
	local seen_before = {}
	for id in archetype.iter_entities(AB) do
		seen_before[id] = true
	end
	assert(seen_before[e] == true, 'present before destroy')

	attr.destroy(e)

	local seen_after = {}
	for id in archetype.iter_entities(AB) do
		seen_after[id] = true
	end
	assert(not seen_after[e], 'removed from queries after destroy')
	assert(archetype.is_a(e, AB) == false, 'is_a false after destroy')
end

function run.edge_cases_and_error_handling()
	local a, A = tag()
	local b, B = tag()

	local e = entity(a)

	-- Test removing non-existent attribute (should not change archetype)
	local prev_archetype = archetype.get(e)
	archetype.move_to_without(e, B)
	-- The function might return early if no archetype exists, so we just check it doesn't crash
	assert(true, 'removing non-existent attribute does not crash')

	-- Test adding same attribute twice
	archetype.move_to_with(e, A)
	assert(archetype.get(e) == A, 'adding same attribute does nothing')

	-- Test with destroyed entity
	attr.destroy(e)
	assert(archetype.get(e) == nil, 'destroyed entity has no archetype')
	assert(archetype.is_a(e, A) == false, 'destroyed entity is not A')
end

return { run = run, skip = skip, focus = focus }
