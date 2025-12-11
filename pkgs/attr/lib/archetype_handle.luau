local key = require './key'
local maybe_source = key.maybe_source
local maybe_alive = key.maybe_alive
local ensure_id = key.ensure_id
local find_id = key.find_id
type key = key.key

local entity_archetype = require './entity_archetype'
local entity_archetype_is_a = entity_archetype.is_a

local archetype = require './archetype'
local match_attributes = archetype.match_attributes
local attributes = archetype.attributes

local attribute_storages = key.pre_allocated_storage()
local archetype_ids = key.pre_allocated_storage()
local excluding = key.pre_allocated_storage()

-- helpers
local function merge_array(arr1, arr2, ...)
	local out = table.clone(arr1)
	table.move(arr2, 1, #arr2, #out + 1, out)
	return if ... then merge_array(out, ...) else out
end
local function merge_map(tab1, tab2)
	local out = table.clone(tab1)
	for i, v in tab2 do
		out[i] = v
	end
	return out
end

-- methods
local archetype_impl

local function intersect(arch_handle: key, arch2: key): any
	local handle = setmetatable({}, archetype_impl)
	local id = ensure_id(handle)

	local id1 = ensure_id(arch_handle)
	local id2 = ensure_id(arch2)

	local this_attributes = merge_array(attributes[id1], attributes[id2])
	local this_excluding = merge_map(excluding[id1], excluding[id2])
	local this_storages = merge_array(attribute_storages[id1], attribute_storages[id2])

	local ordered_attributes = table.clone(this_attributes)
	table.sort(ordered_attributes)

	local arch_id = archetype.with_attr(unpack(ordered_attributes))

	excluding[id] = this_excluding
	attributes[id] = this_attributes
	archetype_ids[id] = { arch_id }
	attribute_storages[id] = table.freeze(this_storages)
	return handle
end
local function ignore(arch_handle: key, arch2: key): any
	local handle = setmetatable({}, archetype_impl)
	local id = ensure_id(handle)

	local id1 = ensure_id(arch_handle)
	local id2 = ensure_id(arch2)

	excluding[id] = merge_array(excluding[id1], excluding[id2], attributes[id2])
	attributes[id] = attributes[id1]
	archetype_ids[id] = { archetype_ids[id1] }
	attribute_storages[id] = attribute_storages[id1]
	return handle
end
local function is_subset(sub: key, super: key): boolean
	return match_attributes(attributes[ensure_id(super)], attributes[ensure_id(sub)])
end

local function get_attributes(arch_handle: key)
	return attributes[ensure_id(arch_handle)]
end
local function root_ids(arch_handle: key): { number }
	return archetype_ids[ensure_id(arch_handle)]
end

local function arch_iter(arch_handle: key): ...any
	return entity_archetype.iter_entities(archetype_ids[ensure_id(arch_handle)][1])
end
local function arch_all(arch_handle: key): { key.id }
	local entities = {}
	for entity in arch_iter(arch_handle) do
		table.insert(entities, entity)
	end
	return entities
end

local function arch_find(arch_handle: key, key: key): ...any
	local id = find_id(key)
	if id == nil then return end
	local storages = attribute_storages[ensure_id(arch_handle)]

	local a = storages[1]
	if a == nil then return end

	local b = storages[2]
	if b == nil then return a[id] end

	local c = storages[3]
	if c == nil then return a[id], b[id] end

	local d = storages[4]
	if d == nil then return a[id], b[id], c[id] end

	local e = storages[5]
	if e == nil then return a[id], b[id], c[id], d[id] end

	local f = storages[6]
	if f == nil then return a[id], b[id], c[id], d[id], e[id] end

	local g = storages[7]
	if g == nil then return a[id], b[id], c[id], d[id], e[id], f[id] end

	local h = storages[8]
	if h == nil then return a[id], b[id], c[id], d[id], e[id], f[id], g[id] end

	local datas = { a[id], b[id], c[id], d[id], e[id], f[id], g[id], h[id] }
	for i, storage in attributes do
		if i <= 8 then continue end
		datas[i] = storage[id]
	end
	return unpack(datas)
end
local function arch_has(arch_handle: key, key: key): boolean
	local id = find_id(key)
	return id ~= nil and entity_archetype_is_a(id, archetype_ids[ensure_id(arch_handle)][1])
end

local function arch_assert_has(arch_handle: key, key: key, message: string?): ()
	if not arch_has(arch_handle, key) then
		assert(find_id(key), `key {key} is destroyed`)
		error(message or `not found`)
	end
end
local function arch_assert(arch_handle: key, key: key, message: string?): ...any
	arch_assert_has(arch_handle, key)
	return arch_find(arch_handle, key)
end

local function arch_await_has(arch_handle: key, key: any): boolean
	local id = ensure_id(key)
	while maybe_alive(id) and not arch_has(arch_handle, key) do
		task.wait()
	end
	return maybe_alive(id) ~= nil
end
local function arch_await(arch_handle: key, key: any): ()
	return arch_await_has(arch_handle, key) and arch_find(arch_handle, key)
end

local function arch_assert_await_has(arch_handle: key, key: key, message: string?): ()
	if not arch_await_has(arch_handle, key) then error(message or `key destroyed before contains {arch_handle}`) end
end
local function arch_assert_await(arch_handle: key, key: key, message: string?): ...any
	arch_assert_await_has(arch_handle, key, message)
	return arch_find(arch_handle, key)
end

-- constructor
archetype_impl = {} :: any
archetype_impl.attributes = get_attributes
archetype_impl.root_ids = root_ids

archetype_impl.assert_await_has = arch_assert_await_has
archetype_impl.assert_await = arch_assert_await
archetype_impl.assert_has = arch_assert_has
archetype_impl.await_has = arch_await_has
archetype_impl.assert = arch_assert
archetype_impl.await = arch_await
archetype_impl.find = arch_find
archetype_impl.iter = arch_iter
archetype_impl.all = arch_all
archetype_impl.has = arch_has

archetype_impl.is_subset = is_subset
archetype_impl.__lt = is_subset
archetype_impl.__le = is_subset

archetype_impl.with = intersect
archetype_impl.__add = intersect

archetype_impl.without = ignore
archetype_impl.__sub = ignore

archetype_impl.kind = 'archetype'
archetype_impl.__index = archetype_impl
archetype_impl.__metatable = 'locked'
table.freeze(archetype_impl)

local function handle<T>(data: key.storage<T>): arch1<T>
	local id = key.ensure_id(data)
	archetype.with_attr(id)

	excluding[id] = {}
	attributes[id] = { id }
	archetype_ids[id] = { id }
	attribute_storages[id] = table.freeze { maybe_source(id) }

	-- assert(getmetatable(data) extends arch_impl)
	return data :: any
end
local function handle_id(arch_id: key.id): arch1<nil>
	local handle = setmetatable({}, archetype_impl) :: any
	local id = ensure_id(handle)

	archetype_ids[id] = { arch_id }
	attributes[id] = { arch_id }
	excluding[id] = {}
	attribute_storages[id] = table.freeze { maybe_source(id) }
	return handle
end

-- types
export type extract_T<T> = base_arch<any, any, T>
export type base_impl<T...> = {
	iter: (any) -> () -> key.id,
	all: (any) -> { key.id },

	assert_await_has: (any, key: key.key) -> (),
	await_has: (any, key: key.key) -> boolean,
	assert_has: (any, key: key.key) -> (),
	has: (any, key: key.key) -> boolean,

	assert_await: (any, key: key.key) -> T...,
	await: (any, key: key.key) -> T...,
	assert: (any, key: key.key) -> T...,
	find: (any, key: key.key) -> T...,
}
type base_arch<api = any, add = () -> (), T... = ()> = typeof(setmetatable(
	{} :: {
		__T: (T...) -> (),
		with: add,
		without: (any, any) -> base_arch<api, add, T...>,
		is_subset: (any, any) -> boolean,
		is_superset: (any, any) -> boolean,

		attributes: (any) -> { key.id },
		root_ids: (any) -> { key.id },
	},
	{} :: {
		__add: add,
		__sub: (any, any) -> base_arch<api, add, T...>,
		__lt: (any, any) -> boolean,
		__le: (any, any) -> boolean,
		__index: api,
	}
))

export type arch1<A, api = any> = base_arch<api, <B>(any, extract_T<B>) -> arch2<A, B>, (A)>

type arch2<A, B> = base_arch<base_impl<A, B>, <C>(any, extract_T<C>) -> arch3<A, B, C>, (A, B)>
type arch3<A, B, C> = base_arch<base_impl<A, B, C>, <D>(any, extract_T<D>) -> arch4<A, B, C, D>, (A, B, C)>
type arch4<A, B, C, D> = base_arch<base_impl<A, B, C, D>, <E>(any, extract_T<E>) -> arch4<A, B, C, D>, (A, B, C, D)>

type arch5<A, B, C, D, E> = base_arch<
	base_impl<A, B, C, D, E>,
	<F>(any, extract_T<F>) -> arch6<A, B, C, D, E, F>,
	(A, B, C, D, E)
>
type arch6<A, B, C, D, E, F> = base_arch<
	base_impl<A, B, C, D, E, F>,
	<G>(any, extract_T<G>) -> arch7<A, B, C, D, E, F, G>,
	(A, B, C, D, E, F)
>
type arch7<A, B, C, D, E, F, G> = base_arch<
	base_impl<A, B, C, D, E, F, G>,
	<H>(any, extract_T<H>) -> arch8<A, B, C, D, E, F, G, H>,
	(A, B, C, D, E, F, G)
>
type arch8<A, B, C, D, E, F, G, H> = base_arch<
	base_impl<A, B, C, D, E, F, G, H>,
	(any, extract_T<any>) -> arch8<A, B, C, D, E, F, G, H>,
	(A, B, C, D, E, F, G, H)
>

export type arch<A = any, B = nil, C = nil, D = nil, E = nil, F = nil, G = nil, H = nil> =
	| arch8<A, B, C, D, E, F, G, H>
	| arch7<A, B, C, D, E, F, G>
	| arch6<A, B, C, D, E, F>
	| arch5<A, B, C, D, E>
	| arch4<A, B, C, D>
	| arch3<A, B, C>
	| arch2<A, B>
	| arch1<A>

-- module
return table.freeze {
	impl = archetype_impl,
	get_archetype_ids = root_ids,
	handle_id = handle_id,
	handle = handle,
}
