local archetype = require('./archetype')
local key = require './key'
type id = key.id

-- functions
local function by_default<V>(defined_default: V): V
	return if type(defined_default) == 'table' then table.clone(defined_default) else defined_default :: any
end

-- defs
local attr_default: { [attr]: any } = {}
export type attr<V = any> = {
	await_until_destroy: (attr<V>, id) -> V?,
	assert_await: (attr<V>, id) -> V,
	assert: (attr<V>, id, message: string?) -> V,
	find: (attr<V>, id) -> V?,
	has: (attr<V>, id) -> boolean,
	swap: (attr<V>, id, id) -> (V?, V?),

	remove: (attr<V>, id) -> (),
	ensure: (attr<V>, id) -> V,
	set: (attr<V>, id, V) -> (),

	iter: (attr<V>) -> () -> (id, V),
	all: (attr<V>) -> { [id]: V },
}

-- methods
local source_ids = key.source_ids
local function attr_find<V>(data: attr<V>, key: id): V?
	return data[key]
end
local function attr_set<V>(data: attr<V>, id: id, value: V?): ()
	if value == nil and data[id] ~= nil then
		archetype.move_to_without(id, source_ids[data])
	elseif value ~= nil and data[id] == nil then
		archetype.move_to_with(id, source_ids[data])
	end
	data[id] = value
end
local function attr_iter<V>(data: attr<V>) --: () -> (id, V)
	return pairs(data :: any)
end

local function attr_has<V>(data: attr<V>, key: id): boolean
	return data:find(key) ~= nil
end
local function attr_ensure<V>(data: attr<V>, key: id): V
	local value = data:find(key)
	if value == nil then
		value = by_default(attr_default[data])
		data:set(key, value :: any)
	end
	return value :: any
end
local function attr_all<V>(data: attr<V>): { [id]: V }
	local output = {}
	for k, v in data:iter() do
		output[k] = v
	end
	return output
end
local function attr_swap<V>(data: attr<V>, id1: id, id2: id): (V?, V?)
	local v1 = data:find(id1)
	local v2 = data:find(id2)
	data:set(id1, v2 :: any)
	data:set(id2, v1 :: any)
	return v2, v1
end

local function attr_assert<V>(data: attr<V>, key: id, message: string?): V
	return data:find(key) or error(message or `not found`)
end
local function attr_await_until_destroy<V>(data: attr<V>, maybe_destroyed_key: id): V?
	local key_gen = key.get_reused_amount(maybe_destroyed_key)
	while key.get_reused_amount(maybe_destroyed_key) == key_gen and not data:has(maybe_destroyed_key) do
		task.wait()
	end
	return data:find(maybe_destroyed_key) :: any
end
local function attr_assert_await<V>(data: attr<V>, maybe_destroyed_key: id, message: string?): V
	return data:await_until_destroy(maybe_destroyed_key) or error(message or `key destroyed before contains {data}`)
end

-- constructor
local attr_impl = {
	await_until_destroy = attr_await_until_destroy,
	assert_await = attr_assert_await,
	assert = attr_assert,
	ensure = attr_ensure,
	remove = attr_set,
	find = attr_find,
	iter = attr_iter,
	swap = attr_swap,
	set = attr_set,
	has = attr_has,
	all = attr_all,
}
attr_impl.__metatable = 'locked'
attr_impl.__index = attr_impl
attr_impl.kind = 'any'
table.freeze(attr_impl)

local function attr_new<V>(default: V): attr<V>
	local data = setmetatable(key.pre_allocated_storage(), attr_impl) :: any
	attr_default[data] = default
	archetype.with_attr(key.ensure_id(data))
	return data
end

-- module
return table.freeze {
	await_until_destroy = attr_await_until_destroy,
	assert_await = attr_assert_await,
	assert = attr_assert,
	ensure = attr_ensure,
	remove = attr_set,
	find = attr_find,
	swap = attr_swap,
	set = attr_set,
	has = attr_has,
	all = attr_all,

	by_default = by_default,
	new = attr_new,
	impl = attr_impl,
}
