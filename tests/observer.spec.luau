--!nolint LocalUnused

local archetype = require '@lib/archetype'
local attr = require '@lib'

local run = {}

function run.on_add()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)

	local call = {}
	local disconnect = attr.on_add(A, function(entity)
		table.insert(call, entity)
	end)

	-- observers are called when a component is added
	local _, id = attr.id()
	a:add(id)
	assert(call[1] == id)

	-- observers watches archetypes
	local _, id2 = attr.id()
	b:add(id2)
	assert(call[2] == nil)
	a:add(id2)
	assert(call[2] == id2)

	-- observers can be disconnected
	disconnect()

	local _, id3 = attr.id()
	a:add(id3)
	assert(call[3] == nil)
end

function run.on_remove()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local remove_calls = {}
	local disconnect = attr.on_remove(A, function(entity)
		table.insert(remove_calls, entity)
	end)

	-- Set up entities with both components
	local _, id1 = attr.id()
	a:add(id1) -- This sets the value to 0 (default)
	b:add(id1)

	local _, id2 = attr.id()
	a:add(id2) -- This sets the value to 0 (default)
	b:add(id2)

	-- Remove component A from first entity
	a:remove(id1) -- This should trigger remove observer
	assert(#remove_calls == 1, 'Expected 1 remove call, got ' .. #remove_calls)
	assert(remove_calls[1] == id1)

	-- Remove component A from second entity
	a:remove(id2) -- This should trigger remove observer
	assert(#remove_calls == 2, 'Expected 2 remove calls, got ' .. #remove_calls)
	assert(remove_calls[2] == id2)

	-- Remove component B should not trigger A observer
	b:remove(id1)
	assert(#remove_calls == 2, 'Expected 2 remove calls after B removal, got ' .. #remove_calls)

	-- Disconnect observer
	disconnect()

	-- Remove A from remaining entity should not trigger
	a:remove(id2)
	assert(#remove_calls == 2, 'Expected 2 remove calls after disconnection, got ' .. #remove_calls)
end

function run.on_change()
	local a = attr.any(0)
	local A = attr.id(a)

	local change_calls = {}
	local disconnect = attr.on_change(A, function(entity)
		table.insert(change_calls, entity)
	end)

	-- Set up entity with component
	local _, id = attr.id()
	a:add(id)

	-- Change component value should trigger observer
	a:set(id, 5)
	assert(change_calls[1] == id)

	-- Another change should trigger again
	a:set(id, 10)
	assert(change_calls[2] == id)

	-- Disconnect observer
	disconnect()

	-- Change should not trigger after disconnection
	a:set(id, 15)
	assert(change_calls[3] == nil)
end

function run.multiple_observers()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local add_calls = {}
	local remove_calls = {}
	local change_calls = {}

	-- Set up multiple observers
	local disconnect1 = attr.on_add(A, function(entity)
		table.insert(add_calls, { observer = 1, entity = entity })
	end)

	local disconnect2 = attr.on_add(A, function(entity)
		table.insert(add_calls, { observer = 2, entity = entity })
	end)

	local disconnect3 = attr.on_remove(A, function(entity)
		table.insert(remove_calls, { observer = 3, entity = entity })
	end)

	local disconnect4 = attr.on_change(A, function(entity)
		table.insert(change_calls, { observer = 4, entity = entity })
	end)

	-- Test multiple observers on add
	local _, id = attr.id()
	a:add(id)
	assert(#add_calls == 2)
	assert(add_calls[1].observer == 1)
	assert(add_calls[2].observer == 2)

	-- Test change observer
	a:set(id, 5)
	assert(#change_calls == 1)
	assert(change_calls[1].observer == 4)

	-- Test remove observer
	a:remove(id)
	assert(#remove_calls == 1)
	assert(remove_calls[1].observer == 3)

	-- Clean up
	disconnect1()
	disconnect2()
	disconnect3()
	disconnect4()
end

function run.archetype_transitions()
	local a = attr.any(0)
	local b = attr.any(0)
	local c = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)
	local C = attr.id(c)

	local add_calls = {}
	local remove_calls = {}

	-- Observer for A component
	local disconnect_a = attr.on_add(A, function(entity)
		table.insert(add_calls, { component = 'A', entity = entity })
	end)

	-- Observer for B component
	local disconnect_b = attr.on_add(B, function(entity)
		table.insert(add_calls, { component = 'B', entity = entity })
	end)

	-- Observer for A removal
	local disconnect_remove_a = attr.on_remove(A, function(entity)
		table.insert(remove_calls, { component = 'A', entity = entity })
	end)

	local _, id = attr.id()

	-- Add A component
	a:add(id)
	assert(#add_calls == 1)
	assert(add_calls[1].component == 'A')

	-- Add B component (entity now has A+B archetype)
	b:add(id)
	assert(#add_calls == 2)
	assert(add_calls[2].component == 'B')

	-- Add C component (entity now has A+B+C archetype)
	c:add(id)
	assert(#add_calls == 2) -- No observer for C

	-- Remove A component (entity transitions to B+C archetype)
	a:remove(id)
	assert(#remove_calls == 1, 'Expected 1 remove call after A removal, got ' .. #remove_calls)
	assert(remove_calls[1].component == 'A')

	-- Remove B component (entity transitions to C archetype)
	b:remove(id)
	assert(#remove_calls == 1, 'Expected 1 remove call after B removal, got ' .. #remove_calls) -- No observer for B removal

	-- Clean up
	disconnect_a()
	disconnect_b()
	disconnect_remove_a()
end

function run.observer_disconnection()
	local a = attr.any(0)
	local A = attr.id(a)

	local calls = {}
	local disconnect = attr.on_add(A, function(entity)
		table.insert(calls, entity)
	end)

	-- Add component before disconnection
	local _, id1 = attr.id()
	a:add(id1)
	assert(#calls == 1)
	assert(calls[1] == id1)

	-- Disconnect observer
	disconnect()

	-- Add component after disconnection should not trigger
	local _, id2 = attr.id()
	a:add(id2)
	assert(#calls == 1) -- Should still be 1, not 2
end

function run.observer_with_different_archetypes()
	local a = attr.any(0)
	local b = attr.any(0)
	local c = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)
	local C = attr.id(c)

	local calls = {}

	-- Observer for A archetype
	local disconnect_a = attr.on_add(A, function(entity)
		table.insert(calls, { type = 'A', entity = entity })
	end)

	-- Observer for B archetype
	local disconnect_b = attr.on_add(B, function(entity)
		table.insert(calls, { type = 'B', entity = entity })
	end)

	-- Observer for C archetype
	local disconnect_c = attr.on_add(C, function(entity)
		table.insert(calls, { type = 'C', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()

	-- Add only A component
	a:add(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A')

	-- Add only B component
	b:add(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'B')

	-- Add only C component
	c:add(id3)
	assert(#calls == 3)
	assert(calls[3].type == 'C')

	-- Add A+B to same entity
	local id4 = attr.id()
	a:add(id4)
	b:add(id4)
	assert(#calls == 5) -- Should trigger both A and B observers
	assert(calls[4].type == 'A')
	assert(calls[5].type == 'B')

	-- Clean up
	disconnect_a()
	disconnect_b()
	disconnect_c()
end

function run.observer_with_archetype_hierarchy()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local calls = {}

	-- Observer for A archetype (should catch entities with A or A+B)
	local disconnect_a = attr.on_add(A, function(entity)
		table.insert(calls, { type = 'A', entity = entity })
	end)

	-- Observer for B archetype (should catch entities with B or A+B)
	local disconnect_b = attr.on_add(B, function(entity)
		table.insert(calls, { type = 'B', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()

	-- Add A only
	a:add(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A')

	-- Add B only
	b:add(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'B')

	-- Add A+B (should trigger both observers)
	a:add(id3)
	b:add(id3)
	assert(#calls == 4) -- A observer + B observer
	assert(calls[3].type == 'A')
	assert(calls[4].type == 'B')

	-- Clean up
	disconnect_a()
	disconnect_b()
end

function run.observer_with_composite_archetype()
	local a = attr.any(0)
	local b = attr.any(0)
	local c = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)
	local C = attr.id(c)

	local calls = {}

	-- Observer for A+B archetype (should only catch entities with both A and B)
	local AB_archetype = archetype.with_attr(A, B)
	local disconnect_ab = attr.on_add(AB_archetype, function(entity)
		table.insert(calls, { type = 'A+B', entity = entity })
	end)

	-- Observer for A+C archetype (should only catch entities with both A and C)
	local AC_archetype = archetype.with_attr(A, C)
	local disconnect_ac = attr.on_add(AC_archetype, function(entity)
		table.insert(calls, { type = 'A+C', entity = entity })
	end)

	-- Observer for B+C archetype (should only catch entities with both B and C)
	local BC_archetype = archetype.with_attr(B, C)
	local disconnect_bc = attr.on_add(BC_archetype, function(entity)
		table.insert(calls, { type = 'B+C', entity = entity })
	end)

	local _, id1 = attr.id()
	local _, id2 = attr.id()
	local _, id3 = attr.id()
	local _, id4 = attr.id()

	-- Add only A (should not trigger any composite observers)
	a:add(id1)
	assert(#calls == 0)

	-- Add only B (should not trigger any composite observers)
	b:add(id2)
	assert(#calls == 0)

	-- Add A+B (should trigger A+B observer)
	a:add(id2) -- id2 now has A+B
	assert(#calls == 1)
	assert(calls[1].type == 'A+B')
	assert(calls[1].entity == id2)

	-- Add A+C (should trigger A+C observer)
	a:add(id3)
	c:add(id3) -- id3 now has A+C
	assert(#calls == 2)
	assert(calls[2].type == 'A+C')
	assert(calls[2].entity == id3)

	-- Add B+C (should trigger B+C observer)
	b:add(id4)
	c:add(id4) -- id4 now has B+C
	assert(#calls == 3)
	assert(calls[3].type == 'B+C')
	assert(calls[3].entity == id4)

	assert(#calls == 3)

	-- Clean up
	disconnect_ab()
	disconnect_ac()
	disconnect_bc()
end

function run.observer_with_triple_composite_archetype()
	local a = attr.any(0)
	local b = attr.any(0)
	local c = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)
	local C = attr.id(c)

	local calls = {}

	-- Observer for A+B+C archetype (should only catch entities with all three)
	local ABC_archetype = archetype.with_attr(A, B, C)
	local disconnect_abc = attr.on_add(ABC_archetype, function(entity)
		table.insert(calls, { type = 'A+B+C', entity = entity })
	end)

	local _, id1 = attr.id()
	local _, id2 = attr.id()
	local _, id3 = attr.id()

	-- Add A only (should not trigger)
	a:add(id1)
	assert(#calls == 0)

	-- Add A+B (should not trigger)
	b:add(id1)
	assert(#calls == 0)

	-- Add A+B+C (should trigger)
	c:add(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A+B+C')
	assert(calls[1].entity == id1)

	-- Add A+B to another entity (should not trigger)
	a:add(id2)
	b:add(id2)
	assert(#calls == 1) -- Still only 1

	-- Add C to make it A+B+C (should trigger)
	c:add(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'A+B+C')
	assert(calls[2].entity == id2)

	-- Add A+B+C directly to third entity (should trigger)
	a:add(id3)
	b:add(id3)
	c:add(id3)
	assert(#calls == 3)
	assert(calls[3].type == 'A+B+C')
	assert(calls[3].entity == id3)

	-- Clean up
	disconnect_abc()
end

function run.observer_composite_archetype_removal()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local add_calls = {}
	local remove_calls = {}

	-- Observer for A+B archetype additions
	local AB_archetype = archetype.with_attr(A, B)
	local disconnect_add = attr.on_add(AB_archetype, function(entity)
		table.insert(add_calls, entity)
	end)

	-- Observer for A+B archetype removals
	local disconnect_remove = attr.on_remove(AB_archetype, function(entity)
		table.insert(remove_calls, entity)
	end)

	local _, id = attr.id()

	-- Add A only (should not trigger)
	a:add(id)
	assert(#add_calls == 0)

	-- Add B to make A+B (should trigger add)
	b:add(id)
	assert(#add_calls == 1)
	assert(add_calls[1] == id)

	-- Remove A (should trigger remove since entity no longer has A+B)
	a:remove(id)
	assert(#remove_calls == 1)
	assert(remove_calls[1] == id)

	-- Add A back to make A+B again (should trigger add)
	a:add(id)
	assert(#add_calls == 2)
	assert(add_calls[2] == id)

	-- Remove B (should trigger remove since entity no longer has A+B)
	b:remove(id)
	assert(#remove_calls == 2)
	assert(remove_calls[2] == id)

	-- Clean up
	disconnect_add()
	disconnect_remove()
end

function run.observer_composite_archetype_change()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local change_calls = {}

	-- Observer for A+B archetype changes
	local AB_archetype = archetype.with_attr(A, B)
	local disconnect_change = attr.on_change(AB_archetype, function(entity)
		table.insert(change_calls, entity)
	end)

	local _, id = attr.id()

	-- Add A+B (should not trigger change on add)
	a:add(id)
	b:add(id)
	assert(#change_calls == 0)

	-- Change A value (should trigger change)
	a:set(id, 5)
	assert(#change_calls == 1)
	assert(change_calls[1] == id)

	-- Change B value (should trigger change)
	b:set(id, 10)
	assert(#change_calls == 2)
	assert(change_calls[2] == id)

	-- Change A value again (should trigger change)
	a:set(id, 15)
	assert(#change_calls == 3)
	assert(change_calls[3] == id)

	-- Clean up
	disconnect_change()
end

return run
