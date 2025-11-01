local attr = require '@lib'
local serde = require '@self/serde'

local sync_serde = attr.any((nil :: any) :: serde.impl<any>)

local function sync_attribute<T>(attribute: attr.attr<T>, serde: serde.impl<T>?)
	if serde then sync_serde:set(attribute, serde) end
end

-- module
return table.freeze {
	sync_attribute = sync_attribute,
	serde = sync_serde,
}
