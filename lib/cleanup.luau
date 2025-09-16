local archetype = require('./archetype')
local key = require('./key')
local free_id = key.free_id
type id = key.id

local cleanups: { [id]: { id | (id) -> () } } = key.pre_allocated_storage()
local inner_destroy_id

-- functions
local function flush_cleanups(id: id)
	local id_cleanups = cleanups[id]
	if id_cleanups == nil then return end

	for i = #id_cleanups, 1, -1 do
		local cleanup = id_cleanups[i]
		if type(cleanup) == 'function' then
			cleanup(id)
		else
			inner_destroy_id(cleanup)
		end
	end
	cleanups[id] = nil
end
local function on_destroy(id: id, cleanup: id | (id) -> ())
	local id_cleanups = cleanups[id]
	if id_cleanups ~= nil then return table.insert(id_cleanups :: any, cleanup) end
	cleanups[id] = { cleanup }
end

local function destroy_id(id: id)
	flush_cleanups(id)

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
