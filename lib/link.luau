local observer = require('./observer')

local archetype = require('./archetype')
local move_to_without = archetype.move_to_without
local move_to_with = archetype.move_to_with
local destroy_attribute = archetype.destroy_attribute
local get_archetype = archetype.get

local graph = require('./archetype/graph')
local bind_transition = graph.bind_transition

local attr = require('./any')
type attr<V = any> = attr.attr
local attr_find = attr.find
local attr_set = attr.set

local cleanup = require('./cleanup')
local on_destroy = cleanup.on_destroy
local destroy = cleanup.destroy

local key = require('./key')
local maybe_ensure_id = key.maybe_ensure_id
local ensure_id = key.ensure_id
local find_id = key.find_id
type key = key.key
type id = key.id

-- defs
local backward_link = setmetatable({}, { __mode = 'kv' })
export type link_attr = link1 | linkN
export type link1 = attr<id>
export type linkN = {
	await_until_destroy: (linkN, key, target: key) -> id?,
	assert_await: (linkN, key, target: key) -> id,
	assert: (linkN, key, target: key, message: string?) -> id,
	has: (linkN, key, target: key) -> boolean,

	remove: (linkN, key, target: key?) -> (),
	ensure: (linkN, key, target: key) -> (),
	add: (linkN, key, target: key) -> (),

	iter: (linkN, target: key?) -> () -> id,
	all: (linkN, of: key?) -> { id },
}

-- functions
local storage = key.pre_allocated_storage()
local id_of_targets = key.pre_allocated_storage()

local function destroy_targets_of_key(tracked_targets_of_key: key.tracked_id)
	local targets_of_key = key.unsafe_alive(tracked_targets_of_key)

	local attrs = storage[targets_of_key]
	local id = id_of_targets[targets_of_key]
	storage[targets_of_key] = false

	local back = backward_link[attrs]
	if not back then return end

	for target in archetype.iter_entities(targets_of_key) do
		attr_set(back, target, nil)
	end
	destroy_attribute(targets_of_key)
	attrs[id] = nil
end
local function get_key_targets(attrs: linkN, id: id): id
	if attrs[id] then return attrs[id] end

	local targets_of_key, tracked_arch = ensure_id()
	storage[targets_of_key] = attrs
	id_of_targets[targets_of_key] = id

	on_destroy(targets_of_key, destroy_targets_of_key)
	on_destroy(id, tracked_arch)

	archetype.with_attr(targets_of_key)
	bind_transition(ensure_id(attrs), targets_of_key, targets_of_key)

	attrs[id] = targets_of_key
	return targets_of_key
end
local function find_target_key_without_backlink(attr: linkN, target: key.tracked_id) -- TODO
	return nil
end

local function linkN_add(data: linkN, id: id, target: key.tracked_id)
	local key_target = get_key_targets(data, id)

	local new_arch = move_to_with(target, key_target)
	observer.fire_add(target, new_arch, key_target)
end
local function linkN_remove(data: linkN, id: id, target: key.tracked_id?)
	local key_target = data[id]
	if key_target == nil then return end

	if target == nil then return destroy(key_target) end
	local prev_arch = get_archetype(target)

	move_to_without(target, key_target)
	observer.fire_remove(target, prev_arch :: any, key_target)
end

-- methods
local function link11_set(data: link1, key: key, target_key: key?)
	local target_id, target = maybe_ensure_id(target_key)
	local id, tracked = ensure_id(key)

	local prev_target_id = maybe_ensure_id(attr_find(data, id))
	if prev_target_id == target_id then return end

	attr_set(data, id, target)

	local backward_data = backward_link[data]
	if backward_data == nil then return end

	if prev_target_id ~= nil then attr_set(backward_data, prev_target_id, nil) end
	if target_id ~= nil then attr_set(backward_data, target_id, tracked) end
end

local function linkN1_set(data: link1, key: key, target_key: key?)
	local target_id, target = maybe_ensure_id(target_key)
	local id, tracked = ensure_id(key)

	local prev_target_id = maybe_ensure_id(attr_find(data, key))
	if prev_target_id == target_id then return end

	attr_set(data, id, target)

	local backward_data = backward_link[data]
	if backward_data == nil then return end

	if prev_target_id ~= nil then linkN_remove(backward_data, prev_target_id, tracked) end
	if target_id ~= nil then linkN_add(backward_data, target_id, tracked) end
end

local function link1N_remove(data: linkN, key: key, target_key: key?)
	local id, tracked = find_id(key)
	if id == nil then return end

	local target_id, target = maybe_ensure_id(target_key)
	local back = backward_link[data]

	if target_id == nil then
		if back ~= nil then
			for prev_target in archetype.iter_entities((ensure_id(data))) do
				attr_set(back, prev_target, nil)
			end
		end
		return linkN_remove(data, id)
	end

	if data ~= nil and attr_find(back, target_id) ~= tracked then return end
	linkN_remove(data, id, target)

	if back == nil then return end
	attr_set(back, target_id, nil)
