local any = require '@self/any'
local archetype_event = require '@self/archetype_event'
local cleanup = require '@self/cleanup'
local key = require '@self/key'
local link = require '@self/link'
local map = require '@self/map'

export type link_attr = link.link_attr
export type link1_attr = link.link1
export type linkN_attr = link.linkN
export type attr<T, R = T> = any.attr<T, R>

export type tracked_id = key.tracked_id
export type id_source = key.id_source
export type key = key.key
export type id = key.id

-- module
return table.freeze {
	id_source = key.maybe_source,
	id = key.ensure_id,

	destroy = cleanup.destroy_key,
	on_destroy = cleanup.on_destroy_key,
	gc_step = cleanup.destroy_unused_ids,

	on_remove = archetype_event.bind_remove,
	on_change = archetype_event.bind_change,
	on_add = archetype_event.bind_add,
	map = map,

	any = any.new,
	ref = link.link_N1,
	xref = link.link_11,
	refs = link.link_NN,
	xrefs = link.link_1N,

	link_11 = link.link_11,
	link_1N = link.link_1N,
	link_N1 = link.link_N1,
	link_NN = link.link_NN,
}
