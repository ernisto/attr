local attr = require './luau_packages/attr'
local id_source = attr.id_source
local destroy = attr.destroy
local id_for = attr.id
local new_id = attr.id

local log = require './log'
local sync = require './luau_packages/attr_sync'
local deserialize = sync.deserialize
local sync_serde_impl = sync.serde

-- vars
local server_ids = attr.any(0)
local link_source = {} -- debug
local client_ids = {}

-- functions
local function find_client_id_for(server_id: attr.id, source: attr.key?): attr.id?
	local client_id = client_ids[server_id]
	if client_id == nil then return end

	if source ~= nil and client_id ~= id_for(source) then
		log.warn(
			log.messages.two_ids_with_same_source(client_id, server_id, id_for(source), source, link_source[client_id])
		)
	end
	return client_id
end
local function new_client_id_for(server_id: attr.id, source: attr.key?): attr.id
	local client_id = if source then id_for(source) else new_id()
	client_ids[server_id] = client_id

	server_ids:set(client_id, server_id)
	return client_id
end
local function ensure_client_id_for(server_id: attr.id, source: attr.key?): attr.id
	return find_client_id_for(server_id, source) or new_client_id_for(server_id, source)
end

local function apply_link(client_id, link: attr.link1_attr, target_server_id: attr.id)
	target_server_id = id_for(target_server_id)

	local existing_target_client_id = client_ids[target_server_id]
	local target_client_id = existing_target_client_id or ensure_client_id_for(target_server_id)

	if not existing_target_client_id then
		local server_id = server_ids[client_id]
		link_source[target_client_id] = `{server_id}/{client_id}.{link}`

		log.warn(
			log.messages.instance_linked_before_receive(client_id, server_id, target_client_id, target_server_id, link)
		)
	end

	link:set(client_id, target_client_id)
end

local function apply_deserialized_value(client_id, attr_id: attr.id, serialized_value: unknown)
	local attribute = assert(id_source(attr_id) :: any)
	if attribute.kind == 'link1' then return apply_link(client_id, attribute, serialized_value :: any) end

	local serde_impl = sync_serde_impl:find(attribute)
	local value = if serde_impl then deserialize(client_id, serde_impl, serialized_value :: any) else serialized_value

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
	server_id = server_ids,
	find_client_id_for = find_client_id_for,
	ensure_client_id_for = ensure_client_id_for,

	destroy_server_id = destroy_server_id,
	create_server_id = create_server_id,
	remove_attribute = remove_attribute,
	change_attribute = change_attribute,
}
