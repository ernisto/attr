--!nolint LocalUnused
local attr = require '@lib'

local archetype = require '@lib/archetype'
local next_archetype_with = archetype.next_archetype_with
local next_archetype_without = archetype.next_archetype_without
local arch_attrs = archetype.with_attr

local check = require './check'
local assert_unordered_array = check.unordered_array

local run, focus, skip = {}, {}, {}

-- functions
local function tag()
	local a = attr.any(true)
	local A = attr.id(a)
	archetype.with_attr(A)
	return a, A
end

local function collect_iter(iter)
	local result = {}
	for item in iter do
		table.insert(result, item)
	end
	return result
end
local function all_smaller_archetypes(arch: number)
	return collect_iter(archetype.iter_smaller_archetypes(arch))
end
local function all_bigger_archetypes(arch: number)
	return collect_iter(archetype.iter_bigger_archetypes(arch))
end

-- tests
function run.iter_smaller_archetypes_includes_subsets()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	assert_unordered_array(all_smaller_archetypes(ABC), { A, B, C, AB, AC, ABC })
end

function run.iter_smaller_archetypes_includes_subsets_without_transition()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local ABC = arch_attrs(A, B, C)

	assert_unordered_array(all_smaller_archetypes(ABC), { A, B, C, AB, ABC })
end

function run.iter_bigger_archetypes_includes_supersets()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	assert_unordered_array(all_bigger_archetypes(AB), { AB, ABC })
end

function run.iter_bigger_archetypes_includes_subsets_without_transition()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local ABC = arch_attrs(A, B, C)

	assert_unordered_array(all_bigger_archetypes(C), { C, ABC })
end

function run.iter_smaller_archetypes_doesnt_visit_twice()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = next_archetype_with(A, B)
	local BC = next_archetype_with(B, C)
	local ABC = next_archetype_with(AB, C)

	local visited = {}
	for archetype_id in all_smaller_archetypes(ABC) do
		assert(not visited[archetype_id], `iter_smaller_archetypes visited archetype {archetype_id} twice`)
		visited[archetype_id] = true
	end
end

function run.iter_bigger_archetypes_doesnt_visit_twice()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = next_archetype_with(A, B)
	local AC = next_archetype_with(A, C)
	local ABC = next_archetype_with(AB, C)

	local visited = {}
	for archetype_id in all_bigger_archetypes(A) do
		assert(not visited[archetype_id], `visited archetype {archetype_id} twice`)
		visited[archetype_id] = true
	end
end

-- must to identify all these (archetype)
--  a  ┐
--     ├  ab  ┐
--  b  ┘      └  abc  ┐
--                    ├ (abcD)
--  c           (bcD) ┘
--
-- (D)
function run.bigger_archetypes_edge_cases_with_remotion()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()
	local d, D = tag()

	local AB = next_archetype_with(A, B)
	local ABC = next_archetype_with(AB, C)
	local ABCD = next_archetype_with(ABC, D)
	local BCD = next_archetype_without(ABCD, A)

	assert_unordered_array(all_bigger_archetypes(D), { D, ABCD, BCD })
end
function run.smaller_archetype_edge_cases_with_remotion()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()
	local d, D = tag()

	local AB = next_archetype_with(A, B)
	local ABC = next_archetype_with(AB, C)
	local ABCD = next_archetype_with(ABC, D)
	local BCD = next_archetype_without(ABCD, A)

	assert_unordered_array(all_smaller_archetypes(ABCD), { A, B, C, D, AB, ABC, BCD, ABCD })
end

return { run = run, skip = skip, focus = focus }
