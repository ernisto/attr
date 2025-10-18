local archetype_event = require './archetype_event'
local archetype_handle = require './archetype_handle'

local key = require './key'
local assert_alive_id = key.assert_alive
local maybe_source = key.maybe_source
local alive = key.unsafe_alive

-- types
type cleanup = () -> ()
type map = <A, B, C, D, E, F, G, H>(
	arch: archetype_handle.arch<A, B, C, D, E, F, G, H>,
	callback: (key.tracked_id, A, B, C, D, E, F, G, H) -> cleanup?
) -> cleanup

local function get_tracker(arch: archetype_handle.arch, callback: (key.id, ...any) -> ())
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
			cleanups[index] = callback(entity)
			return
		end
		local datas = table.create(read_amount)
		for i = 1, read_amount do
			datas[i] = storages[i][index]
		end
		cleanups[index] = callback(entity, unpack(datas, 1, read_amount))
	end

	return arch_id, cleanups, track
end

-- functions
local function on_add(arch: archetype_handle.arch, callback: (key.tracked_id) -> cleanup?): cleanup
	local arch_id, cleanups, track = get_tracker(arch, callback)

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
local function on_change(arch: archetype_handle.arch, callback: (key.tracked_id) -> cleanup?): cleanup
	local arch_id, cleanups, track = get_tracker(arch, callback)

	local disconnect_added = archetype_event.bind_add(arch_id, track)
	local disconnect_changed = archetype_event.bind_change(arch_id, function(entity)
		local cleanup = cleanups[alive(entity)]
		if cleanup ~= nil then cleanup() end
		(track :: any)(entity)
	end)
	local disconnect_removed = archetype_event.bind_remove(arch_id, function(entity)
		local cleanup = cleanups[alive(entity)]
		if cleanup ~= nil then cleanup() end
	end)

	local function disconnect_tracker()
		disconnect_added()
		disconnect_changed()
		disconnect_removed()

		for index, cleanup in cleanups do
			cleanup()
		end
	end
	return disconnect_tracker
end
local function on_remove(arch: archetype_handle.arch, callback: (key.tracked_id) -> cleanup?): cleanup
	local arch_id, cleanups, track = get_tracker(arch, callback)
	local disconnect_removed = archetype_event.bind_remove(arch_id, track)

	local function disconnect_tracker()
		disconnect_removed()

		for index, cleanup in cleanups do
			cleanup()
		end
	end
	return disconnect_tracker
end

-- module
return table.freeze {
	on_add = on_add :: map,
	on_change = on_change :: map,
	on_remove = on_remove :: map,
}
