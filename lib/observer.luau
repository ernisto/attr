local archetype = require('./archetype')
local cleanup = require('./cleanup')
local key = require('./key')

type archetype_id = key.id
type attribute_id = key.id

local target = key.pre_allocated_storage()

local function event()
	local event = key.pre_allocated_storage()

	local function disconnect(id: key.id)
		local callback = key.source(id)
		for arch in archetype.iter_smaller_archetypes(target[id]) do
			local arch_event = event[arch]
			if arch_event == nil then continue end

			for attr, callbacks in arch_event do
				local index = table.find(callbacks, callback)
				if index then table.remove(callbacks, index) end
			end
		end
		target[id] = nil
	end

	local function find_dense_callbacks(arch: archetype_id, attr: attribute_id)
		local arch_event = event[arch]
		return arch_event and arch_event[attr]
	end
	local function ensure_dense_callbacks(arch: archetype_id, attr: attribute_id)
		local arch_event = event[arch]
		local callbacks = arch_event and arch_event[attr]
		if callbacks then return callbacks end

		callbacks = {}
		event[arch] = arch_event or { [attr] = callbacks }
		event[arch][attr] = callbacks

		for sub_arch in archetype.iter_smaller_archetypes(arch, { [attr] = true :: any }) do
			local sub_callbacks = find_dense_callbacks(sub_arch, attr)
			if sub_callbacks == nil then continue end

			for _, callback in sub_callbacks do
				if table.find(callbacks, callback) then continue end
				table.insert(callbacks, callback)
			end
		end
		return callbacks
	end

	local function fire_event(entity: key.id, new_arch: archetype_id, attr: attribute_id)
		if new_arch == attr and not find_dense_callbacks(new_arch, attr) then return end
		local callbacks = ensure_dense_callbacks(new_arch, attr)
		for _, callback in callbacks do
			callback(entity)
		end
	end
	local function bind_event(arch: archetype_id, callback: (key.id, any, any) -> ())
		local connection = key.ensure_id(callback)
		local sub_archs = {}

		for sub_arch in archetype.iter_smaller_archetypes(arch) do
			table.insert(sub_archs, sub_arch)
		end
		for _, attr in archetype.attributes[arch] do
			ensure_dense_callbacks(arch, attr)
			for _, sub_arch in sub_archs do
				local sub_callbacks = find_dense_callbacks(sub_arch, attr)
				if sub_callbacks then table.insert(sub_callbacks, callback) end
			end
		end

		cleanup.on_destroy(arch, connection)
		cleanup.on_destroy(connection, disconnect)

		target[connection] = arch
		return connection
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
}
