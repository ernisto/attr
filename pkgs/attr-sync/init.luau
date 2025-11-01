local client = require '@self/client'
local server = require '@self/server'
local shared = require '@self/shared'

-- module
return table.freeze {
	sync_attribute = shared.sync_attribute,
	serde = shared.serde,

	client = client,
	server = server,
}
