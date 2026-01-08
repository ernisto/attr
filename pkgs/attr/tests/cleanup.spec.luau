local cleanup = require '@lib/cleanup'
local key = require '@lib/key'

local run = {}
local focus = {}

function run.destruction_queue()
	local _, id = key.ensure_id()
	local _, id2 = key.ensure_id()

	cleanup.on_destroy_key(id, id2)
	cleanup.destroy(id)

	assert(not key.maybe_alive(id))
	assert(not key.maybe_alive(id2))
end

return { run = run, focus = focus }
