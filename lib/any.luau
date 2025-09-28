local archetype_handle = require './archetype_handle'
local handle_archetype = archetype_handle.handle

local archetype_event = require './archetype_event'
local fire_change = archetype_event.fire_change

local entity_archetype = require './entity_archetype'
local move_entity_archetype_to_without = entity_archetype.move_to_without
local move_entity_archetype_to_with = entity_archetype.move_to_with
local get_entity_archetype = entity_archetype.get

local key = require './key'
local ensure_id = key.ensure_id
local find_id = key.find_id
type key = key.key
type id = key.id

-- functions
local attr_default = key.pre_allocated_storage()
local function by_default<V>(defined_default: V): V
	return if type(defined_default) == 'table' then table.clone(defined_default) else defined_default :: any
end

-- defs
export type attr<V = any> = archetype_handle.arch1<
	V,
	{
		remove: (attr<V>, key) -> (),
		set: (attr<V>, key, V) -> (),
		add: (attr<V>, key) -> V,

		-- inline archetype_handle.base_impl<V>
		iter: (any) -> () -> key.id,
		all: (any) -> { key.id },

		assert_await_has: (any, key: key.key) -> (),
		await_has: (any, key: key.key) -> boolean,
		assert_has: (any, key: key.key) -> (),
		has: (any, key: key.key) -> boolean,

		assert_await: (any, key: key.key) -> V,
		await: (any, key: key.key) -> V?,
		assert: (any, key: key.key) -> V,
		find: (any, key: key.key) -> V?,
	}
>

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

	data[id] = value
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
end
local function attr_add<V>(data: attr<V>, key: key): V
	local value = attr_find(data, key)
	if value ~= nil then return value end

	value = by_default(attr_default[ensure_id(data)])
	attr_set(data, key, value :: any)
	return value :: any
end

-- constructor
local attr_impl = table.clone(archetype_handle.impl) :: any
attr_impl.remove = attr_set
attr_impl.find = attr_find
attr_impl.set = attr_set
attr_impl.add = attr_add
attr_impl.kind = 'any'
attr_impl.__index = attr_impl
table.freeze(attr_impl)

local function attr_new<V>(default: V): attr<V>
	local data = setmetatable(key.pre_allocated_storage(), attr_impl) :: any
	attr_default[ensure_id(data)] = default

	return handle_archetype(data) :: any
end

-- module
return table.freeze {
	remove = attr_set,
	find = attr_find,
	set = attr_set,
	add = attr_add,

	by_default = by_default,
	new = attr_new,
	impl = attr_impl,
}
