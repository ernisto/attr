local attr = require '../../lib'

-- vars
local client_ids = {}
local server_ids = attr.any(0)

-- events
local function create_server_id(server_id: attr.id, source: attr.id_source, attributes: { [attr.id]: unknown })
	local client_id = attr.id(source)
	client_ids[server_id] = client_id

	server_ids:set(client_id, server_id)
	for attr_id, attr_value in attributes do
		assert(attr.id_source(attr_id) :: any):set(client_id, attr_value)
	end

	return client_id
end
local function destroy_server_id(server_id: attr.id)
	attr.destroy(client_ids[server_id])
end
local function change_component(server_id: attr.id, attr_id: attr.id, attr_value: unknown)
	local attribute = assert(attr.id_source(attr_id) :: any)
	if attribute.kind == 'link1' then attr_value = attr_value and client_ids[attr.id(attr_value)] or nil end

	attribute:set(client_ids[server_id], attr_value)
end

attr.on_remove(server_ids, function(client_id, server_id): ()
	client_ids[server_id] = nil
end)

-- module
return table.freeze {
	create_server_id = create_server_id,
	destroy_server_id = destroy_server_id,
	change_component = change_component,
	server_id = server_ids,
}
