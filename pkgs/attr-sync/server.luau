local attr = require '@lib'
local get_attributes = attr.get_attributes
local id_source = attr.id_source
local new_id = attr.id
local id_for = attr.id

local serde = require './serde'
local serialize = serde.serialize

local shared = require './shared'
local base_sync_attribute = shared.sync_attribute
local sync_serde_impl = shared.serde

-- defs
local function always_sync(subject: attr.id, receiver: attr.id)
	return true
end

local group_all_receivers = attr.any({} :: { receiver })
local group_receivers = attr.refs()
local sync_group, group_syncing_entities = attr.ref()
local sync_filter = attr.any(always_sync)

local prev_receivers_set: { [attr.id]: set<receiver> } = {}
type set<T> = { [T]: true }

local raw_receiver = attr.any((nil :: any) :: receiver)
type receiver = {}

-- commands
-- ensure attr.id(attribute) is the same for both sides
-- achieved if both requires component registry first than
-- another modules which potentially creates more components
type attribute_id = attr.id
type attributes = { [attribute_id]: unknown }

local function queue_entity_added(
	receivers: { receiver },
	entity: attr.id,
	source: attr.id_source,
	data: attributes
)
end
local function queue_entity_removed(receivers: { receiver }, entity: attr.id) end

local function queue_attribute_changed(receivers: { receiver }, entity: attr.id, attribute: attr.id, value: unknown) end
local function queue_attribute_removed(receivers: { receiver }, entity: attr.id, attribute: attr.id, value: unknown) end

-- helpers
local function get_serialized_value(id: attr.id, attribute_id: attr.id)
	local storage = id_source(attribute_id) :: attr.attr<any>
	local value = storage:find(id)

	local impl = sync_serde_impl:find(attribute_id)
	return if impl then serialize(id, impl, value) else value
end
local function serialize_synced_attributes(id: attr.id): attributes
	local attribute_ids = get_attributes(id)
	local attributes = {}

	for _, attribute_id in attribute_ids do
		local should_sync = sync_filter:find(attribute_id)
		if should_sync == nil then continue end

		attributes[attribute_id] = get_serialized_value(id, attribute_id)
	end
	return attributes
end
local function get_delta_set(
	prev_set: set<receiver>,
	new_arr: { receiver }
): (set<receiver>, { receiver }, { receiver }, { receiver })
	local new_set = {}
	local removed = {}
	local added = {}
	local keept = {}

	for _, receiver in new_arr do
		if prev_set[receiver] == nil then
			table.insert(added, receiver)
		else
			table.insert(keept, receiver)
		end
		new_set[receiver] = true
	end
	for receiver in prev_set do
		if new_set[receiver] == nil then table.insert(removed, receiver) end
	end

	return new_set :: any, removed, added, keept
end

-- functions
local function destroy_group(group_id)
	for id in group_receivers:iter(group_id) do
		prev_receivers_set[id] = nil
	end
end
local function bind_sync_group(group: attr.key)
	local all_receivers = {}
	group_all_receivers:set(group, all_receivers)

	attr.on_destroy(group, destroy_group)
	attr.on_add(group_receivers:of(group), function(id): ()
		local receiver = raw_receiver:assert(id)
		for id in group_syncing_entities:of(group):iter() do
			queue_entity_added(all_receivers, id, id_source(id), serialize_synced_attributes(id))
		end

		table.insert(all_receivers, receiver)
	end)
	attr.on_remove(group_receivers:of(group), function(id): ()
		local receiver = raw_receiver:assert(id)

		local index = table.find(all_receivers, receiver)
		if index then table.remove(all_receivers, index) end
	end)
end
local function new_sync_group()
	local group_id = new_id()
	bind_sync_group(group_id)
	return group_id
end

local everyone = new_sync_group()
local function sync_attribute<T>(attribute: attr.attr<T>, serde_impl: serde.impl<T>?)
	sync_filter:set(attribute, always_sync)
	base_sync_attribute(attribute, serde_impl)

	attr.on_add(sync_group + attribute, function(id, group, value): ()
		local ser_value = if serde_impl ~= nil then serialize(id, serde_impl :: any, value) else value
		queue_attribute_changed(group_all_receivers:assert(group), id, id_for(attribute), ser_value)
	end)
	attr.on_change(attribute, function(id: attr.id, value): ()
		local group = sync_group:find(id)
		if not group then return end

		local ser_value = if serde_impl ~= nil then serialize(id, serde_impl :: any, value) else value
		queue_attribute_changed(group_all_receivers:assert(group), id, id_for(attribute), ser_value)
	end)
	attr.on_remove(sync_group + attribute, function(id, group): ()
		queue_attribute_removed(group_all_receivers:assert(group), id, id_for(attribute))
	end)
end

-- traits
local function group_changed(id, group_id)
	local new_receivers = group_all_receivers:assert(group_id)
	local new_receivers_set, removed, added = get_delta_set(prev_receivers_set[id] or {}, new_receivers)
	local attributes = serialize_synced_attributes(id)

	queue_entity_added(added, id, id_source(id), attributes)
	queue_entity_removed(removed, id)
	prev_receivers_set[id] = new_receivers_set
end

attr.on_change(sync_group, group_changed)
attr.on_add(sync_group, group_changed)

-- module
return table.freeze {
	everyone = everyone,

	receivers = group_receivers,
	group = sync_group,

	sync_attribute = sync_attribute,
	bind_group = bind_sync_group,
	new_group = new_sync_group,
}
