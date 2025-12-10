local attr = require './luau_packages/attr'
local serde = require './serde'

local sync_serde = attr.any((nil :: any) :: serde.impl<any>)

export type serde_impl<T> = serde.impl<T>

local function sync_attribute<T>(attribute: attr.attr<T>, serde: serde_impl<T>?)
	if serde then sync_serde:set(attribute, serde) end
	return sync_serde:find(attribute) -- fallback to previously defined serde
end

-- module
return table.freeze {
	sync_attribute = sync_attribute,
	deserialize = serde.deserialize,
	serialize = serde.serialize,
	serde = sync_serde,
}
