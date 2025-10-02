local archetype_event = require './archetype_event'
local archetype_handle = require './archetype_handle'
local entity_archetype = require './entity_archetype'

local key = require './key'
local assert_alive_id = key.assert_alive
local maybe_source = key.maybe_source
local alive = key.unsafe_alive

type cleanup = () -> ()
local function map<A, B, C, D, E, F, G, H>(
	arch: archetype_handle.arch<A, B, C, D, E, F, G, H>,
	callback: (key.tracked_id, A, B, C, D, E, F, G, H) -> nil | () -> ()
): cleanup
	local arch_ids = arch:root_ids()
	local attributes = arch:attributes()

	local param_count: number, is_variadic = debug.info(callback, 'a')
	local read_amount = math.min(#attributes, if is_variadic then 1 / 0 else param_count - 1)

	local storages = {}
	for i = 1, read_amount do
		storages[i] = maybe_source(attributes[i]) or {}
	end

	local cleanups = {}
	local arch_id = assert_alive_id(arch_ids[1])

	local function track(entity)
		local index = alive(entity)
		if read_amount == 0 then
			cleanups[index] = (callback :: any)(entity)
			return
		end
		local datas = table.create(read_amount)
		for i = 1, read_amount do
			datas[i] = storages[i][index]
		end
		cleanups[index] = (callback :: any)(entity, unpack(datas, 1, read_amount))
	end

	for entity in entity_archetype.iter_entities(arch_id) do
		track(entity)
	end

	local disconnect_added = archetype_event.bind_add(arch_id, track)
	local disconnect_removed = archetype_event.bind_remove(arch_id, function(entity)
		local cleanup = cleanups[alive(entity)]
		if cleanup ~= nil then cleanup() end
	end)

	local function disconnect_tracker()
		disconnect_added()
		disconnect_removed()

		for index, cleanup in cleanups do
			cleanup()
		end
	end
	return disconnect_tracker
end

return map
