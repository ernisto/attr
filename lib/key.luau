-- memory
export type storage = { [id]: any }
local pre_allocate_amount = 2 ^ 12
local destroy_handlers: { [storage]: (storage, id) -> () } = {} -- setmetatable({}, { __mode = 'k' }) :: any

local function pre_allocated_arr(remove: nil | (any, id) -> ()): storage
	local storage = table.create(pre_allocate_amount)
	destroy_handlers[storage] = remove :: any
	return storage
end

-- id
local reused_amount: { [id]: number } = table.create(pre_allocate_amount, 0)
local cleanups: { [id]: { (id) -> () } } = table.create(pre_allocate_amount) :: any
local free_ids = {}
local prev_id = 0

local function new_id<K>(): id
	prev_id += 1
	return prev_id
end
local function get_clean_id(): id
	return table.remove(free_ids) or new_id()
end

local function flush_cleanups(id: id)
	local id_cleanups = cleanups[id]
	if id_cleanups == nil then return end

	for _, cleanup in id_cleanups :: any do
		cleanup(id)
	end
end
local function on_destroy(id: id, cleanup: (id) -> ())
	local id_cleanups = cleanups[id]
	if id_cleanups ~= nil then return table.insert(id_cleanups :: any, cleanup) end
	cleanups[id] = { cleanup }
end

local function destroy_id(id: id): ()
	flush_cleanups(id)

	for storage, remove in destroy_handlers do
		remove(storage, id)
	end

	table.insert(free_ids, id)
	reused_amount[id] = 1 + (reused_amount[id] or 0)
end
local function get_reused_amount(id: id)
	return reused_amount[id] or 0
end

-- source id
local id_sources: { [id]: id_source } = setmetatable(pre_allocated_arr(), { __mode = 'v' }) :: any
local source_ids: { [id_source]: id } = setmetatable({}, { __mode = 'k' }) :: any
local holding_ids: { [id]: true } = {}

local function get_source(id: id): id_source?
	return id_sources[id]
end
local function remapped_id(source: id_source): id
	local id = source_ids[source]
	if id == nil then
		id = new_id()
		holding_ids[id] = true
		source_ids[source] = id
		id_sources[id] = source
	end
	return id
end
local function destroy_unused_ids(): ()
	local unused_ids = table.clone(holding_ids)
	for _, id in source_ids :: any do
		unused_ids[id] = nil
	end
	for id in unused_ids do
		destroy_id(id)
	end
end

-- api
export type id = number
export type id_source = table | thread | userdata | () -> ()

type userdata = typeof(newproxy())
type table = { [any]: any }

local function doesnt_gc(x: any): boolean
	return type(x) == 'number' or type(x) == 'string' or type(x) == 'boolean'
end
local function assert_ensure_id(source: id_source | any?): id
	return if source == nil
		then get_clean_id()
		elseif type(source) == 'number' and source == source // 1 and source > 0 then source
		elseif doesnt_gc(source) then error(`attempt to get a id for non-gc (primitive) value '{source}'`)
		else remapped_id(source)
end

-- module
return table.freeze {
	source_ids = source_ids,

	source = get_source,
	destroy_id = destroy_id,
	on_destroy = on_destroy,
	assert_ensure_id = assert_ensure_id,
	get_reused_amount = get_reused_amount,
	destroy_unused_ids = destroy_unused_ids,
	pre_allocated_storage = pre_allocated_arr,
}
