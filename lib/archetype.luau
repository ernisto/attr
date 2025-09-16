local utils = require('./utils')
local ordered_remove = utils.ordered_remove
local ordered_insert = utils.ordered_insert

local key = require('./key')
local current_archetype = key.pre_allocated_storage() -- archetype
local with_removed = key.pre_allocated_storage() -- [attribute]: archetype
local with_added = key.pre_allocated_storage() -- [attribute]: archetype
local attributes = key.pre_allocated_storage() -- ordered { entity }
local ids = key.pre_allocated_storage() -- ordered { entity }

-- defs
type archetype_id = key.id
type attribute_id = key.id
type entity_id = key.id

-- vars
local by_depth = {}

-- functions
-- returns nil if theres more than 1 missing attribute
-- which means no direct transition between those archetypes
local function get_only_1_missing_attribute(
	bigger_attributes: { attribute_id },
	smaller_attributes: { attribute_id }
): attribute_id?
	-- both arrays are sorted; return the single element that exists in bigger but not in smaller
	if #bigger_attributes ~= #smaller_attributes + 1 then return end

	local i = 1
	local j = 1
	local missing: attribute_id?

	while i <= #bigger_attributes and j <= #smaller_attributes do
		local big_attr = bigger_attributes[i]
		local small_attr = smaller_attributes[j]

		if big_attr == small_attr then
			i += 1
			j += 1
		else
			if missing ~= nil then return end
			missing = big_attr
			i += 1
		end
	end

	-- if we finished smaller without finding a diff, the last element is the extra
	if j <= #smaller_attributes then return end
	if missing == nil then missing = bigger_attributes[#bigger_attributes] end
	return missing
end
local function match_attributes(attributes: { attribute_id }, required_attributes: { attribute_id }): boolean
	local match_goal = #required_attributes
	if #attributes < match_goal then return false end

	local match_count = 0
	local next_required = required_attributes[1]

	for i, attribute in attributes do
		if attribute > next_required then return false end
		match_count += if attribute == next_required then 1 else 0

		if match_count == match_goal then return true end
		next_required = required_attributes[match_count + 1]
	end
	return false
end

local function bind_transitions(archetype: archetype_id)
	local this_attributes = attributes[archetype]
	local depth = #this_attributes
	local removes = {}
	local adds = {}

	by_depth[depth] = by_depth[depth] or {}
	table.insert(by_depth[depth], archetype)

	with_removed[archetype] = removes
	with_added[archetype] = adds

	for _, small_archetype in by_depth[depth - 1] or {} :: any do
		local missing_attribute = get_only_1_missing_attribute(this_attributes, attributes[small_archetype])
		if not missing_attribute then continue end

		removes[missing_attribute] = small_archetype
		with_added[small_archetype][missing_attribute] = archetype
	end

	if by_depth[depth + 1] == nil then return end
	for _, big_archetype in by_depth[depth + 1] do
		local extra_attribute = get_only_1_missing_attribute(attributes[big_archetype], this_attributes)
		if not extra_attribute then continue end

		with_removed[big_archetype][extra_attribute] = archetype
		adds[extra_attribute] = big_archetype
	end
end
local function next_archetype_with(base_archetype: archetype_id?, new_attribute: attribute_id): archetype_id
	local existing = if base_archetype
		then with_added[base_archetype][new_attribute]
		elseif ids[new_attribute] then new_attribute
		else nil
	if existing then return existing end

	local archetype = if base_archetype then key.ensure_id() else new_attribute
	local this_attributes = if base_archetype == nil then {} else table.clone(attributes[base_archetype])

	ordered_insert(this_attributes, new_attribute)
	attributes[archetype] = table.freeze(this_attributes)
	ids[archetype] = {}

	bind_transitions(archetype)
	return archetype
end
local function next_archetype_without(base_archetype: archetype_id, prev_attribute: attribute_id): archetype_id
	local existing = with_removed[base_archetype][prev_attribute]
	if existing then return existing end

	local archetype = key.ensure_id()
	local this_attributes = table.clone(attributes[base_archetype])

	ordered_remove(this_attributes, prev_attribute)
	attributes[archetype] = table.freeze(this_attributes)
	ids[archetype] = {}

	bind_transitions(archetype)
	return archetype
end

local function iter_smaller_archetypes(archetype: archetype_id, with: { [attribute_id]: true }?): () -> archetype_id?
	local pending = { archetype }
	local index = 1

	return function()
		local compatible_archetype = pending[index]
		if compatible_archetype == nil then return nil :: any end

		for removed_attr, new_archetype in with_removed[compatible_archetype] do
			if with and with[removed_attr] then continue end
			table.insert(pending, new_archetype)
		end
		index += 1
		return compatible_archetype
	end
end
local function iter_bigger_archetypes(archetype: archetype_id, without: { [attribute_id]: true }?): () -> archetype_id?
	local pending = { archetype }
	local index = 1

	return function()
		local compatible_archetype = pending[index]
		if compatible_archetype == nil then return nil :: any end

		for added_attr, new_archetype in with_added[compatible_archetype] do
			if without and without[added_attr] then continue end
			table.insert(pending, new_archetype)
		end
		index += 1
		return compatible_archetype
	end
end

local function iter_entities(archetype: archetype_id, exclude: { [attribute_id]: true }?): () -> key.id?
	local next_compatible_archetype = iter_bigger_archetypes(archetype, exclude)
	local last_index = 0
	local index = 0
	local entities

	return function()
		while index == last_index do
			local next_archetype = next_compatible_archetype()
			if next_archetype == nil then return nil :: any end

			entities = ids[next_archetype]
			last_index = #entities
			index = 0
		end

		index += 1
		return entities[index]
	end
end
local function get_archetype_with(...: attribute_id): archetype_id
	local archetype = nil :: any
	for _, next_attribute in { ... } do
		archetype = next_archetype_with(archetype, next_attribute)
	end
	return archetype
end

local function set_entity_archetype(id: entity_id, new_archetype: archetype_id?, prev_archetype: archetype_id?)
	if new_archetype ~= nil then ordered_insert(ids[new_archetype], id) end
	if prev_archetype ~= nil then ordered_remove(ids[prev_archetype], id) end
	current_archetype[id] = new_archetype :: any
end
local function get_entity_archetype(id: entity_id): archetype_id?
	return current_archetype[id]
end

local function move_entity_to_with(id: entity_id, added: attribute_id)
	local prev_archetype = get_entity_archetype(id)
	local new_archetype = next_archetype_with(prev_archetype, added)
	set_entity_archetype(id, new_archetype, prev_archetype)
end
local function move_entity_to_without(id: entity_id, removed: attribute_id)
	local prev_archetype = get_entity_archetype(id)
	if prev_archetype == nil then return end

	local new_archetype = next_archetype_without(prev_archetype, removed)
	set_entity_archetype(id, new_archetype, prev_archetype)
end

local function get_entity_attrs(id: entity_id): { attribute_id }
	local archetype = current_archetype[id]
	return if archetype then attributes[archetype] else {}
end
local function entity_is_a(id: entity_id, base_archetype: archetype_id): boolean
	local archetype = current_archetype[id]
	if archetype == nil then return false end
	if archetype == base_archetype then return true end

	return match_attributes(attributes[archetype], attributes[base_archetype])
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
	iter_smaller_archetypes = iter_smaller_archetypes,
	iter_bigger_archetypes = iter_bigger_archetypes,

	iter_entities = iter_entities,
	with_attr = get_archetype_with,

	-- entity
	remove = remove_entity_archetype,
	get_attrs = get_entity_attrs,
	is_a = entity_is_a,

	move_to_without = move_entity_to_without,
	move_to_with = move_entity_to_with,

	set = set_entity_archetype,
	get = get_entity_archetype,
}
