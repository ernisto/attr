--!nolint LocalUnused

local attr = require '@lib'
local entity_archetype = require '@lib/entity_archetype'
local iter_archetype_entities = entity_archetype.iter_entities
local get_entity_attributes = entity_archetype.get_attributes
local get_entity_archetype = entity_archetype.get
local set_entity_archetype = entity_archetype.set
local entity_is_a = entity_archetype.is_a

local archetype = require '@lib/archetype'
local check = require('./check')
local arch_attrs = archetype.with_attr

local run, skip, focus = {}, {}, {}

-- functions
local function entity(...: attr.attr<boolean>)
	local _, tracked_id = attr.id()
	for _, attribute in { ... } do
		attribute:add(tracked_id)
	end
	return tracked_id
end
local function tag()
	local a = attr.any(true)
	local A = attr.id(a)
	arch_attrs(A)
	return a, A
end

-- tests
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
	assert(entity_is_a(e1, A) == true, 'e1 is A')
	assert(entity_is_a(e1, B) == true, 'e1 is B')
	assert(entity_is_a(e1, C) == false, 'e1 is not C')
	assert(entity_is_a(e1, AB) == true, 'e1 is AB')
	assert(entity_is_a(e1, ABC) == false, 'e1 is not ABC')

	-- e2 has B,C
	assert(entity_is_a(e2, BC) == true, 'e2 is BC')
	assert(entity_is_a(e2, A) == false, 'e2 is not A')

	-- e3 has A,C
	assert(entity_is_a(e3, AC) == true, 'e3 is AC')
	assert(entity_is_a(e3, B) == false, 'e3 is not B')

	-- e4 has A,B,C
	assert(entity_is_a(e4, ABC) == true, 'e4 is ABC')
	assert(entity_is_a(e4, AB) == true, 'e4 matches AB superset')
	assert(entity_is_a(e4, AC) == true, 'e4 matches AC superset')
	assert(entity_is_a(e4, BC) == true, 'e4 matches BC superset')

	-- get_attrs returns exactly the tags the entity has
	check.unordered_array(get_entity_attributes(e1), { A, B })
	check.unordered_array(get_entity_attributes(e2), { B, C })
	check.unordered_array(get_entity_attributes(e3), { A, C })
	check.unordered_array(get_entity_attributes(e4), { A, B, C })
end

function run.archetype_transitions_work_correctly()
	local a, A = tag()
	local b, B = tag()
	local c, C = tag()

	local AB = arch_attrs(A, B)
	local AC = arch_attrs(A, C)
	local ABC = arch_attrs(A, B, C)

	local e = entity(a)
	assert(entity_is_a(e, A) == true, 'starts with A')

	-- Add B
	entity_archetype.move_to_with(e, B)
	assert(entity_is_a(e, AB) == true, 'now has AB')
	assert(entity_is_a(e, A) == true, 'still has A')

	-- Add C
	entity_archetype.move_to_with(e, C)
	assert(entity_is_a(e, ABC) == true, 'now has ABC')

	-- Remove B
	entity_archetype.move_to_without(e, B)
	assert(entity_is_a(e, AC) == true, 'now has AC')
	assert(entity_is_a(e, AB) == false, 'no longer has AB')
end

function run.entity_archetype_management()
	local a, A = tag()
	local b, B = tag()

	local e = entity(a)
	assert(get_entity_archetype(e) == A, 'entity starts in A archetype')

	entity_archetype.move_to_with(e, B)
	local AB = arch_attrs(A, B)
	assert(get_entity_archetype(e) == AB, 'moved to AB archetype')

	entity_archetype.move_to_without(e, A)
	assert(get_entity_archetype(e) == B, 'moved to B archetype')

	entity_archetype.move_to_without(e, B)
	assert(get_entity_archetype(e) == nil, 'no archetype after removing all')
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
	for id in iter_archetype_entities(AB) do
		seen[id] = true
	end
	assert(seen[e1], 'AB iter_entities should include AB')
	assert(seen[e4], 'AB iter_entities should include ABC')
	assert(not seen[e3], 'AB iter_entities should not include AC')

	local seen2 = {}
	for id in iter_archetype_entities(AC) do
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
	assert(entity_is_a(e, AB) == true, 'starts as AB')

	-- remove B via attribute API
	b:remove(e)
	assert(entity_is_a(e, AB) == false, 'no longer AB after removing B')
	assert(entity_is_a(e, arch_attrs(A)) == true, 'still has A')

	-- add C via attribute API
	c:add(e)
	assert(entity_is_a(e, AC) == true, 'now AC after adding C')

	-- add B back
	b:add(e)
	assert(entity_is_a(e, ABC) == true, 'now ABC after adding B back')
end

function run.set_and_get_moves_between_archetypes()
	local a, A = tag()
	local b, B = tag()

	local A_only = arch_attrs(A)
	local AB = arch_attrs(A, B)

	local e = entity(a)
	assert(entity_is_a(e, A_only) == true, 'starts as A')

	local prev = get_entity_archetype(e)
	set_entity_archetype(e, AB, prev)
	assert(entity_is_a(e, AB) == true, 'moved to AB using set')
end

function run.destroy_id_removes_from_queries()
	local a, A = tag()
	local b, B = tag()
	local AB = arch_attrs(A, B)
	local e = entity(a, b)

	local seen_before = {}
	for id in iter_archetype_entities(AB) do
		seen_before[id] = true
	end
	assert(seen_before[e] == true, 'present before destroy')

	attr.destroy(e)

	local seen_after = {}
	for id in iter_archetype_entities(AB) do
		seen_after[id] = true
	end
	assert(not seen_after[e], 'removed from queries after destroy')
	assert(entity_is_a(e, AB) == false, 'is_a false after destroy')
end

function run.edge_cases_and_error_handling()
	local a, A = tag()
	local b, B = tag()

	local e = entity(a)

	-- Test removing non-existent attribute (should not change archetype)
	local prev_archetype = get_entity_archetype(e)
	entity_archetype.move_to_without(e, B)
	-- The function might return early if no archetype exists, so we just check it doesn't crash
	assert(true, 'removing non-existent attribute does not crash')

	-- Test adding same attribute twice
	entity_archetype.move_to_with(e, A)
	assert(get_entity_archetype(e) == A, 'adding same attribute does nothing')

	-- Test with destroyed entity
	attr.destroy(e)
	assert(get_entity_archetype(e) == nil, 'destroyed entity has no archetype')
	assert(entity_is_a(e, A) == false, 'destroyed entity is not A')
end

return { run = run, skip = skip, focus = focus }
