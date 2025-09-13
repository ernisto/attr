local attr = require('../../lib')
local serde = require('./serde')

local handler_attribute = attr.any(nil :: any)
local saving_attributes = attr.refs('key')
local saving_N_handlers = attr.refs('key')
local saving_1_handlers = attr.refs('key')
local saving_serde = attr.any({} :: serde.property)

export type data = { [attr.id]: { [attr_key]: any } }
export type attr_key = string

-- functions
local function include_attr(handler: attr.id, attribute: attr.attr<any>, key: attr_key)
	saving_attributes:set(handler, attr.id(attribute), key)
end
local function include_ids(handler: attr.id, attribute: attr.linkN_attr<any>, key: attr_key): attr.id
	local child_handler = attr.id()
	handler_attribute:set(child_handler, attribute)
	saving_N_handlers:set(handler, child_handler, key)
	return child_handler
end
local function include_id(handler: attr.id, attribute: attr.link1_attr<any>, key: attr_key): attr.id
	local child_handler = attr.id()
	handler_attribute:set(child_handler, attribute)
	saving_1_handlers:set(handler, child_handler, key)
	return child_handler
end

local function save(root_handler: attr.id, root: attr.id): data
	local internal_ids = { [root] = 1 }
	local data = {}

	local pending_handlers = { root_handler }
	local pending_ids = { root }

	local entities_count = 1
	local function get_internal_id(real_id)
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

		for attribute, key in saving_attributes:all(handler) do
			if entity_data[key] ~= nil then continue end
			local attr_serde = saving_serde:find(attribute)

			local value = assert(attr.id_source(attribute)):find(real_id)
			entity_data[key] = if attr_serde then serde.serialize(real_id, attr_serde, value) else value
		end

		for sub_handler_id, key in saving_1_handlers:all(handler) do
			if entity_data[key] ~= nil then continue end
			local attribute = handler_attribute:assert(sub_handler_id)

			local target_id = attribute:find(real_id)
			if target_id == nil then continue end

			entity_data[key] = get_internal_id(target_id)
			table.insert(pending_handlers, sub_handler_id)
			table.insert(pending_ids, target_id)
		end

		for sub_handler_id, key in saving_N_handlers:all(handler) do
			if entity_data[key] ~= nil then continue end
			local attribute = handler_attribute:assert(sub_handler_id)

			local attr_data = {}
			entity_data[key] = attr_data

			for target_id in attribute:all(real_id) do
				table.insert(attr_data, get_internal_id(target_id))
				table.insert(pending_handlers, sub_handler_id)
				table.insert(pending_ids, target_id)
			end
		end
	end
	return data
end
local function load(root_handler: attr.id, data: data, root: attr.id?): { attr.id }
	local real_ids = { root :: attr.id }
	for internal_id in data do
		real_ids[internal_id] = real_ids[internal_id] or attr.id()
	end

	local pending_ids = { 1 }
	local pending_handler_id = { root_handler }
	for index, internal_id in pending_ids do
		local handler_id = pending_handler_id[index]
		local real_id = real_ids[internal_id]
		local entity_data = data[internal_id] or {}

		for attribute, key in saving_attributes:all(handler_id) do
			local attr_serde = saving_serde:find(attribute)
			local value = entity_data[key] or attr_serde and attr_serde.default and attr_serde.default(real_id)

			if value == nil then continue end
			local attr_value = if attr_serde then serde.deserialize(real_id, attr_serde, value) else value

			assert(attr.id_source(attribute)):set(real_id, attr_value)
			entity_data[key] = nil
		end

		for sub_handler_id, key in saving_1_handlers:all(handler_id) do
			local value = entity_data[key]
			if type(value) ~= 'number' then continue end

			local attribute = handler_attribute:assert(sub_handler_id)
			local target_id = real_ids[value]

			table.insert(pending_handler_id, sub_handler_id)
			table.insert(pending_ids, value)

			attribute:set(real_id, target_id, true)
			entity_data[key] = nil
		end

		for sub_handler_id, key in saving_N_handlers:all(handler_id) do
			local value = entity_data[key]
			if type(value) ~= 'table' then continue end

			local attribute = handler_attribute:assert(sub_handler_id)
			for _, target in value do
				local target_id = real_ids[target]
				attribute:set(real_id, target_id, true)

				table.insert(pending_handler_id, sub_handler_id)
				table.insert(pending_ids, target)
			end
			entity_data[key] = nil
		end
	end
	return real_ids
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
