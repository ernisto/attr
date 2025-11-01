local attr = require '../../lib'

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
local function queue_entity_added(
	receivers: { receiver },
	entity: attr.id,
	source: attr.id_source,
	attributes: { [attr.id]: unknown }
)
end
local function queue_entity_removed(receivers: { receiver }, entity: attr.id) end

local function queue_component_changed(reicevers: { receiver }, entity: attr.id, attr: attr.id, value: unknown) end
local function queue_component_removed(reicevers: { receiver }, entity: attr.id, attr: attr.id, value: unknown) end

-- helpers
local function sync_added_entity(id: attr.id, receiver_receivers: { receiver })
	local attribute_ids = attr.get_attributes(id)
	local attributes = {}

	for _, attribute_id in attribute_ids do
		local should_sync = sync_filter:find(attribute_id)
		if should_sync == nil then continue end

		local storage = attr.id_source(attribute_id) :: attr.attr<any>
		attributes[attribute_id] = storage:find(id)
	end
	queue_entity_added(receiver_receivers, id, attr.id_source(id), attributes)
end
local function sync_removed_entity(id: attr.id, receiver_receivers: { receiver })
	queue_entity_removed(receiver_receivers, id)
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
			sync_added_entity(id, { receiver })
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
	local group_id = attr.id()
	bind_sync_group(group_id)
	return group_id
end

local everyone = new_sync_group()
local function sync_attribute(attribute: attr.attr<any>)
	sync_filter:set(attribute, always_sync)

	attr.on_add(sync_group + attribute, function(id, group, value): ()
		queue_component_changed(group_all_receivers:assert(group), id, attr.id(attribute), value)
	end)
	attr.on_change(attribute, function(id: attr.id, value): ()
		local group = sync_group:find(id)
		if not group then return end

		queue_component_changed(group_all_receivers:assert(group), id, attr.id(attribute), value)
	end)
	attr.on_remove(sync_group + attribute, function(id, group): ()
		queue_component_removed(group_all_receivers:assert(group), id, attr.id(attribute) :: any)
	end)
end

-- traits
local function group_changed(id, group_id)
	local new_receivers = group_all_receivers:assert(group_id)
	local new_receivers_set, removed, added = get_delta_set(prev_receivers_set[id] or {}, new_receivers)

	sync_added_entity(id, added)
	sync_removed_entity(id, removed)

	prev_receivers_set[id] = new_receivers_set
end

attr.on_change(sync_group, group_changed)
attr.on_add(sync_group, group_changed)

-- module
return table.freeze {
	everyone = everyone,
	group = sync_group,
	sync_attribute = sync_attribute,
	new_sync_group = new_sync_group,
}
