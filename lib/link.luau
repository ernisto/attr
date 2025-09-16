local archetype = require('./archetype')
local attr = require('./any')
type attr<V = any> = attr.attr
local attr_find = attr.find
local attr_set = attr.set

local map_attr = require('./map')
type map_attr<K, V> = map_attr.map_attr<K, V>
local map_attr_iter = map_attr.iter
local map_attr_set = map_attr.set

local key = require('./key')
type id = key.id

-- defs
local backward_link = setmetatable({}, { __mode = 'kv' }) :: any
export type link_attr<V = any> = link1<V> | linkN<V>
export type linkN<V = any> = map_attr<id, V>
export type link1<V = any> = attr<id>

-- methods
local function link11_set<V>(data: link1<V>, key: id, target: id?, value: V?)
	local prev_target = attr_find(data, key)
	attr_set(data, key, target)

	local backward_data = backward_link[data] :: any
	if backward_data == nil then return end

	if prev_target ~= nil and prev_target ~= target then attr_set(backward_data, prev_target, nil) end
	if target == nil then return end

	attr_set(backward_data, target, key)
end
local function link1N_set<V>(data: linkN<V>, key: id, target: id?, value: V?)
	local backward_data = backward_link[data] :: any

	if target ~= nil then
		map_attr_set(data, key, target, value)
		if backward_data == nil then return end

		local prev_key = attr_find(backward_data, target)
		if prev_key then map_attr_set(data, prev_key, target, nil :: any) end

		return attr_set(backward_data, target, value and key)
	end

	-- remove all targets for this key; capture then clear
	if backward_data ~= nil then
		for prev_target in map_attr_iter(data, key) do
			attr_set(backward_data, prev_target, nil)
		end
	end
	map_attr_set(data, key, nil, nil)
end
local function linkNN_set<V>(data: linkN<V>, key: id, target: id?, value: V?)
	local backward_data = backward_link[data] :: any

	if target ~= nil then
		map_attr_set(data, key, target, value)
		if backward_data == nil then return end

		return map_attr_set(backward_data, target, key, value)
	end

	-- remove all targets for this key; capture then clear
	if backward_data ~= nil then
		for prev_target in map_attr_iter(data, key) do
			map_attr_set(backward_data, prev_target, key, nil)
		end
	end
	map_attr_set(data, key, nil, nil)
end
local function linkN1_set<V>(data: link1<V>, key: id, target: id?, value: V?)
	local prev_target = attr_find(data, key)
	attr_set(data, key, target)

	local backward_data = backward_link[data] :: any
	if backward_data == nil then return end

	if prev_target ~= nil and prev_target ~= target then map_attr_set(backward_data, prev_target, key, nil :: any) end
	if target == nil then return end

	map_attr_set(backward_data, target, key, value or target)
end

-- local function iter_descendants<V>(data: linkN<V>, key: id): () -> (id, V)
-- 	local values = {}
-- 	local ids = {}

-- 	local iter = data:iter(key)
-- 	return function()
-- 		while iter == nil or id == nil do
-- 			local next_id = table.remove(ids)
-- 			if next_id then return next_id, table.remove(values) :: any end

-- 			iter = data:iter(next_id)
-- 		end
-- 		local queued_id, queued_value = iter()
-- 		table.insert(queued_id, queued_value)
-- 	end
-- end

-- metatables
local link11_impl = table.clone(attr.impl)
link11_impl.remove = link11_set :: any
link11_impl.set = link11_set :: any
link11_impl.__metatable = 'locked'
link11_impl.__index = link11_impl
link11_impl.kind = 'link1'
table.freeze(link11_impl)

local linkN1_impl = table.clone(attr.impl)
linkN1_impl.remove = linkN1_set :: any
linkN1_impl.set = linkN1_set :: any
linkN1_impl.__metatable = 'locked'
linkN1_impl.__index = linkN1_impl
linkN1_impl.kind = 'link1'
table.freeze(linkN1_impl)

local link1N_impl = table.clone(map_attr.impl)
link1N_impl.remove = link1N_set :: any
link1N_impl.set = link1N_set :: any
link1N_impl.__metatable = 'locked'
link1N_impl.__index = link1N_impl
link1N_impl.kind = 'linkN'
table.freeze(link1N_impl)

local linkNN_impl = table.clone(map_attr.impl)
linkNN_impl.remove = linkNN_set :: any
linkNN_impl.set = linkNN_set :: any
linkNN_impl.__metatable = 'locked'
linkNN_impl.__index = linkNN_impl
linkNN_impl.kind = 'linkN'
table.freeze(linkNN_impl)

-- constructors
local function link_11<V>(default: V): (link1<V>, link1<V>)
	local forward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr(key.ensure_id(forward))
	archetype.with_attr(key.ensure_id(backward))
	return forward, backward
end
local function link_1N<V>(default: V): (linkN<V>, link1<V>)
	local forward = setmetatable(key.pre_allocated_storage(), link1N_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkN1_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr(key.ensure_id(forward))
	archetype.with_attr(key.ensure_id(backward))
	return forward, backward
end
local function link_NN<V>(default: V): (linkN<V>, linkN<V>)
	local forward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr(key.ensure_id(forward))
	archetype.with_attr(key.ensure_id(backward))
	return forward, backward
end
local function link_N1<V>(default: V): (link1<V>, linkN<V>)
	local a, b = link_1N(default)
	return b, a
end

-- module
return table.freeze {
	link_11 = link_11,
	link_1N = link_1N,
	link_NN = link_NN,
	link_N1 = link_N1,
}
