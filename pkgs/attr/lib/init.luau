local any = require '@self/any'
local cleanup = require '@self/cleanup'
local entity_archetype = require '@self/entity_archetype'
local key = require '@self/key'
local link = require '@self/link'
local tracker = require '@self/tracker'

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
	is_alive = key.maybe_alive,
	find_id = key.find_id,
	id = key.ensure_id,

	destroy = cleanup.destroy_key,
	on_destroy = cleanup.on_destroy_key,
	gc_step = cleanup.destroy_unused_ids,

	on_remove = tracker.on_remove,
	on_change = tracker.on_change,
	on_add = tracker.on_add,

	get_attributes = entity_archetype.get_attributes,
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
