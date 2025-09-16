--!nolint LocalUnused

local archetype = require('@lib/archetype')
local attr = require('@lib')

local run, focus, skip = {}, {}, {}

local function tag()
	local a = attr.any(true)
	return a, attr.id(a)
end
local function entity(...: attr.attr<boolean>)
	local id = attr.id()
	for _, attribute in { ... } do
		attribute:ensure(id)
	end
	return id
end
local arch_attrs = archetype.with_attr

local function to_set(arr)
	local s = {}
	for _, v in arr do
		s[v] = true
	end
	return s
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
	assert(seen[e1] and seen[e4], 'AB iter_entities should include AB and ABC')
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

return { run = run, skip = skip, focus = focus }