end
local function link1N_add(data: linkN, key: key, target_key: key)
	local target_id, target = ensure_id(target_key)
	local id, tracked = ensure_id(key)

	local back = backward_link[data]
	if back == nil or back[target_id] == tracked then return end

	local prev_key = attr_find(back, target_id) or find_target_key_without_backlink(data, target)
	if prev_key then linkN_remove(data, ensure_id(prev_key), target) end

	attr_set(back, target_id, tracked)
	linkN_add(data, id, target)
end

local function linkNN_remove(data: linkN, key: key, target_key: key?)
	local id, tracked = find_id(key)
	if id == nil then return end

	local target_id, target = maybe_ensure_id(target_key)
	local back = backward_link[data]

	if target_id == nil then
		if back ~= nil then
			for prev_target in archetype.iter_entities((ensure_id(data))) do
				linkN_remove(back, prev_target, tracked)
			end
		end
	elseif back ~= nil then
		linkN_remove(back, target_id, tracked)
	end

	linkN_remove(data, id, target)
end
local function linkNN_add(data: linkN, key: key, target_key: key)
	local target_id, target = ensure_id(target_key)
	local id, tracked = ensure_id(key)

	linkN_add(data, id, target)
	local back = backward_link[data]

	if back == nil then return end
	linkN_add(back, target_id, tracked)
end

-- utils
local function linkN_await_until_destroy(data: linkN, maybe_destroyed_key: key, maybe_destroyed_target: key): id?
	local id, tracked = ensure_id(maybe_destroyed_key)
	while key.maybe_alive(tracked) and not data:has(id, maybe_destroyed_target) do
		task.wait()
	end
	return data:has(id, maybe_destroyed_target) and maybe_destroyed_target or nil
end
local function linkN_assert_await(
	data: linkN,
	maybe_destroyed_key: key,
	maybe_destroyed_target: key,
	message: string?
): id?
	return data:await_until_destroy(maybe_destroyed_key, maybe_destroyed_target)
		or error(message or `key destroyed before contains {data}`)
end
local function linkN_has(data: linkN, key: key, target_key: key): boolean
	local id = find_id(key)
	if id == nil then return false end

	local attr_for_key = data[id]
	if attr_for_key == nil then return false end

	local _, target = find_id(target_key)
	return target ~= nil and archetype.has_attribute(target, attr_for_key)
end
local function linkN_assert(data: linkN, key: key, target: key, message: string?)
	return linkN_has(data, key, target) or error(message or `link of key '{key}' to '{target}' doesnt exist`)
end

local function linkN_ensure(data: linkN, key: key, target: key): ()
	if linkN_has(data, key, target) then return end
	data:add(key, target)
end

local function linkN_iter(data: linkN, key: key?): () -> id?
	local key_id = key and find_id(key)
	local arch = if key_id ~= nil then data[key_id] else ensure_id(data)
	return if arch then archetype.iter_entities(arch) else function() end :: any
end
local function linkN_all(data: linkN, key: key?): { id }
	local out = {}
	for id in linkN_iter(data, key) do
		table.insert(out, id)
	end
	return out
end

local linkN_impl = table.freeze {
	await_until_destroy = linkN_await_until_destroy,
	assert_await = linkN_assert_await,
	assert = linkN_assert,
	ensure = linkN_ensure,
	iter = linkN_iter,
	all = linkN_all,
	has = linkN_has,
}

-- metatables
local link11_impl = table.clone(attr.impl :: any)
link11_impl.remove = link11_set
link11_impl.set = link11_set
link11_impl.__metatable = 'locked'
link11_impl.__index = link11_impl
link11_impl.kind = 'link1'
table.freeze(link11_impl)

local linkN1_impl = table.clone(attr.impl :: any)
linkN1_impl.remove = linkN1_set
linkN1_impl.set = linkN1_set
linkN1_impl.__metatable = 'locked'
linkN1_impl.__index = linkN1_impl
linkN1_impl.kind = 'link1'
table.freeze(linkN1_impl)

local link1N_impl = table.clone(linkN_impl)
link1N_impl.remove = link1N_remove
link1N_impl.add = link1N_add
link1N_impl.__metatable = 'locked'
link1N_impl.__index = link1N_impl
link1N_impl.kind = 'linkN'
table.freeze(link1N_impl)

local linkNN_impl = table.clone(linkN_impl)
linkNN_impl.remove = linkNN_remove
linkNN_impl.add = linkNN_add
linkNN_impl.__metatable = 'locked'
linkNN_impl.__index = linkNN_impl
linkNN_impl.kind = 'linkN'
table.freeze(linkNN_impl)

-- constructors
local function link_11(): (link1, link1)
	local forward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr((ensure_id(forward)))
	archetype.with_attr((ensure_id(backward)))
	return forward, backward
end
local function link_1N(): (linkN, link1)
	local forward = setmetatable(key.pre_allocated_storage(), link1N_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkN1_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr((ensure_id(forward)))
	archetype.with_attr((ensure_id(backward)))
	return forward, backward
end
local function link_NN(): (linkN, linkN)
	local forward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	archetype.with_attr((ensure_id(forward)))
	archetype.with_attr((ensure_id(backward)))
	return forward, backward
end
local function link_N1(): (link1, linkN)
	local a, b = link_1N()
	return b, a
end

-- module
return table.freeze {
	link_11 = link_11,
	link_1N = link_1N,
	link_NN = link_NN,
	link_N1 = link_N1,
}
