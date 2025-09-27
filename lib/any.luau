local archetype = require './archetype'
local archetype_event = require './archetype_event'
local fire_change = archetype_event.fire_change

local entity_archetype = require './entity_archetype'
local move_entity_archetype_to_without = entity_archetype.move_to_without
local move_entity_archetype_to_with = entity_archetype.move_to_with
local get_entity_archetype = entity_archetype.get

local key = require './key'
local maybe_alive = key.maybe_alive
local ensure_id = key.ensure_id
local find_id = key.find_id
type key = key.key
type id = key.id

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

	remove: (attr<V>, key) -> (),
	set: (attr<V>, key, V) -> (),
	add: (attr<V>, key) -> V,

	iter: (attr<V>) -> () -> (id, V),
	all: (attr<V>) -> { [id]: V },
}

-- methods
local function attr_find<V>(data: attr<V>, key: key): V?
	local id = find_id(key)
	return id and data[id]
end
local function attr_set<V>(data: attr<V>, key: key, value: V?): ()
	local id, tracked = ensure_id(key)
	local prev_value = data[id]

	if prev_value == value then return end
	local attr_id = ensure_id(data)

	if value == nil and prev_value ~= nil then
		move_entity_archetype_to_without(tracked, attr_id)
		data[id] = value
	elseif value ~= nil and prev_value == nil then
		data[id] = value
		move_entity_archetype_to_with(tracked, attr_id)
	else
		data[id] = value
		fire_change(tracked, get_entity_archetype(id) :: any, attr_id)
	end
	data[id] = value
end
local function attr_iter<V>(data: attr<V>) --: () -> (id, V)
	return pairs(data :: any)
end

local function attr_has<V>(data: attr<V>, key: key): boolean
	return attr_find(data, key) ~= nil
end
local function attr_add<V>(data: attr<V>, key: key): V
	local value = attr_find(data, key)
	if value == nil then
		value = by_default(attr_default[data])
		attr_set(data, key, value :: any)
	end
	return value :: any
end
local function attr_all<V>(data: attr<V>): { [id]: V }
	local output = {}
	for k, v in attr_iter(data) do
		output[k] = v
	end
	return output
end

local function attr_assert<V>(data: attr<V>, key: key, message: string?): V
	return attr_find(data, key) or error(message or `not found`)
end
local function attr_await_until_destroy<V>(data: attr<V>, key: any): V?
	local id = ensure_id(key)
	while maybe_alive(id) and not attr_has(data, key) do
		task.wait()
	end
	return attr_find(data, key) :: any
end
local function attr_assert_await<V>(data: attr<V>, key: key, message: string?): V
	return attr_await_until_destroy(data, key) or error(message or `key destroyed before contains {data}`)
end

-- constructor
local attr_impl = {
	await_until_destroy = attr_await_until_destroy,
	assert_await = attr_assert_await,
	assert = attr_assert,
	remove = attr_set,
	find = attr_find,
	iter = attr_iter,
	set = attr_set,
	add = attr_add,
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
	remove = attr_set,
	find = attr_find,
	set = attr_set,
	add = attr_add,
	has = attr_has,
	all = attr_all,

	by_default = by_default,
	new = attr_new,
	impl = attr_impl,
}
