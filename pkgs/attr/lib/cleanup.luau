local archetype = require './archetype'
local archetype_attributes = archetype.attributes

local entity_archetype = require './entity_archetype'
local remove_entity_archetype = entity_archetype.remove

local key = require './key'
local unsafe_alive_id = key.unsafe_alive
local maybe_alive_id = key.maybe_alive
local ensure_id = key.ensure_id
local free_id = key.free_id
local find_id = key.find_id
local id_sources = key.id_sources

type cleanup = key.tracked_id | (key.tracked_id) -> ()
type id = key.id

-- states
local cleanups: { [id]: { cleanup } } = key.pre_allocated_storage()
local destroy_queue: { key.tracked_id }?
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

local function on_destroy(id: id, cleanup: cleanup)
	local id_cleanups = cleanups[id]
	if id_cleanups ~= nil then return table.insert(id_cleanups :: any, cleanup) end
	cleanups[id] = { cleanup }
end
local function on_destroy_key(key: key.key, cleanup: cleanup)
	on_destroy(ensure_id(key), cleanup)
end

local function destroy_id(tracked: key.tracked_id)
	local id = maybe_alive_id(tracked)
	if id == nil then return end

	if destroy_queue then return table.insert(destroy_queue, tracked) end
	destroy_queue = {}

	flush_cleanups(id, tracked)
	remove_entity_archetype(id)
	free_id(id)

	for _, tracked in destroy_queue or {} :: any do
		id = maybe_alive_id(tracked)
		if id == nil then continue end

		flush_cleanups(id, tracked)
		remove_entity_archetype(id)
		free_id(id)
	end
	destroy_queue = nil
end
local function destroy_key(key: key.key)
	local id = find_id(key)
	return id and destroy_id(id)
end

local last_alive = {}
local function destroy_unused_ids(): ()
	local collected_ids = last_alive

	-- archetypes have internal strong references
	for id in archetype_attributes do
		collected_ids[id] = nil
	end
	for id in id_sources do
		collected_ids[id] = nil
	end

	for id in collected_ids do
		destroy_id(id)
	end

	-- snapshot for next frame
	last_alive = {}
	for id in id_sources do
		last_alive[id] = true
	end
end

-- module
inner_destroy_id = destroy_id
return table.freeze {
	destroy_unused_ids = destroy_unused_ids,
	on_destroy = on_destroy,
	destroy = destroy_id,

	on_destroy_key = on_destroy_key,
	destroy_key = destroy_key,
}
