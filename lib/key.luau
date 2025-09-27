-- defs
export type id = number
export type tracked_id = number -- id(u32) .. destroyed_count(u16)
export type id_source = does_gc
export type key = id | tracked_id | id_source

type does_gc = table | thread | userdata | buffer | () -> ()
type userdata = typeof(newproxy())
type table = { [any]: any }

local function doesnt_gc(x: any): boolean
	return type(x) == 'number' or type(x) == 'string' or type(x) == 'boolean' or type(x) == 'vector'
end

-- memory
export type storage = { [id]: any }
local pre_allocate_amount = 2 ^ 12

local function pre_allocated_arr(): storage
	return table.create(pre_allocate_amount)
end

-- id
local GENERATION_BIT_POS = 2 ^ 32
local destroyed_count: { [id]: number } = table.create(pre_allocate_amount, 1)
local prev_id = GENERATION_BIT_POS -- generate ids already tracked
local free_ids: { tracked_id } = {}

local function get_destroyed_amount(id: id): number
	return destroyed_count[id] or 1
end
local function unsafe_holding_destroyed_amount(id: tracked_id): number
	return id // GENERATION_BIT_POS
end
local function maybe_holding_destroyed_amount(id: id | tracked_id): number?
	return if id < GENERATION_BIT_POS then nil else unsafe_holding_destroyed_amount(id)
end

local function unsafe_alive_id(id: id | tracked_id): id
	return id % GENERATION_BIT_POS
end
local function maybe_alive_id(id: id | tracked_id): id?
	-- stylua: ignore
	return if id < GENERATION_BIT_POS then id
		elseif unsafe_holding_destroyed_amount(id) == get_destroyed_amount(unsafe_alive_id(id)) then unsafe_alive_id(id)
		else nil
end
local function assert_alive_id(id: id | tracked_id): id
	return maybe_alive_id(id) or error('this id already was destroyed, you are holding a dead reference')
end

local function ensure_tracked_id(tracked: id | tracked_id, new_count: number?): tracked_id
	if tracked > GENERATION_BIT_POS and new_count == nil then return tracked end
	local id = unsafe_alive_id(tracked)
	return id + (new_count or get_destroyed_amount(id)) * GENERATION_BIT_POS
end
local function id_pair(id: id | tracked_id): (id, tracked_id)
	return if id > GENERATION_BIT_POS then assert_alive_id(id) else id,
		if id > GENERATION_BIT_POS then id else ensure_tracked_id(id)
end

-- constructor
local function new_id<K>(): tracked_id
	prev_id += 1
	return prev_id
end
local function get_clean_id(): tracked_id
	return table.remove(free_ids) or new_id()
end

-- remapping
local id_sources: { [id]: id_source } = setmetatable(pre_allocated_arr(), { __mode = 'v' }) :: any
local source_ids: { [id_source]: tracked_id } = setmetatable({}, { __mode = 'k' }) :: any

local function maybe_source(id: id | tracked_id): id_source?
	return id_sources[unsafe_alive_id(id)]
end
local function ensure_remapped_id(source: id_source): id
	local id = source_ids[source]
	if id ~= nil then return id end

	if doesnt_gc(source) then error(`attempt to get a id for non-gc (primitive) value '{source}'`) end

	id = get_clean_id()
	source_ids[source] = id
	id_sources[unsafe_alive_id(id)] = source
	return id
end

local function ensure_id(source: key?): (id, tracked_id)
	if type(source) == 'number' and source % 1 == 0 then return id_pair(source) end

	local tracked = if source == nil then get_clean_id() else ensure_remapped_id(source)
	return unsafe_alive_id(tracked), tracked
end
local function find_id(source: key): (id?, tracked_id?)
	if type(source) == 'number' then return id_pair(source) end
	local tracked = source_ids[source]

	if tracked == nil then return end
	return unsafe_alive_id(tracked), tracked
end
local function maybe_ensure_id(source: key?): (id?, tracked_id?)
	if source == nil then return nil, nil end
	return ensure_id(source)
end

local function free_id(id: id): ()
	local new_count = get_destroyed_amount(id) + 1
	destroyed_count[id] = new_count

	table.insert(free_ids, ensure_tracked_id(id, new_count))

	local source = id_sources[id]
	if source == nil then return end

	source_ids[source] = nil
	id_sources[id] = nil
end

-- module
return table.freeze {
	source_ids = source_ids,
	id_sources = id_sources,

	maybe_ensure_id = maybe_ensure_id,
	ensure_id = ensure_id,
	find_id = find_id,
	maybe_source = maybe_source,

	maybe_holding_destroyed_amount = maybe_holding_destroyed_amount,
	get_destroyed_amount = get_destroyed_amount,
	unsafe_alive = unsafe_alive_id,
	assert_alive = assert_alive_id,
	maybe_alive = maybe_alive_id,
	tracked = ensure_tracked_id,

	free_id = free_id,
	pre_allocated_storage = pre_allocated_arr,
}
