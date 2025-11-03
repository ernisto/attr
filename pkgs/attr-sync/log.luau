local attr = require '@lib'

local messages = {}
export type message = {
	what: string,
	why: string?,
	fix: string?,
	fallback: string?,
}

function messages.two_ids_with_same_source(
	client_id: attr.id,
	server_id: attr.id,
	source_id: attr.id,
	source: attr.key,
	link_source: string
)
	return table.freeze {
		what = `The id {source_id} mapping to source {source} isnt the same id {client_id} created by syncing link {link_source}`,
		why = table.concat {
			`It occured because you replicated the link {link_source} before replicate `,
			`server#{server_id}, so the client created {client_id} (without source). Another id `,
			`{source_id} mapped by {source} was created before receive the {client_id} source from server.`,
		},
		fix = `Sync entity server#{server_id} before replicate the link {link_source}`,
		fallback = `Attr is deleting {source_id} and moving their attributes to {client_id} before apply server attributes`,
	}
end
function messages.instance_linked_before_receive(
	client_id: attr.id,
	server_id: attr.id,
	target_client_id: attr.id,
	target_server_id: attr.id,
	link: attr.link1_attr
)
	return table.freeze {
		what = `{server_id}/{client_id} linking '{link}' to {target_server_id}/{target_client_id}, which has not been received yet`,
		why = `You are replicating the link '{link}' of {server_id} before update its 'sync.sync_group' to one which matches the local client`,
		fix = `Update {server_id}'s sync.sync_group before define replicate the link {link}`,
		fallback = `Attr is creating a empty id for link target. Could be dangerous if client have a id mapping to the same source of {target_server_id}`,
	}
end

-- functions
local function warn(message: message)
	local options = {} :: any
	if message.why then
		table.insert(options, 'why')
		table.insert(options, { message.why })
	end
	if message.fix then
		table.insert(options, 'fix')
		table.insert(options, { message.fix })
	end
	if message.fallback then
		table.insert(options, 'fallback')
		table.insert(options, { message.fallback })
	end
	print(message.what, '\n', unpack(options))
end

-- module
return table.freeze {
	messages = messages,
	warn = warn,
}
