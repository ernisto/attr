local archetype = require './archetype'
local iter_smaller_archetypes = archetype.iter_smaller_archetypes
local iter_bigger_archetypes = archetype.iter_bigger_archetypes
local archetype_attributes = archetype.attributes

local key = require './key'
type archetype_id = key.id
type attribute_id = key.id

local connection_roots = key.pre_allocated_storage()

local function event()
	local dense_inherited_callbacks = key.pre_allocated_storage()

	local function find_dense_inherited_callbacks(arch: archetype_id, attr: attribute_id)
		local arch_event = dense_inherited_callbacks[arch]
		return arch_event and arch_event[attr]
	end
	local function ensure_dense_inherited_callbacks(arch: archetype_id, attr: attribute_id)
		local arch_event = dense_inherited_callbacks[arch]
		local callbacks = arch_event and arch_event[attr]
		if callbacks then return callbacks end

		callbacks = {}
		dense_inherited_callbacks[arch] = arch_event or { [attr] = callbacks }
		dense_inherited_callbacks[arch][attr] = callbacks

		for sub_arch in iter_smaller_archetypes(arch, { [attr] = true :: any }) do
			local sub_callbacks = find_dense_inherited_callbacks(sub_arch, attr)
			if sub_callbacks == nil then continue end

			for _, callback in sub_callbacks do
				if table.find(callbacks, callback) then continue end
				table.insert(callbacks, callback)
			end
		end
		return callbacks
	end

	local function fire_event(entity: key.tracked_id, arch: archetype_id, attr: attribute_id)
		if arch == attr and not find_dense_inherited_callbacks(arch, attr) then return end
		local callbacks = ensure_dense_inherited_callbacks(arch, attr)
		if #callbacks == 0 then return end

		for _, callback in callbacks do
			callback(entity)
		end
	end
	local function bind_event(arch: archetype_id, callback: (key.id, any, any) -> ())
		local sub_archs = {}
		for sub_arch in iter_bigger_archetypes(arch) do
			table.insert(sub_archs, sub_arch)
		end

		for _, attr in archetype_attributes[arch] do
			ensure_dense_inherited_callbacks(arch, attr)
			for _, sub_arch in sub_archs do
				local sub_callbacks = find_dense_inherited_callbacks(sub_arch, attr)
				if sub_callbacks then table.insert(sub_callbacks, callback) end
			end
		end

		local connected = true
		local function disconnect()
			if connected == false then return end
			connected = true

			local index = table.find(connection_roots[arch], disconnect)
			table.remove(connection_roots[arch], index)

			for arch in iter_bigger_archetypes(arch) do
				local arch_event = dense_inherited_callbacks[arch]
				if arch_event == nil then continue end

				for attr, callbacks in arch_event do
					local callback_index = table.find(callbacks, callback)
					if callback_index then table.remove(callbacks, callback_index) end
				end
			end
		end

		connection_roots[arch] = connection_roots[arch] or {}
		table.insert(connection_roots[arch], disconnect)
		return disconnect
	end

	return fire_event, bind_event
end

local fire_remove, bind_remove = event()
local fire_change, bind_change = event()
local fire_add, bind_add = event()

-- module
return table.freeze {
	fire_change = fire_change,
	bind_change = bind_change,

	fire_remove = fire_remove,
	bind_remove = bind_remove,

	bind_add = bind_add,
	fire_add = fire_add,

	connection_roots = connection_roots,
	new = event,
}
