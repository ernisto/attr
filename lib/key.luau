-- defs
local function doesnt_gc(x: any): boolean
	return type(x) == 'number' or type(x) == 'string' or type(x) == 'boolean'
end

export type id = number
export type tracked_id = number -- id(u32) .. destroyed_count(u16)
export type id_source = table | thread | userdata | () -> ()
export type key = id | tracked_id | id_source

type userdata = typeof(newproxy())
type table = { [any]: any }

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

local function unsafe_alive_id(id: tracked_id | id): id
	return id % GENERATION_BIT_POS
end
local function get_holding_destroyed_amount(id: tracked_id): number?
	return id // GENERATION_BIT_POS
end
local function get_destroyed_amount(id: id): number
	return destroyed_count[id] or 1
end
local function tracked_id(id: id | tracked_id, new_count: number?): tracked_id
	if id > GENERATION_BIT_POS and new_count == nil then return id end
	local idx = unsafe_alive_id(id)
	return idx + (new_count or get_destroyed_amount(idx)) * GENERATION_BIT_POS
end
local function maybe_holding_destroyed_amount(id: id | tracked_id): number?
	local count = get_holding_destroyed_amount(id)
	return if count == 0 then nil else count
end
local function maybe_alive_id(id: id | tracked_id): id?
	-- stylua: ignore
	return if id < GENERATION_BIT_POS then id
		elseif get_holding_destroyed_amount(id) == get_destroyed_amount(unsafe_alive_id(id)) then unsafe_alive_id(id)
		else nil
end
local function assert_alive_id(id: id | tracked_id): id
	return maybe_alive_id(id) or error('this id already was destroyed, you are holding a dead reference')
end

local function new_id<K>(): tracked_id
	prev_id += 1
	return prev_id
end
local function get_clean_id(): tracked_id
	return table.remove(free_ids) or new_id()
end

-- source id
local id_sources: { [id]: id_source } = setmetatable(pre_allocated_arr(), { __mode = 'v' }) :: any
local source_ids: { [id_source]: tracked_id } = setmetatable({}, { __mode = 'k' }) :: any

local function get_source(id: id | tracked_id): id_source?
	return id_sources[unsafe_alive_id(id)]
end
local function remapped_id(source: id_source): id
	local id = source_ids[source]
	if id == nil then
		id = new_id()
		source_ids[source] = id
		id_sources[unsafe_alive_id(id)] = source
	end
	return id
end
local function ensure_id(source: key?): (id, tracked_id)
	local tracked = if source == nil
		then get_clean_id()
		elseif type(source) == 'number' and source == source // 1 then tracked_id(source)
		elseif doesnt_gc(source) then error(`attempt to get a id for non-gc (primitive) value '{source}'`)
		else remapped_id(source)

	return assert_alive_id(tracked), tracked
end
local function find_id(source: key): (id, tracked_id)
	local tracked = if type(source) == 'number' and source == source // 1
		then tracked_id(source)
		elseif doesnt_gc(source) then error(`attempt to get a id for non-gc (primitive) value '{source}'`)
		else source_ids[source]

	return assert_alive_id(tracked), tracked
end
local function maybe_ensure_id(source: key?): (id?, tracked_id?)
	if source == nil then return end
	return ensure_id(source)
end

local function free_id(id: id): ()
	local new_count = get_destroyed_amount(id) + 1
	destroyed_count[id] = new_count

	table.insert(free_ids, tracked_id(id, new_count))

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
	source = get_source,

	maybe_holding_destroyed_amount = maybe_holding_destroyed_amount,
	get_destroyed_amount = get_destroyed_amount,
	unsafe_alive = unsafe_alive_id,
	assert_alive = assert_alive_id,
	maybe_alive = maybe_alive_id,
	tracked = tracked_id,

	free_id = free_id,
	pre_allocated_storage = pre_allocated_arr,
}
