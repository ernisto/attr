local archetype = require('./archetype')
local attr = require('./any')
type attr<V = any> = attr.attr
local by_default = attr.by_default
local attr_set = attr.set

local key = require('./key')
local ensure_id = key.ensure_id
type id = key.id

-- defs
local map_attr_default: { [map_attr]: any } = {}
export type key = id | key.id_source
export type map_attr<K = any, V = any> = {
	await_until_destroy: (map_attr<K, V>, key, K) -> V?,
	assert_await: (map_attr<K, V>, key, K) -> V,
	assert: (map_attr<K, V>, key, K, message: string?) -> V,
	find: (map_attr<K, V>, key, K) -> V?,
	has: (map_attr<K, V>, key, K) -> boolean,

	remove: (map_attr<K, V>, key, K) -> (),
	ensure: (map_attr<K, V>, key, K) -> V,
	set: (map_attr<K, V>, key, K?, V?) -> V,

	iter: (map_attr<K, V>, key) -> () -> (K, V),
	all: ((map_attr<K, V>) -> { [id]: { [K]: V } }) & ((map_attr<K, V>, id) -> { [K]: V }),
}

-- methods
local function map_attr_find<K, V>(data: map_attr<K, V>, key: key, target: K): V?
	local id = ensure_id(key)
	local key_links = data[id]
	return if key_links == nil then nil else key_links[target]
end
local function map_attr_iter<V>(data: map_attr<V>, key: key) --: () -> (id, V)
	local id = ensure_id(key)
	return pairs(if key then (data[id] or {}) else data)
end
local function map_attr_set<K, V>(data: map_attr<K, V>, key: key, target: K?, value: V?): ()
	local id = ensure_id(key)
	if target == nil then data[id] = nil end

	local key_links = data[id]
	if key_links ~= nil then
		key_links[target] = value
		return
	end
	if value == nil then return end
	attr_set(data :: any, id, { [target] = value })
end

local function map_attr_has<K, V>(data: map_attr<K, V>, key: key, target: K): boolean
	return data:find(key, target) ~= nil
end
local function map_attr_ensure<K, V>(data: map_attr<K, V>, key: key, target: K): V
	local value = data:find(key, target)
	if value == nil then
		value = by_default(map_attr_default[data])
		data:set(key, target, value :: any)
	end
	return value :: any
end
local function map_attr_assert<K, V>(data: map_attr<K, V>, key: key, target: K, message: string?): V
	return data:find(key, target) or error(message or `not found`)
end
local function map_attr_all<K, V>(data: map_attr<K, V>, key: key): { [K]: V }
	local output = {}
	for id, data in data:iter(key) do
		output[id] = data
	end
	return output
end

local function map_attr_await_until_destroy<K, V>(data: map_attr<K, V>, maybe_destroyed_key: key, target: K): V?
	local tracked_id = ensure_id(key)
	while key.maybe_alive(tracked_id) and not data:has(tracked_id, target) do
		task.wait()
	end
	return data:find(tracked_id, target) :: any
end
local function map_attr_assert_await<K, V>(data: map_attr<K, V>, maybe_destroyed_key: key, target: K, message: string?): V
	return data:await_until_destroy(maybe_destroyed_key, target)
		or error(message or `key destroyed before contains {data}`)
end

-- metatable
local map_attr_impl = {
	await_until_destroy = map_attr_await_until_destroy,
	assert_await = map_attr_assert_await,
	assert = map_attr_assert,
	ensure = map_attr_ensure,
	iter = map_attr_iter,
	has = map_attr_has,
	all = map_attr_all,
	remove = map_attr_set,
	find = map_attr_find,
	set = map_attr_set,
}
map_attr_impl.__metatable = 'locked'
map_attr_impl.__index = map_attr_impl
map_attr_impl.kind = 'map'
table.freeze(map_attr_impl)

-- constructors
local function map_attr<K, V>(default: V): map_attr<K, V>
	local map_attr = setmetatable(key.pre_allocated_storage(), map_attr_impl)
	map_attr_default[map_attr :: any] = default
	archetype.with_attr(key.ensure_id(map_attr))
	return map_attr :: any
end

-- module
return table.freeze {
	await_until_destroy = map_attr_await_until_destroy,
	assert_await = map_attr_assert_await,
	assert = map_attr_assert,
	ensure = map_attr_ensure,
	iter = map_attr_iter,
	has = map_attr_has,
	all = map_attr_all,
	remove = map_attr_set,
	find = map_attr_find,
	set = map_attr_set,

	new = map_attr,
	impl = map_attr_impl,
}
