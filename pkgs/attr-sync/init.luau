local client = require '@self/client'
local server = require '@self/server'

return table.freeze {
	client = client,
	server = server,
}
