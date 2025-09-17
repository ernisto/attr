local any = require('@lib/any')
local key = require('@lib/key')

local run, focus, skip = {}, {}, {}

function run.set_find_has_and_remove()
	local attr = any.new(0)
	local id = key.ensure_id()
	assert(not attr:has(id), 'should not have before set')
	attr:set(id, 5)
	assert(attr:has(id), 'should have after set')
	assert(attr:find(id) == 5, 'find should return set value')
	attr:remove(id)
	assert(not attr:has(id), 'should not have after remove')
end

function run.ensure_creates_with_primitive_default()
	local attr = any.new(123)
	local id = key.ensure_id()
	local v = attr:ensure(id)
	assert(v == 123, 'ensure should create with primitive default')
	assert(attr:find(id) == 123, 'value stored after ensure')
end

function run.ensure_clones_table_default_per_id()
	local default = { a = 1 }
	local attr = any.new(default)
	local id1 = key.ensure_id()
	local id2 = key.ensure_id()
	local v1 = attr:ensure(id1)
	local v2 = attr:ensure(id2)
	assert(v1 ~= default, 'ensure should clone table default')
	assert(v2 ~= default, 'ensure should clone table default')
	assert(v1 ~= v2, 'each id should get its own clone')
	v1.a = 42
	assert(v2.a == 1, 'mutating one clone should not affect the other')
end

function run.assert_errors_when_missing()
	local attr = any.new(false)
	local id = key.ensure_id()
	local ok = pcall(function()
		attr:assert(id)
	end)
	assert(not ok, 'assert should error when key missing')
end

function run.all_returns_shallow_copy()
	local attr = any.new(0)
	local id1 = key.ensure_id()
	local id2 = key.ensure_id()
	attr:set(id1, 10)
	attr:set(id2, 20)
	local all = attr:all()
	assert(all[id1] == 10 and all[id2] == 20, 'all should contain all entries')
end

return { run = run, skip = skip, focus = focus }
