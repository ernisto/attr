export type json = number | string | boolean | { json } | { [string]: json }
export type binary = buffer

export type impl<Entity = any, Deserialized = any, Serialized = json> = {
	fallback: nil | (Entity) -> Deserialized,
	default: nil | (Entity) -> Deserialized?,
} & ({
	fallback_serialized: nil,
	default_serialized: nil,
	deserialize: nil,
	serialize: nil,
} | {
	fallback_serialized: nil | (Entity) -> Serialized,
	default_serialized: nil | (Entity) -> Serialized?,
	deserialize: (Serialized, Entity) -> Deserialized?,
	serialize: (Deserialized, Entity) -> Serialized?,
})

-- functions
local function deserialize_component<E, T, S>(entity: E, impl: impl<E, T, S>, serialized: S?): T?
	if serialized == nil and impl.fallback_serialized then serialized = impl.fallback_serialized(entity) end

	local deserialized = if serialized ~= nil and impl.deserialize ~= nil
		then impl.deserialize(serialized, entity)
		else serialized :: any

	return if deserialized == nil and impl.fallback then impl.fallback(entity) else deserialized
end
local function serialize_component<E, T, S>(entity: E, impl: impl<E, T, S>, deserialized: T?): S?
	if deserialized == nil and impl.fallback then deserialized = impl.fallback(entity) end

	local serialized = if deserialized ~= nil and impl.serialize ~= nil
		then impl.serialize(deserialized, entity)
		else deserialized :: any

	return if serialized == nil and impl.fallback_serialized then impl.fallback_serialized(entity) else serialized
end

-- module
return table.freeze {
	deserialize = deserialize_component,
	serialize = serialize_component,
}
