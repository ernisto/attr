local attr = require '@lib'
local id_source = attr.id_source
local destroy = attr.destroy
local id_for = attr.id
local new_id = attr.id

local serde = require './serde'
local deserialize = serde.deserialize

local shared = require './shared'
local sync_serde_impl = shared.serde

-- vars
local client_ids = {}
local server_ids = attr.any(0)

-- helpers
local function ensure_client_id_for(server_id: attr.id, source: attr.key?): attr.id
	if client_ids[server_id] then return client_ids[server_id] end

	local client_id = if source then id_for(source) else new_id()
	client_ids[server_id] = client_id

	server_ids:set(client_id, server_id)
	return client_id
end
local function apply_link(client_id, attribute: attr.link1_attr, target_server_id: attr.id)
	target_server_id = id_for(target_server_id)

	local target_client_id = client_ids[target_server_id]
	if not target_client_id then
		print(`[warn] client#{client_id} linking '{attribute}' to a id server#{target_server_id} didnt replicated yet`)
	end

	target_client_id = ensure_client_id_for(target_server_id)
	attribute:set(client_id, target_client_id)
end

local function apply_deserialized_value(client_id, attr_id: attr.id, serialized_value: unknown)
	local attribute = assert(id_source(attr_id) :: any)
	if attribute.kind == 'link1' then return apply_link(client_id, attribute, serialized_value :: any) end

	local serde_impl = sync_serde_impl:find(attribute)
	local value = if serde_impl then deserialize(client_id, serde_impl, serialized_value) else serialized_value

	attribute:set(client_id, value)
end

-- events
local function destroy_server_id(server_id: attr.id)
	destroy(client_ids[server_id])
end
local function create_server_id(server_id: attr.id, source: attr.id_source, attributes: { [attr.id]: unknown })
	local client_id = ensure_client_id_for(server_id, source)
	for attr_id, serialized_value in attributes do
		apply_deserialized_value(client_id, attr_id, serialized_value)
	end
	return client_id
end

local function change_attribute(server_id: attr.id, attr_id: attr.id, serialized_value: unknown)
	local client_id = client_ids[server_id]
	apply_deserialized_value(client_id, attr_id, serialized_value)
end
local function remove_attribute(server_id: attr.id, attr_id: attr.id, link_target: attr.id?)
	local attribute = assert(id_source(attr_id) :: any)
	attribute:remove(client_ids[server_id], link_target and client_ids[link_target])
end

attr.on_remove(server_ids, function(client_id, server_id): ()
	client_ids[server_id] = nil
end)

-- module
return table.freeze {
	destroy_server_id = destroy_server_id,
	create_server_id = create_server_id,
	remove_attribute = remove_attribute,
	change_attribute = change_attribute,
	server_id = server_ids,
}
