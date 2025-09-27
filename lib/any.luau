local archetype = require('./archetype')
local key = require './key'
local observer = require('./observer')
local ensure_id = key.ensure_id
type key = key.key
type id = key.id

-- pair(any, player) -> owner(player), replicating(player)
-- pair(owner, player) -> item1, item2
-- pair(owner, any) -> item1, item2, item3
-- owner -> player

-- functions
local function by_default<V>(defined_default: V): V
	return if type(defined_default) == 'table' then table.clone(defined_default) else defined_default :: any
end

-- defs
local attr_default: { [attr]: any } = {}
export type attr<V = any> = {
	await_until_destroy: (attr<V>, key) -> V?,
	assert_await: (attr<V>, key) -> V,
	assert: (attr<V>, key, message: string?) -> V,
	find: (attr<V>, key) -> V?,
	has: (attr<V>, key) -> boolean,
	swap: (attr<V>, key, key) -> (V?, V?),

	remove: (attr<V>, key) -> (),
	ensure: (attr<V>, key) -> V,
	set: (attr<V>, key, V) -> (),

	iter: (attr<V>) -> () -> (id, V),
	all: (attr<V>) -> { [id]: V },
}

-- methods
local function attr_find<V>(data: attr<V>, key: key): V?
	return data[ensure_id(key)]
end
local function attr_set<V>(data: attr<V>, key: key, value: V?): ()
	local id, tracked = ensure_id(key)
	local attr_id = ensure_id(data)
	local prev_value = data[id]

	if value == nil and prev_value ~= nil then
		local prev_arch = archetype.move_to_without(tracked, attr_id)
		observer.fire_remove(tracked, prev_arch :: any, attr_id)
	elseif value ~= nil and prev_value == nil then
		local new_arch = archetype.move_to_with(tracked, attr_id)
		observer.fire_add(tracked, new_arch, attr_id)
	else
		observer.fire_change(tracked, archetype.get(id) :: any, attr_id)
	end
	data[id] = value
end
local function attr_iter<V>(data: attr<V>) --: () -> (id, V)
	return pairs(data :: any)
end

local function attr_has<V>(data: attr<V>, key: key): boolean
	return data:find(key) ~= nil
end
local function attr_ensure<V>(data: attr<V>, key: key): V
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
local function attr_swap<V>(data: attr<V>, key1: key, key2: key): (V?, V?)
	local v1 = data:find(key1)
	local v2 = data:find(key2)
	data:set(key1, v2 :: any)
	data:set(key2, v1 :: any)
	return v2, v1
end

local function attr_assert<V>(data: attr<V>, key: key, message: string?): V
	return data:find(key) or error(message or `not found`)
end
local function attr_await_until_destroy<V>(data: attr<V>, maybe_destroyed_key: any): V?
	local id = key.ensure_id(maybe_destroyed_key)
	while key.maybe_alive(id) and not data:has(maybe_destroyed_key) do
		task.wait()
	end
	return data:find(maybe_destroyed_key) :: any
end
local function attr_assert_await<V>(data: attr<V>, maybe_destroyed_key: key, message: string?): V
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
	archetype.with_attr((key.ensure_id(data)))
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
