local attr = require '@lib'

local run, focus, skip = {}, {}, {}
local function call_logger()
	local log = {}
	return log, function(...)
		table.insert(log, table.pack(...))
	end
end

function run.base_usage()
	local A = attr.any(0)
	local B = attr.any('cavalo')
	local C = attr.link_NN()

	local calls, log_call = call_logger()

	attr.map(A + B + C:of(A), log_call)
	assert(#calls == 0)

	A:add(B)
	assert(#calls == 0)

	C:add(A, B)
	assert(#calls == 0)

	C:add(B, A)
	assert(#calls == 0)

	B:add(B)
	assert(#calls == 1)

	assert(calls[1][1] == select(2, attr.id(B)))
	assert(calls[1][2] == 0)
	assert(calls[1][3] == 'cavalo')
	assert(calls[1][4] == nil)
end

return { run = run, skip = skip, focus = focus }
