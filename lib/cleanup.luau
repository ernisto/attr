local archetype = require('./archetype')
local key = require('./key')
local maybe_alive_id = key.maybe_alive
local free_id = key.free_id
type id = key.id

local cleanups: { [id]: { id | (id) -> () } } = key.pre_allocated_storage()
local inner_destroy_id

-- functions
local function flush_cleanups(id: id, tracked)
	local id_cleanups = cleanups[id]
	if id_cleanups == nil then return end

	for i = #id_cleanups, 1, -1 do
		local cleanup = id_cleanups[i]
		if type(cleanup) == 'function' then
			cleanup(tracked)
		else
			inner_destroy_id(cleanup)
		end
	end
	cleanups[id] = nil
end
local function on_destroy(id: id, cleanup: key.tracked_id | (key.tracked_id) -> ())
	local id_cleanups = cleanups[id]
	if id_cleanups ~= nil then return table.insert(id_cleanups :: any, cleanup) end
	cleanups[id] = { cleanup }
end

local function destroy_id(tracked: key.tracked_id)
	local id = maybe_alive_id(tracked)
	if id == nil then return end

	flush_cleanups(id, tracked)
	if not maybe_alive_id(tracked) then return end

	archetype.remove(id)
	free_id(id)
end

local last_alive = {}
local function destroy_unused_ids(): ()
	local collected_ids = last_alive
	for id in key.id_sources do
		collected_ids[id] = nil
	end
	for id in collected_ids do
		destroy_id(id)
	end

	last_alive = {}
	for id in key.id_sources do
		last_alive[id] = true
	end
end

-- module
inner_destroy_id = destroy_id
return table.freeze {
	destroy_unused_ids = destroy_unused_ids,
	on_destroy = on_destroy,
	destroy = destroy_id,
}
