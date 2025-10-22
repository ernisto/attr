local attr = require '../../lib'
local serde = require './serde'

local handler_attribute = attr.any(nil :: any)
local save_key = attr.any('key')
local saving_attributes = attr.refs()
local saving_N_handlers = attr.refs()
local saving_1_handlers = attr.refs()
local saving_serde = attr.any({} :: serde.property)

export type data = { [attr.id]: { [attr_key]: any } }
export type attr_key = string

-- functions
local function include_attr<T>(handler: attr.id, attribute: attr.attr<T>, key: attr_key, serde: serde.property<T>?)
	saving_attributes:add(handler, attribute)
	save_key:set(attribute, key)

	if not serde then return end
	saving_serde:set(attribute, serde)
end
local function include_ids(handler: attr.id, attribute: attr.linkN_attr, key: attr_key): attr.id
	local child_handler = attr.id()
	saving_N_handlers:add(handler, child_handler)
	handler_attribute:set(child_handler, attribute)
	save_key:set(child_handler, key)
	return child_handler
end
local function include_id(handler: attr.id, attribute: attr.link1_attr, key: attr_key): attr.id
	local child_handler = attr.id()
	saving_1_handlers:add(handler, child_handler)
	handler_attribute:set(child_handler, attribute)
	save_key:set(child_handler, key)
	return child_handler
end

local function save(root_handler: attr.id, root_key: attr.key): data
	local _, root = attr.id(root_key)
	local internal_ids = { [root] = 1 }
	local data = {}

	local pending_handlers = { root_handler }
	local pending_ids = { root }

	local entities_count = 1
	local function get_internal_id(real_id: attr.tracked_id): number
		local internal_id = internal_ids[real_id]
		if internal_id then return internal_id end

		entities_count += 1
		internal_id = entities_count

		internal_ids[real_id] = internal_id
		return internal_id :: any
	end

	for index, real_id in pending_ids do
		local internal_id = get_internal_id(real_id)
		local handler = pending_handlers[index]

		local entity_data = data[internal_id] or {}
		data[internal_id] = entity_data

		for _, attribute_id in saving_attributes:all(handler) do
			local key = save_key:assert(attribute_id)
			if entity_data[key] ~= nil then continue end
			local attr_serde = saving_serde:find(attribute_id)

			local value = assert(attr.id_source(attribute_id)):find(real_id)
			entity_data[key] = if attr_serde then serde.serialize(real_id, attr_serde, value) else value
		end

		for _, sub_handler_id in saving_1_handlers:all(handler) do
			local key = save_key:assert(sub_handler_id)
			if entity_data[key] ~= nil then continue end
			local attribute = handler_attribute:assert(sub_handler_id)

			local target_id = attribute:find(real_id)
			if target_id == nil then continue end

			entity_data[key] = get_internal_id(target_id)
			table.insert(pending_handlers, sub_handler_id)
			table.insert(pending_ids, target_id)
		end

		for _, sub_handler_id in saving_N_handlers:all(handler) do
			local key = save_key:assert(sub_handler_id)
			if entity_data[key] ~= nil then continue end
			local attribute = handler_attribute:assert(sub_handler_id)

			local attr_data = {}
			entity_data[key] = attr_data

			for target_id in attribute:iter(real_id) do
				table.insert(attr_data, get_internal_id(target_id))
				table.insert(pending_handlers, sub_handler_id)
				table.insert(pending_ids, target_id)
			end
		end
	end
	return data
end
local function load(root_handler: attr.id, data: data, root_key: attr.key?): { attr.id }
	local root_id, root = attr.id(root_key)
	local real_ids = { root_id }
	local tracked_real_ids = { root }

	for internal_id in data do
		local id, tracked = attr.id()
		real_ids[internal_id] = id
		tracked_real_ids[internal_id] = tracked
	end

	local pending_ids = { 1 }
	local pending_handler_id = { root_handler }
	for index, internal_id in pending_ids do
		local handler_id = pending_handler_id[index]
		local real_id = real_ids[internal_id]
		local tracked_real_id = tracked_real_ids[internal_id]
		local entity_data = data[internal_id] or {}

		for _, attribute_id in saving_attributes:all(handler_id) do
			local key = save_key:assert(attribute_id)
			local attr_serde = saving_serde:find(attribute_id)
			local value = entity_data[key] or attr_serde and attr_serde.default and attr_serde.default(tracked_real_id)

			if value == nil then continue end
			local attr_value = if attr_serde then serde.deserialize(tracked_real_id, attr_serde, value) else value

			assert(attr.id_source(attribute_id)):set(real_id, attr_value)
			entity_data[key] = nil
		end

		for _, sub_handler_id in saving_1_handlers:all(handler_id) do
			local key = save_key:assert(sub_handler_id)
			local value = entity_data[key]
			if type(value) ~= 'number' then continue end

			local attribute = handler_attribute:assert(sub_handler_id)
			local target_id = real_ids[value]

			table.insert(pending_handler_id, sub_handler_id)
			table.insert(pending_ids, value)

			attribute:set(real_id, target_id)
			entity_data[key] = nil
		end

		for _, sub_handler_id in saving_N_handlers:all(handler_id) do
			local key = save_key:assert(sub_handler_id)
			local value = entity_data[key]
			if type(value) ~= 'table' then continue end

			local attribute = handler_attribute:assert(sub_handler_id)
			for _, target in value do
				local target_id = real_ids[target]
				attribute:add(real_id, target_id)

				table.insert(pending_handler_id, sub_handler_id)
				table.insert(pending_ids, target)
			end
			entity_data[key] = nil
		end
	end
	return tracked_real_ids
end

-- module
return table.freeze {
	include_attr = include_attr,
	include_ids = include_ids,
	include_id = include_id,
	serde = saving_serde,
	load = load,
	save = save,
}
