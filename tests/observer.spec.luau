--!nolint LocalUnused

local archetype = require('../lib/archetype')
local attr = require '../lib'

local run = {}

function run.on_add()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)

	local call = {}
	local conn = attr.on_add(A, function(entity)
		table.insert(call, entity)
	end)

	-- observers are called when a component is added
	local id = attr.id()
	a:ensure(id)
	assert(call[1] == id)

	-- observers watches archetypes
	local id2 = attr.id()
	b:ensure(id2)
	assert(call[2] == nil)
	a:ensure(id2)
	assert(call[2] == id2)

	-- observers can be disconnected
	attr.destroy(conn)

	local id3 = attr.id()
	a:ensure(id3)
	assert(call[3] == nil)
end

function run.on_remove()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local remove_calls = {}
	local conn = attr.on_remove(A, function(entity)
		table.insert(remove_calls, entity)
	end)

	-- Set up entities with both components
	local id1 = attr.id()
	a:ensure(id1) -- This sets the value to 0 (default)
	b:ensure(id1)

	local id2 = attr.id()
	a:ensure(id2) -- This sets the value to 0 (default)
	b:ensure(id2)

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
	attr.destroy(conn)

	-- Remove A from remaining entity should not trigger
	a:remove(id2)
	assert(#remove_calls == 2, 'Expected 2 remove calls after disconnection, got ' .. #remove_calls)
end

function run.on_change()
	local a = attr.any(0)
	local A = attr.id(a)

	local change_calls = {}
	local conn = attr.on_change(A, function(entity)
		table.insert(change_calls, entity)
	end)

	-- Set up entity with component
	local id = attr.id()
	a:ensure(id)

	-- Change component value should trigger observer
	a:set(id, 5)
	assert(change_calls[1] == id)

	-- Another change should trigger again
	a:set(id, 10)
	assert(change_calls[2] == id)

	-- Disconnect observer
	attr.destroy(conn)

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
	local conn1 = attr.on_add(A, function(entity)
		table.insert(add_calls, { observer = 1, entity = entity })
	end)

	local conn2 = attr.on_add(A, function(entity)
		table.insert(add_calls, { observer = 2, entity = entity })
	end)

	local conn3 = attr.on_remove(A, function(entity)
		table.insert(remove_calls, { observer = 3, entity = entity })
	end)

	local conn4 = attr.on_change(A, function(entity)
		table.insert(change_calls, { observer = 4, entity = entity })
	end)

	-- Test multiple observers on add
	local id = attr.id()
	a:ensure(id)
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
	attr.destroy(conn1)
	attr.destroy(conn2)
	attr.destroy(conn3)
	attr.destroy(conn4)
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
	local conn_a = attr.on_add(A, function(entity)
		table.insert(add_calls, { component = 'A', entity = entity })
	end)

	-- Observer for B component
	local conn_b = attr.on_add(B, function(entity)
		table.insert(add_calls, { component = 'B', entity = entity })
	end)

	-- Observer for A removal
	local conn_remove_a = attr.on_remove(A, function(entity)
		table.insert(remove_calls, { component = 'A', entity = entity })
	end)

	local id = attr.id()

	-- Add A component
	a:ensure(id)
	assert(#add_calls == 1)
	assert(add_calls[1].component == 'A')

	-- Add B component (entity now has A+B archetype)
	b:ensure(id)
	assert(#add_calls == 2)
	assert(add_calls[2].component == 'B')

	-- Add C component (entity now has A+B+C archetype)
	c:ensure(id)
	assert(#add_calls == 2) -- No observer for C

	-- Remove A component (entity transitions to B+C archetype)
	a:remove(id)
	assert(#remove_calls == 1, 'Expected 1 remove call after A removal, got ' .. #remove_calls)
	assert(remove_calls[1].component == 'A')

	-- Remove B component (entity transitions to C archetype)
	b:remove(id)
	assert(#remove_calls == 1, 'Expected 1 remove call after B removal, got ' .. #remove_calls) -- No observer for B removal

	-- Clean up
	attr.destroy(conn_a)
	attr.destroy(conn_b)
	attr.destroy(conn_remove_a)
end

function run.observer_disconnection()
	local a = attr.any(0)
	local A = attr.id(a)

	local calls = {}
	local conn = attr.on_add(A, function(entity)
		table.insert(calls, entity)
	end)

	-- Add component before disconnection
	local id1 = attr.id()
	a:ensure(id1)
	assert(#calls == 1)
	assert(calls[1] == id1)

	-- Disconnect observer
	attr.destroy(conn)

	-- Add component after disconnection should not trigger
	local id2 = attr.id()
	a:ensure(id2)
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
	local conn_a = attr.on_add(A, function(entity)
		table.insert(calls, { type = 'A', entity = entity })
	end)

	-- Observer for B archetype
	local conn_b = attr.on_add(B, function(entity)
		table.insert(calls, { type = 'B', entity = entity })
	end)

	-- Observer for C archetype
	local conn_c = attr.on_add(C, function(entity)
		table.insert(calls, { type = 'C', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()

	-- Add only A component
	a:ensure(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A')

	-- Add only B component
	b:ensure(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'B')

	-- Add only C component
	c:ensure(id3)
	assert(#calls == 3)
	assert(calls[3].type == 'C')

	-- Add A+B to same entity
	local id4 = attr.id()
	a:ensure(id4)
	b:ensure(id4)
	assert(#calls == 5) -- Should trigger both A and B observers
	assert(calls[4].type == 'A')
	assert(calls[5].type == 'B')

	-- Clean up
	attr.destroy(conn_a)
	attr.destroy(conn_b)
	attr.destroy(conn_c)
end

function run.observer_with_archetype_hierarchy()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local calls = {}

	-- Observer for A archetype (should catch entities with A or A+B)
	local conn_a = attr.on_add(A, function(entity)
		table.insert(calls, { type = 'A', entity = entity })
	end)

	-- Observer for B archetype (should catch entities with B or A+B)
	local conn_b = attr.on_add(B, function(entity)
		table.insert(calls, { type = 'B', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()

	-- Add A only
	a:ensure(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A')

	-- Add B only
	b:ensure(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'B')

	-- Add A+B (should trigger both observers)
	a:ensure(id3)
	b:ensure(id3)
	assert(#calls == 4) -- A observer + B observer
	assert(calls[3].type == 'A')
	assert(calls[4].type == 'B')

	-- Clean up
	attr.destroy(conn_a)
	attr.destroy(conn_b)
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
	local conn_ab = attr.on_add(AB_archetype, function(entity)
		table.insert(calls, { type = 'A+B', entity = entity })
	end)

	-- Observer for A+C archetype (should only catch entities with both A and C)
	local AC_archetype = archetype.with_attr(A, C)
	local conn_ac = attr.on_add(AC_archetype, function(entity)
		table.insert(calls, { type = 'A+C', entity = entity })
	end)

	-- Observer for B+C archetype (should only catch entities with both B and C)
	local BC_archetype = archetype.with_attr(B, C)
	local conn_bc = attr.on_add(BC_archetype, function(entity)
		table.insert(calls, { type = 'B+C', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()
	local id4 = attr.id()

	-- Add only A (should not trigger any composite observers)
	a:ensure(id1)
	assert(#calls == 0)

	-- Add only B (should not trigger any composite observers)
	b:ensure(id2)
	assert(#calls == 0)

	-- Add A+B (should trigger A+B observer)
	a:ensure(id2) -- id2 now has A+B
	assert(#calls == 1)
	assert(calls[1].type == 'A+B')
	assert(calls[1].entity == id2)

	-- Add A+C (should trigger A+C observer)
	a:ensure(id3)
	c:ensure(id3) -- id3 now has A+C
	assert(#calls == 2)
	assert(calls[2].type == 'A+C')
	assert(calls[2].entity == id3)

	-- Add B+C (should trigger B+C observer)
	b:ensure(id4)
	c:ensure(id4) -- id4 now has B+C
	assert(#calls == 3)
	assert(calls[3].type == 'B+C')
	assert(calls[3].entity == id4)

	assert(#calls == 3)

	-- Clean up
	attr.destroy(conn_ab)
	attr.destroy(conn_ac)
	attr.destroy(conn_bc)
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
	local conn_abc = attr.on_add(ABC_archetype, function(entity)
		table.insert(calls, { type = 'A+B+C', entity = entity })
	end)

	local id1 = attr.id()
	local id2 = attr.id()
	local id3 = attr.id()

	-- Add A only (should not trigger)
	a:ensure(id1)
	assert(#calls == 0)

	-- Add A+B (should not trigger)
	b:ensure(id1)
	assert(#calls == 0)

	-- Add A+B+C (should trigger)
	c:ensure(id1)
	assert(#calls == 1)
	assert(calls[1].type == 'A+B+C')
	assert(calls[1].entity == id1)

	-- Add A+B to another entity (should not trigger)
	a:ensure(id2)
	b:ensure(id2)
	assert(#calls == 1) -- Still only 1

	-- Add C to make it A+B+C (should trigger)
	c:ensure(id2)
	assert(#calls == 2)
	assert(calls[2].type == 'A+B+C')
	assert(calls[2].entity == id2)

	-- Add A+B+C directly to third entity (should trigger)
	a:ensure(id3)
	b:ensure(id3)
	c:ensure(id3)
	assert(#calls == 3)
	assert(calls[3].type == 'A+B+C')
	assert(calls[3].entity == id3)

	-- Clean up
	attr.destroy(conn_abc)
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
	local conn_add = attr.on_add(AB_archetype, function(entity)
		table.insert(add_calls, entity)
	end)

	-- Observer for A+B archetype removals
	local conn_remove = attr.on_remove(AB_archetype, function(entity)
		table.insert(remove_calls, entity)
	end)

	local id = attr.id()

	-- Add A only (should not trigger)
	a:ensure(id)
	assert(#add_calls == 0)

	-- Add B to make A+B (should trigger add)
	b:ensure(id)
	assert(#add_calls == 1)
	assert(add_calls[1] == id)

	-- Remove A (should trigger remove since entity no longer has A+B)
	a:remove(id)
	assert(#remove_calls == 1)
	assert(remove_calls[1] == id)

	-- Add A back to make A+B again (should trigger add)
	a:ensure(id)
	assert(#add_calls == 2)
	assert(add_calls[2] == id)

	-- Remove B (should trigger remove since entity no longer has A+B)
	b:remove(id)
	assert(#remove_calls == 2)
	assert(remove_calls[2] == id)

	-- Clean up
	attr.destroy(conn_add)
	attr.destroy(conn_remove)
end

function run.observer_composite_archetype_change()
	local a = attr.any(0)
	local b = attr.any(0)
	local A = attr.id(a)
	local B = attr.id(b)

	local change_calls = {}

	-- Observer for A+B archetype changes
	local AB_archetype = archetype.with_attr(A, B)
	local conn_change = attr.on_change(AB_archetype, function(entity)
		table.insert(change_calls, entity)
	end)

	local id = attr.id()

	-- Add A+B (should not trigger change on add)
	a:ensure(id)
	b:ensure(id)
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
	attr.destroy(conn_change)
end

return run
