local archetype_handle = require './archetype_handle'
local handle_archetype_id = archetype_handle.handle_id
local handle_archetype = archetype_handle.handle

local entity_archetype = require './entity_archetype'
local move_entity_archetype_to_without = entity_archetype.move_to_without
local move_entity_archetype_to_with = entity_archetype.move_to_with
local iter_archetype_entities = entity_archetype.iter_entities
local entity_has_attribute = entity_archetype.has_attribute
local destroy_attribute = entity_archetype.destroy_attribute

local archetype = require './archetype'
local archetype_with_attr = archetype.with_attr
local bind_transition = archetype.bind_transition

local attr = require './any'
local attr_find = attr.find
local attr_set = attr.set

local cleanup = require './cleanup'
local on_destroy = cleanup.on_destroy
local destroy = cleanup.destroy

local key = require './key'
local maybe_ensure_id = key.maybe_ensure_id
local maybe_alive = key.maybe_alive
local ensure_id = key.ensure_id
local alive = key.unsafe_alive
local find_id = key.find_id
type key = key.key
type id = key.id

-- defs
local function no_op() end
local backward_link = setmetatable({}, { __mode = 'kv' })

export type link_attr = link1 | linkN
export type link1 = attr.attr<key, id>
export type linkN = archetype_handle.arch1<id, {
	of: (any, of: key?) -> archetype_handle.arch1<nil, archetype_handle.base_impl<nil>>,
	remove: (any, key, target: key?) -> (),
	add: (any, key, target: key) -> (),

	assert_await: (any, key, target: key, message: string?) -> (),
	assert: (any, key, target: key, message: string?) -> (),
	await: (any, key, target: key) -> boolean,
	has: (any, key, target: key) -> boolean,

	iter: (any, target: key?) -> () -> id,
	all: (any, of: key?) -> { id },
}>

-- functions
local storage = key.pre_allocated_storage()
local id_of_targets = key.pre_allocated_storage()

local function destroy_targets_of_key(tracked_targets_of_key: key.tracked_id)
	local targets_of_key = alive(tracked_targets_of_key)

	local attrs = storage[targets_of_key]
	local id = id_of_targets[targets_of_key]
	storage[targets_of_key] = false

	local back = backward_link[attrs]
	if not back then return end

	for target in iter_archetype_entities(targets_of_key) do
		attr_set(back, target, nil)
	end
	destroy_attribute(targets_of_key)
	attrs[id] = nil
end
local function get_key_targets_tag(tags: linkN, id: id): id
	if tags[id] then return tags[id] end

	local tag, tracked_tag = ensure_id()
	id_of_targets[tag] = id
	storage[tag] = tags

	on_destroy(tag, destroy_targets_of_key)
	on_destroy(id, tracked_tag)

	archetype_with_attr(tag)
	bind_transition(ensure_id(tags), tag, tag)

	tags[id] = tag
	return tag
end
local function find_target_key_without_backlink(attr: linkN, target: key.tracked_id) -- TODO
	return nil
end

local function linkN_add(data: linkN, id: id, target: key.tracked_id)
	local target_tag = get_key_targets_tag(data, id)
	move_entity_archetype_to_with(target, target_tag)
end
local function linkN_remove(data: linkN, id: id, target: key.tracked_id?)
	local target_tag = data[id]
	if target_tag == nil then return end

	if target == nil then return destroy(target_tag) end
	move_entity_archetype_to_without(target, target_tag)
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
			for prev_target in iter_archetype_entities((ensure_id(data))) do
				attr_set(back, prev_target, nil)
			end
		end
		return linkN_remove(data, id)
	end

	if back ~= nil and attr_find(back, target_id) ~= tracked then return end
	linkN_remove(data, id, target)

	if back == nil then return end
	attr_set(back, target_id, nil)
end
local function link1N_add(data: linkN, key: key, target_key: key)
	local target_id, target = ensure_id(target_key)
	local id, tracked = ensure_id(key)

	local back = backward_link[data]
	local prev_key = if back then attr_find(back, target_id) else find_target_key_without_backlink(data, target)

	if prev_key == tracked then return end
	if prev_key ~= nil then linkN_remove(data, ensure_id(prev_key), target) end

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
			for prev_target in iter_archetype_entities((ensure_id(data))) do
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
local function linkN_targets_of(data: linkN, key: key): archetype_handle.arch1<nil>?
	local id = find_id(key) or error(`attempt to use dead reference '{key}'`)
	local tag_id = get_key_targets_tag(data, id)

	return handle_archetype_id(tag_id) :: any
