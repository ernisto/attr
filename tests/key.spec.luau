local any = require('@lib/any')
local key = require('@lib/key')
local run, focus, skip = {}, {}, {}

function run.generate_distinct_positive_ids_for_nil()
	local a = key.assert_ensure_id()
	local b = key.assert_ensure_id()
	assert(type(a) == 'number' and a > 0, 'id a should be positive number')
	assert(type(b) == 'number' and b > 0, 'id b should be positive number')
	assert(a ~= b, 'ids for nil should be distinct')
end

function run.accepts_explicit_positive_integer_id()
	local x = key.assert_ensure_id(42)
	assert(x == 42, 'explicit integer id should pass through')
end

function run.rejects_primitive_non_gc_values()
	local ok1 = pcall(function()
		key.assert_ensure_id('abc')
	end)
	assert(not ok1, 'string should be rejected')

	local ok2 = pcall(function()
		key.assert_ensure_id(true)
	end)
	assert(not ok2, 'boolean should be rejected')

	local ok3 = pcall(function()
		key.assert_ensure_id(1.5)
	end)
	assert(not ok3, 'non-integer number should be rejected')
end

function run.same_id_for_same_table()
	local t = {}
	local a = key.assert_ensure_id(t)
	local b = key.assert_ensure_id(t)
	assert(a == b, 'same table should map to same id')
end

function run.destroy_id_removes_from_attr_storages()
	local attr = any.new(false)
	local id = key.assert_ensure_id()
	attr:set(id, true)
	assert(attr:has(id), 'attr should contain id before destroy')
	key.destroy_id(id)
	assert(not attr:has(id), 'attr should not contain id after destroy')
end

function run.destroy_id_trigger_on_destroyed()
	local id = key.assert_ensure_id()

	local called = 0
	key.on_destroy(id, function()
		called += 1
	end)

	key.destroy_id(id)
	assert(called == 1, `on_destroy callback get called only 1 time`)
end

function run.reuses_freed_ids_from_pool()
	local id1 = key.assert_ensure_id()
	key.destroy_id(id1)
	local id2 = key.assert_ensure_id()
	assert(id2 == id1, 'new id should reuse freed id')
end

return { run = run, skip = skip, focus = focus }
