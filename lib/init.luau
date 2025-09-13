local any = require '@self/any'
local key = require '@self/key'
local link = require '@self/link'

export type link_attr<T> = link.link_attr<T>
export type link1_attr<T> = link.link1<T>
export type linkN_attr<T> = link.linkN<T>
export type attr<T> = any.attr<T>
export type id = key.id

-- module
return table.freeze {
	id_source = key.source,
	id = key.assert_ensure_id,
	destroy = key.destroy_id,
	on_destroy = key.on_destroy,
	gc_step = key.destroy_unused_ids,

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