end

local function linkN_iter(data: linkN, key: key?): () -> id?
	local key_id = key and find_id(key)
	local arch = if key_id ~= nil then data[key_id] else ensure_id(data)

	return if arch then iter_archetype_entities(arch) else no_op
end
local function linkN_all(data: linkN, key: key?): { id }
	local out = {}
	for id in linkN_iter(data, key) do
		table.insert(out, id)
	end
	return out
end

local function linkN_has(data: linkN, key: key, target_key: key): boolean
	local id = find_id(key)
	if id == nil then return false end

	local attr_for_key = data[id]
	if attr_for_key == nil then return false end

	local _, target = find_id(target_key)
	return target ~= nil and entity_has_attribute(target, attr_for_key)
end
local function linkN_assert_has(data: linkN, key: key, target_key: key, message: string?)
	if linkN_has(data, key, target_key) then return end

	assert(find_id(target_key) ~= nil, `target {target_key} is destroyed`)
	assert(find_id(key) ~= nil, `key {key} is destroyed`)
	error(message or `link of key '{key}' to '{target_key}' doesnt exist`)
end

local function linkN_await_has(data: linkN, key: key, target_key: key): boolean
	local id, tracked = ensure_id(key)
	while maybe_alive(tracked) and maybe_alive(target_key :: any) and not linkN_has(data, id, target_key) do
		task.wait()
	end
	return linkN_has(data, id, target_key)
end
local function linkN_assert_await_has(data: linkN, key: key, target_key: key, message: string?)
	if linkN_await_has(data, key, target_key) then return end

	assert(find_id(target_key) ~= nil, `target was destroyed`)
	error(message or `key destroyed before contains {data}`)
end

local linkN_impl = table.clone(archetype_handle.impl) :: any
linkN_impl.assert_await = linkN_assert_await_has
linkN_impl.assert = linkN_assert_has
linkN_impl.await = linkN_await_has
-- linkN_impl.remove = linkN_remove
linkN_impl.iter = linkN_iter
-- linkN_impl.add = linkN_add
linkN_impl.all = linkN_all
linkN_impl.has = linkN_has
linkN_impl.of = linkN_targets_of

-- metatables
local link11_impl = table.clone(attr.impl :: any)
link11_impl.remove = link11_set
link11_impl.set = link11_set
link11_impl.kind = 'link1'
link11_impl.__index = link11_impl
table.freeze(link11_impl)

local linkN1_impl = table.clone(attr.impl :: any)
linkN1_impl.remove = linkN1_set
linkN1_impl.set = linkN1_set
linkN1_impl.kind = 'link1'
linkN1_impl.__index = linkN1_impl
table.freeze(linkN1_impl)

local link1N_impl = table.clone(linkN_impl)
link1N_impl.remove = link1N_remove
link1N_impl.add = link1N_add
link1N_impl.kind = 'linkN'
link1N_impl.__index = link1N_impl
table.freeze(link1N_impl)

local linkNN_impl = table.clone(linkN_impl)
linkNN_impl.remove = linkNN_remove
linkNN_impl.add = linkNN_add
linkNN_impl.kind = 'linkN'
linkNN_impl.__index = linkNN_impl
table.freeze(linkNN_impl)

-- constructors
local function link_11(): (link1, link1)
	local forward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), link11_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	return handle_archetype(forward) :: any, handle_archetype(backward) :: any
end
local function link_1N(): (linkN, link1)
	local forward = setmetatable(key.pre_allocated_storage(), link1N_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkN1_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	return handle_archetype(forward) :: any, handle_archetype(backward) :: any
end
local function link_NN(): (linkN, linkN)
	local forward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any
	local backward = setmetatable(key.pre_allocated_storage(), linkNN_impl) :: any

	backward_link[forward] = backward
	backward_link[backward] = forward

	return handle_archetype(forward) :: any, handle_archetype(backward) :: any
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
