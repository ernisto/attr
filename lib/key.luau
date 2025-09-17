-- defs
local function doesnt_gc(x: any): boolean
	return type(x) == 'number' or type(x) == 'string' or type(x) == 'boolean'
end

export type id = number
export type id_source = table | thread | userdata | () -> ()

type userdata = typeof(newproxy())
type table = { [any]: any }

-- memory
export type storage = { [id]: any }
local pre_allocate_amount = 2 ^ 12

local function pre_allocated_arr(): storage
	return table.create(pre_allocate_amount)
end

-- id
local reused_amount: { [id]: number } = table.create(pre_allocate_amount, 0)
local free_ids = {}
local prev_id = 0

local function new_id<K>(): id
	prev_id += 1
	return prev_id
end
local function get_clean_id(): id
	return table.remove(free_ids) or new_id()
end
local function get_reused_amount(id: id)
	return reused_amount[id] or 0
end

-- source id
local id_sources: { [id]: id_source } = setmetatable(pre_allocated_arr(), { __mode = 'v' }) :: any
local source_ids: { [id_source]: id } = setmetatable({}, { __mode = 'k' }) :: any

local function get_source(id: id): id_source?
	return id_sources[id]
end
local function remapped_id(source: id_source): id
	local id = source_ids[source]
	if id == nil then
		id = new_id()
		source_ids[source] = id
		id_sources[id] = source
	end
	return id
end
local function ensure_id(source: id_source?): id
	return if source == nil
		then get_clean_id()
		elseif type(source) == 'number' and source == source // 1 and source > 0 then source
		elseif doesnt_gc(source) then error(`attempt to get a id for non-gc (primitive) value '{source}'`)
		else remapped_id(source)
end

local function free_id(id: id): ()
	table.insert(free_ids, id)
	reused_amount[id] = 1 + (reused_amount[id] or 0)

	local source = id_sources[id]
	if source == nil then return end

	source_ids[source] = nil
	id_sources[id] = nil
end

-- module
return table.freeze {
	source_ids = source_ids,
	id_sources = id_sources,

	source = get_source,
	ensure_id = ensure_id,

	free_id = free_id,
	get_reused_amount = get_reused_amount,
	pre_allocated_storage = pre_allocated_arr,
}
