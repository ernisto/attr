local key = require('./key')
local current_archetype = key.pre_allocated_storage() -- archetype
local head_id = key.pre_allocated_storage()
local next_id = key.pre_allocated_storage()
local prev_id = key.pre_allocated_storage()

local graph = require('@self/graph')
local next_archetype_without = graph.next_archetype_without
local next_archetype_with = graph.next_archetype_with
local attributes = graph.attributes

-- defs
type archetype_id = key.id
type attribute_id = key.id
type entity_id = key.id

-- functions
local function iter_entities(archetype: archetype_id, exclude: { [attribute_id]: true }?): () -> key.id?
	local next_compatible_archetype = graph.iter_bigger_archetypes(archetype, exclude)
	local next_entity = head_id[archetype]

	next_compatible_archetype()
	return function()
		if next_entity == nil then return nil end

		local entity = next_entity
		next_entity = next_id[next_entity]

		while next_entity == nil do
			local next_archetype = next_compatible_archetype()
			if next_archetype == nil then break end

			next_entity = head_id[next_archetype]
		end
		return entity
	end
end
local function get_archetype_with(...: attribute_id): archetype_id
	local archetype = nil :: any
	for _, next_attribute in { ... } do
		archetype = graph.next_archetype_with(archetype, next_attribute)
	end
	return archetype
end

local function remove_archetype_entity(archetype: archetype_id, id: entity_id)
	local prev = prev_id[id]
	local next = next_id[id]
	if prev then
		next_id[prev] = next
	else
		head_id[archetype] = next
	end
	if next then prev_id[next] = prev end
end
local function add_archetype_entity(archetype: archetype_id, id: entity_id)
	local prev_head = head_id[archetype]
	head_id[archetype] = id
	prev_id[id] = nil

	if prev_head then prev_id[prev_head] = id end
	next_id[id] = prev_head
end

local function set_entity_archetype(id: entity_id, new_archetype: archetype_id?, prev_archetype: archetype_id?)
	if prev_archetype ~= nil then remove_archetype_entity(prev_archetype, id) end
	if new_archetype ~= nil then add_archetype_entity(new_archetype, id) end
	current_archetype[id] = new_archetype :: any
end
local function get_entity_archetype(id: entity_id): archetype_id?
	return current_archetype[id]
end

local function move_entity_to_with(id: entity_id, added: attribute_id)
	local prev_archetype = get_entity_archetype(id)
	local new_archetype = next_archetype_with(prev_archetype, added)
	set_entity_archetype(id, new_archetype, prev_archetype)
	return new_archetype
end
local function move_entity_to_without(id: entity_id, removed: attribute_id)
	local prev_archetype = get_entity_archetype(id)
	if prev_archetype == nil then return end

	local new_archetype = next_archetype_without(prev_archetype, removed)
	set_entity_archetype(id, new_archetype, prev_archetype)
end

local function entity_is_a(id: entity_id, base_archetype: archetype_id): boolean
	local archetype = current_archetype[id]
	if archetype == nil then return false end
	if archetype == base_archetype then return true end

	return graph.match_attributes(attributes[archetype], attributes[base_archetype])
end
local function get_entity_attrs(id: entity_id): { attribute_id }
	local archetype = current_archetype[id]
	return if archetype then attributes[archetype] else {}
end

local function remove_entity_archetype(id: entity_id)
	local archetype = current_archetype[id]
	if archetype == nil then return end

	for _, attribute in attributes[archetype] do
		local data = assert(key.id_sources[attribute] :: any)
		data:remove(id)
	end
	set_entity_archetype(id, nil, archetype)
end

-- module
return table.freeze {
	iter_smaller_archetypes = graph.iter_smaller_archetypes,
	iter_bigger_archetypes = graph.iter_bigger_archetypes,

	iter_entities = iter_entities,
	with_attr = get_archetype_with,

	attributes = attributes,

	-- entity
	remove = remove_entity_archetype,
	get_attrs = get_entity_attrs,
	is_a = entity_is_a,

	move_to_without = move_entity_to_without,
	move_to_with = move_entity_to_with,

	set = set_entity_archetype,
	get = get_entity_archetype,
}
