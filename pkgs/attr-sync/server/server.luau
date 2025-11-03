local attr = require './luau_packages/attr'
local get_attributes = attr.get_attributes
local id_source = attr.id_source
local new_id = attr.id
local id_for = attr.id

local sync = require './luau_packages/attr_sync'
local base_sync_attribute = sync.sync_attribute
local sync_serde_impl = sync.serde
local serialize = sync.serialize

-- defs
local function always_sync(subject: attr.id, receiver: attr.id)
	return true
end

local group_receivers = attr.refs()
local sync_group, group_syncing_entities = attr.ref()
local sync_filter = attr.any(always_sync)

local group_all_receivers = attr.any({} :: { client })
local group_receivers_set = attr.any({} :: any)

local receivers_set = {}
type set<T> = { [T]: true }

local client = attr.any((nil :: any) :: client)
type client = any

-- ensure attr.id(attribute) is the same for both sides
-- achieved if both requires component registry first than
-- another modules which potentially creates more components
type attribute_id = attr.id
type attributes = { [attribute_id]: unknown }

-- commands
local commands = {}

function commands.entity_added(receivers: { client }, entity: attr.id, source: attr.id_source, data: attributes) end
function commands.entity_removed(receivers: { client }, entity: attr.id) end

function commands.attribute_changed(receivers: { client }, entity: attr.id, attribute: attr.id, value: unknown) end
function commands.attribute_removed(receivers: { client }, entity: attr.id, attribute: attr.id) end

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
		if should_sync ~= nil then attributes[attribute_id] = get_serialized_value(id, attribute_id) end
	end
	return attributes
end
local function get_delta_set<T>(prev_set: set<T>, new_set: set<T>, new_arr: { T }): ({ T }, { T })
	local removed, added = {}, {}

	for _, receiver in new_arr do
		if prev_set[receiver] == nil then table.insert(added, receiver) end
	end
	for receiver in prev_set do
		if new_set[receiver] == nil then table.insert(removed, receiver) end
	end

	return removed, added
end

-- functions
local function destroy_group(group_id: attr.id)
	for id in group_receivers:iter(group_id) do
		receivers_set[id] = nil
	end
end
local function bind_sync_group(group: attr.key)
	local all_receivers = {}
	local receivers_set = {}

	group_all_receivers:set(group, all_receivers)
	group_receivers_set:set(group, receivers_set)

	attr.on_destroy(group, destroy_group)
	attr.on_add(group_receivers:of(group), function(id): ()
		local receiver = client:assert(id)
		local new_receiver = { receiver }

		-- todo: batch request
		for id in group_syncing_entities:of(group):iter() do
			commands.entity_added(new_receiver, id, id_source(id), serialize_synced_attributes(id))
		end

		receivers_set[receiver] = true
		table.insert(all_receivers, receiver)
	end)
	attr.on_remove(group_receivers:of(group), function(id): ()
		local receiver = client:assert(id)
		receivers_set[receiver] = nil

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
local function sync_attribute<T>(attribute: attr.attr<T>, serde_impl: sync.serde_impl<T>?)
	sync_filter:set(attribute, always_sync)
	base_sync_attribute(attribute, serde_impl)

	attr.on_add(sync_group + attribute, function(id, group, value): ()
		local ser_value = if serde_impl ~= nil then serialize(id, serde_impl :: any, value) else value
		commands.attribute_changed(group_all_receivers:assert(group), id, id_for(attribute), ser_value)
	end)
	attr.on_change(attribute, function(id: attr.id, value): ()
		local group = sync_group:find(id)
		if not group then return end

		local ser_value = if serde_impl ~= nil then serialize(id, serde_impl :: any, value) else value
		commands.attribute_changed(group_all_receivers:assert(group), id, id_for(attribute), ser_value)
	end)
	attr.on_remove(sync_group + attribute, function(id, group): ()
		commands.attribute_removed(group_all_receivers:assert(group), id, (id_for(attribute)))
	end)
end

-- traits
local function group_changed(id: attr.id, group_id: attr.id): ()
	local new_receivers = group_all_receivers:assert(group_id)
	local new_receivers_set = group_receivers_set:assert(group_id)

	local prev_receivers_set = receivers_set[id]
	local removed, added = {}, new_receivers

	if prev_receivers_set then
		removed, added = get_delta_set(prev_receivers_set, new_receivers_set, new_receivers)
	end

	local attributes = serialize_synced_attributes(id)
	receivers_set[id] = new_receivers_set

	commands.entity_added(added, id, id_source(id), attributes)
	commands.entity_removed(removed, id)
end

attr.on_change(sync_group, group_changed :: any)
attr.on_add(sync_group, group_changed :: any)

-- module
return table.freeze {
	everyone = everyone,
	commands = commands,

	receivers = group_receivers,
	group = sync_group,
	client = client,

	sync_attribute = sync_attribute,
	bind_group = bind_sync_group,
	new_group = new_sync_group,
}
