local utils = require './utils'
local ordered_remove = utils.ordered_remove
local ordered_insert = utils.ordered_insert
local ordered_find = utils.ordered_find

local key = require './key'
local with_removed = key.pre_allocated_storage() -- [attribute]: archetype
local with_added = key.pre_allocated_storage() -- [attribute]: archetype
local attributes = key.pre_allocated_storage() -- ordered { entity }
local ensure_id = key.ensure_id

-- defs
type archetype_id = key.id
type attribute_id = key.id
type entity_id = key.id

-- vars
local archetype_by_attribute_amount = {}
local archetypes_with_transition_of = {}

-- functions
local function has_attribute(archetype: archetype_id, required: attribute_id)
	return ordered_find(attributes[archetype], required) ~= nil
end
local function has_some_attribute(archetype: archetype_id, map: { [attribute_id]: true })
	for _, attribute in attributes[archetype] do
		if map[attribute] then return true end
	end
	return false
end
local function match_attributes(attributes: { attribute_id }, required_attributes: { attribute_id }): boolean
	local match_goal = #required_attributes
	if #attributes <= match_goal then return false end

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
local function match_only_1_extra_attribute(
	extra_attributes: { attribute_id },
	required_attributes: { attribute_id }
): attribute_id?
	local matching_index = 1
	local extra: attribute_id?

	for _, attr in extra_attributes do
		local required_attr = required_attributes[matching_index]
		if attr == required_attr then
			matching_index += 1
			continue
		end
		if extra then return end
		extra = attr
	end
	return extra
end

