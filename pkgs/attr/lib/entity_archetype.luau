local key = require './key'
local current_archetype = key.pre_allocated_storage() -- archetype
local head_id = key.pre_allocated_storage()
local next_id = key.pre_allocated_storage()
local prev_id = key.pre_allocated_storage()
local maybe_source = key.maybe_source
local free_id = key.free_id
local alive = key.unsafe_alive

local archetype_event = require './archetype_event'
local archetype_connection_roots = archetype_event.connection_roots
local fire_removed_event = archetype_event.fire_remove
local fire_added_event = archetype_event.fire_add

local archetype = require './archetype'
local iter_bigger_archetypes = archetype.iter_bigger_archetypes
local next_archetype_without = archetype.next_archetype_without
local next_archetype_with = archetype.next_archetype_with
local archetype_has_some_attribute = archetype.has_some_attribute
local archetype_has_attribute = archetype.has_attribute
local reset_transitions = archetype.reset_transitions
local match_attributes = archetype.match_attributes
local attributes = archetype.attributes

-- defs
type archetype_id = key.id
type attribute_id = key.id
type entity_id = key.tracked_id

-- functions
local function iter_entities(root_archetype: archetype_id, exclude: { [attribute_id]: true }?): () -> key.tracked_id?
	local next_compatible_archetype = iter_bigger_archetypes(root_archetype, exclude)
	local archetype = next_compatible_archetype()
	local next_entity = archetype and head_id[archetype]

	return function()
		if archetype == nil then return end
		while next_entity == nil do
			archetype = next_compatible_archetype()
			if archetype == nil then break end

			next_entity = head_id[archetype]
		end
		local entity = next_entity

		next_entity = next_entity and next_id[alive(next_entity)]
		return entity
	end
end

local function remove_archetype_entity(archetype: archetype_id, entity: key.tracked_id)
	local prev = prev_id[alive(entity)]
	local next = next_id[alive(entity)]
	if prev then
		next_id[alive(prev)] = next
	else
		head_id[archetype] = next
	end
	if next then prev_id[alive(next)] = prev end
end
local function add_archetype_entity(archetype: archetype_id, entity: key.tracked_id)
	local prev_head = head_id[archetype]

	head_id[archetype] = entity
	prev_id[alive(entity)] = nil

	if prev_head then prev_id[alive(prev_head)] = entity end
	next_id[alive(entity)] = prev_head
end

local function set_entity_archetype(entity: key.tracked_id, new_archetype: archetype_id?, prev_archetype: archetype_id?)
	if prev_archetype ~= nil then remove_archetype_entity(prev_archetype, entity) end
	if new_archetype ~= nil then add_archetype_entity(new_archetype, entity) end
	current_archetype[alive(entity)] = new_archetype :: any
end
local function get_entity_archetype(entity: entity_id): archetype_id?
	return current_archetype[alive(entity)]
end

local function move_entity_to_with(entity: key.tracked_id, added: attribute_id): archetype_id
	local prev_archetype = get_entity_archetype(entity)
	local new_archetype = next_archetype_with(prev_archetype, added)

	set_entity_archetype(entity, new_archetype, prev_archetype)
	fire_added_event(entity, new_archetype, added)

	return new_archetype
end
local function move_entity_to_without(entity: key.tracked_id, removed: attribute_id): archetype_id
	local prev_archetype = get_entity_archetype(entity) :: archetype_id
	local new_archetype = next_archetype_without(prev_archetype, removed)

	set_entity_archetype(entity, new_archetype, prev_archetype)
	fire_removed_event(entity, prev_archetype, removed)

	return prev_archetype
end

local function entity_is_a(entity: key.tracked_id, base_archetype: archetype_id): boolean
	local archetype = get_entity_archetype(entity)
	if archetype == nil then return false end
	if archetype == base_archetype then return true end

	return match_attributes(attributes[archetype], attributes[base_archetype])
end
local function get_entity_attributes(entity: key.tracked_id): { attribute_id }
	local archetype = get_entity_archetype(entity)
	return if archetype then attributes[archetype] else {}
end

local function entity_has_attribute(entity: entity_id, attribute: attribute_id)
	local archetype = get_entity_archetype(entity)
	return archetype ~= nil and archetype_has_attribute(archetype, attribute)
end
local function entity_has_some_attribute(entity: entity_id, map: { [attribute_id]: true })
	local archetype = get_entity_archetype(entity)
	return archetype ~= nil and archetype_has_some_attribute(archetype, map)
end

local function remove_entity_archetype(entity: key.tracked_id)
	local archetype = get_entity_archetype(entity)
	if archetype == nil then return end

	local id = alive(entity)
	for _, attribute in attributes[archetype] do
		local data = maybe_source(attribute)
		if data ~= nil then data:remove(id) end
	end
	set_entity_archetype(entity, nil, archetype)
end
local function destroy_attribute(attribute: attribute_id)
	local data = maybe_source(attribute)
	local remove = data and data.remove

	if remove ~= nil then
		for id in iter_entities(attribute) do
			remove(data, id)
		end
	end

	local bigger_archetypes = {}
	for archetype in iter_bigger_archetypes(attribute) do
		table.insert(bigger_archetypes, archetype)
	end

	for _, archetype in bigger_archetypes do
		head_id[archetype] = nil
		reset_transitions(archetype)
		free_id(archetype)

		local connections = archetype_connection_roots[archetype]
		if connections == nil then continue end

		for _, disconnect in connections do
			disconnect()
		end
	end
end

-- module
return table.freeze {
	iter_entities = iter_entities,
	destroy_attribute = destroy_attribute,

	-- entity
	remove = remove_entity_archetype,
	get_attributes = get_entity_attributes,
	has_some_attribute = entity_has_some_attribute,
	has_attribute = entity_has_attribute,
	is_a = entity_is_a,

	move_to_without = move_entity_to_without,
	move_to_with = move_entity_to_with,

	set = set_entity_archetype,
	get = get_entity_archetype,
}
