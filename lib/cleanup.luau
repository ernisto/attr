local archetype = require('./archetype')
local key = require('./key')
local free_id = key.free_id
type id = key.id

local cleanups: { [id]: { (id) -> () } } = key.pre_allocated_storage()

-- functions
local function flush_cleanups(id: id)
	local id_cleanups = cleanups[id]
	if id_cleanups == nil then return end

	for _, cleanup in id_cleanups :: any do
		cleanup(id)
	end
	cleanups[id] = nil
end
local function on_destroy(id: id, cleanup: (id) -> ())
	local id_cleanups = cleanups[id]
	if id_cleanups ~= nil then return table.insert(id_cleanups :: any, cleanup) end
	cleanups[id] = { cleanup }
end

local function destroy_id(id: id)
	flush_cleanups(id)

	archetype.remove_archetype(id)
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
return table.freeze {
	destroy_unused_ids = destroy_unused_ids,
	on_destroy = on_destroy,
	destroy = destroy_id,
}