local function bind_transitions(
	archetype: archetype_id,
	from_small_archetype: archetype_id?,
	from_big_archetype: archetype_id?
)
	local this_attributes = attributes[archetype]
	local removes = with_removed[archetype]
	local adds = with_added[archetype]
	local attributes_amount = #this_attributes

	archetype_by_attribute_amount[attributes_amount] = archetype_by_attribute_amount[attributes_amount] or {}
	table.insert(archetype_by_attribute_amount[attributes_amount], archetype)

	local smaller_archetypes = archetype_by_attribute_amount[attributes_amount - 1]
	if smaller_archetypes and (not from_small_archetype or #smaller_archetypes > 1) then
		for _, small_archetype in smaller_archetypes do
			if small_archetype == from_small_archetype then continue end

			local missing_attribute = match_only_1_extra_attribute(this_attributes, attributes[small_archetype])
			if not missing_attribute then continue end

			removes[missing_attribute] = small_archetype
			with_added[small_archetype][missing_attribute] = archetype

			table.insert(archetypes_with_transition_of[missing_attribute], archetype)
		end
	end

	local bigger_archetypes = archetype_by_attribute_amount[attributes_amount + 1]
	if bigger_archetypes == nil then return end
	if from_big_archetype and #bigger_archetypes == 1 then return end

	for _, big_archetype in bigger_archetypes do
		if big_archetype == from_big_archetype then continue end

		local extra_attribute = match_only_1_extra_attribute(attributes[big_archetype], this_attributes)
		if not extra_attribute then continue end

		with_removed[big_archetype][extra_attribute] = archetype
		adds[extra_attribute] = big_archetype

		table.insert(archetypes_with_transition_of[extra_attribute], big_archetype)
	end
end
local function bind_transition(base_archetype: archetype_id, attribute: attribute_id, next_archetype: archetype_id)
	with_added[base_archetype][attribute] = next_archetype
	with_removed[next_archetype][attribute] = base_archetype
end

local function next_archetype_with(base_archetype: archetype_id?, new_attribute: attribute_id): archetype_id
	local existing = if base_archetype
		then with_added[base_archetype][new_attribute]
		elseif attributes[new_attribute] then new_attribute
		else nil
	if existing then return existing end

	local archetype = if base_archetype then ensure_id() else new_attribute
	local this_attributes = if base_archetype then table.clone(attributes[base_archetype]) else {}

	ordered_insert(this_attributes, new_attribute)
	attributes[archetype] = table.freeze(this_attributes)

	with_removed[archetype] = { [new_attribute] = base_archetype }
	with_added[archetype] = {}

	if archetypes_with_transition_of[new_attribute] == nil then
		archetypes_with_transition_of[new_attribute] = { new_attribute }
	end

	bind_transitions(archetype, base_archetype)
	if base_archetype == nil then return archetype end

	with_added[base_archetype][new_attribute] = archetype
	table.insert(archetypes_with_transition_of[new_attribute], archetype)

	return archetype
end
local function next_archetype_without(base_archetype: archetype_id, prev_attribute: attribute_id): archetype_id?
	local existing = with_removed[base_archetype][prev_attribute]
	if existing then return existing end
	if #attributes[base_archetype] == 1 then return nil end

	local archetype = ensure_id()
	local this_attributes = table.clone(attributes[base_archetype])

	ordered_remove(this_attributes, prev_attribute)
	attributes[archetype] = table.freeze(this_attributes)

	with_removed[archetype] = {}
	with_added[archetype] = { [prev_attribute] = base_archetype }

	bind_transitions(archetype, nil, base_archetype)

	with_removed[base_archetype][prev_attribute] = archetype
	table.insert(archetypes_with_transition_of[prev_attribute], base_archetype)

	return archetype
end

local function iter_smaller_archetypes(archetype: archetype_id, with: { [attribute_id]: true }?): () -> archetype_id?
	local already_queued = { [archetype] = true }
	local pending = { archetype }
	local index = 1

	local this_attributes = attributes[archetype]
	for _, attribute in this_attributes do
		if archetypes_with_transition_of[attribute] == nil then continue end
		for _, next_archetype in archetypes_with_transition_of[attribute] do
			if not match_attributes(this_attributes, attributes[next_archetype]) then continue end
			if already_queued[next_archetype] then continue end
			already_queued[next_archetype] = true
			table.insert(pending, next_archetype)
		end
	end

	return function()
		local compatible_archetype = pending[index]
		if compatible_archetype == nil then return nil :: any end

		for removed_attr, new_archetype in with_removed[compatible_archetype] do
			if with and with[removed_attr] then continue end
			if already_queued[new_archetype] then continue end
			already_queued[new_archetype] = true
			table.insert(pending, new_archetype)
		end
		index += 1
		return compatible_archetype
	end
end
local function iter_bigger_archetypes(archetype: archetype_id, without: { [attribute_id]: true }?): () -> archetype_id?
	local already_queued = { [archetype] = true }
	local pending = { archetype }
	local index = 1

	local this_attributes = attributes[archetype]
	for _, attribute in this_attributes do
		if archetypes_with_transition_of[attribute] == nil then continue end
		for _, next_archetype in archetypes_with_transition_of[attribute] do
			if not match_attributes(attributes[next_archetype], this_attributes) then continue end
			if already_queued[next_archetype] then continue end
			already_queued[next_archetype] = true
			table.insert(pending, next_archetype)
		end
	end

	return function()
		local compatible_archetype = pending[index]
		if compatible_archetype == nil then return nil :: any end

		for added_attr, new_archetype in with_added[compatible_archetype] do
			if without and without[added_attr] then continue end
			if already_queued[new_archetype] then continue end
			already_queued[new_archetype] = true
			table.insert(pending, new_archetype)
		end
		index += 1
		return compatible_archetype
	end
end

local function with_attr(...: attribute_id): archetype_id
	local archetype = nil :: any
	for _, next_attribute in { ... } do
		archetype = next_archetype_with(archetype, next_attribute)
	end
	return archetype
end
local function unbind_transitions(arch: archetype_id)
	for attribute, prev_arch in with_removed[arch] do
		with_added[prev_arch][attribute] = nil
		local attribute_transitions = archetypes_with_transition_of[attribute]

		local index = table.find(attribute_transitions, arch)
		table.remove(attribute_transitions, index)
	end
	for attribute, next_arch in with_added[arch] do
		with_removed[next_arch][attribute] = nil
	end

	local archetypes_with_same_attributes_amount = archetype_by_attribute_amount[#attributes[arch]]
	local index = table.find(archetypes_with_same_attributes_amount, arch)
	table.remove(archetypes_with_same_attributes_amount, index)

	with_removed[arch] = nil
	with_added[arch] = nil
	attributes[arch] = nil
end

-- module
return table.freeze {
	get_only_1_extra_attribute = match_only_1_extra_attribute,
	match_attributes = match_attributes,
	has_some_attribute = has_some_attribute,
	has_attribute = has_attribute,
	attributes = attributes,

	next_archetype_without = next_archetype_without,
	next_archetype_with = next_archetype_with,

	bind_transitions = bind_transitions,
	bind_transition = bind_transition,

	iter_smaller_archetypes = iter_smaller_archetypes,
	iter_bigger_archetypes = iter_bigger_archetypes,

	with_attr = with_attr,
	unbind_transitions = unbind_transitions,
}
