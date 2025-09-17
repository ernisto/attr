local any = require('@lib/any')
local cleanup = require('../lib/cleanup')
local key = require('@lib/key')
local run, focus, skip = {}, {}, {}

function run.generate_distinct_positive_ids_for_nil()
	local a = key.ensure_id()
	local b = key.ensure_id()
	assert(type(a) == 'number' and a > 0, 'id a should be positive number')
	assert(type(b) == 'number' and b > 0, 'id b should be positive number')
	assert(a ~= b, 'ids for nil should be distinct')
end

function run.accepts_explicit_positive_integer_id()
	local x = key.ensure_id(42)
	assert(x == 42, 'explicit integer id should pass through')
end

function run.rejects_primitive_non_gc_values()
	local ok1 = pcall(function()
		key.ensure_id('abc')
	end)
	assert(not ok1, 'string should be rejected')

	local ok2 = pcall(function()
		key.ensure_id(true)
	end)
	assert(not ok2, 'boolean should be rejected')

	local ok3 = pcall(function()
		key.ensure_id(1.5)
	end)
	assert(not ok3, 'non-integer number should be rejected')
end

function run.same_id_for_same_table()
	local t = {}
	local a = key.ensure_id(t)
	local b = key.ensure_id(t)
	assert(a == b, 'same table should map to same id')
end

function run.destroy_id_removes_from_attr_storages()
	local attr = any.new(false)
	local id = key.ensure_id()
	attr:set(id, true)
	assert(attr:has(id), 'attr should contain id before destroy')
	cleanup.destroy(id)
	assert(not attr:has(id), 'attr should not contain id after destroy')
end

function run.destroy_id_trigger_on_destroyed()
	local id = key.ensure_id()

	local called = 0
	cleanup.on_destroy(id, function()
		called += 1
	end)

	cleanup.destroy(id)
	assert(called == 1, `on_destroy callback get called only 1 time`)
end

function run.reuses_freed_ids_from_pool()
	local id1 = key.ensure_id()
	cleanup.destroy(id1)
	local id2 = key.ensure_id()
	assert(id2 == id1, 'new id should reuse freed id')
end

return { run = run, skip = skip, focus = focus }
