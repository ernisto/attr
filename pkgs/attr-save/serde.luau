export type json = number | string | boolean | { json } | { [string]: json }
export type binary = buffer

export type property<Entity = any, Deserialized = any, Serialized = json> = {
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
local function deserialize_component<E, T, S>(entity: E, property: property<E, T, S>, serialized: S?): T?
	if serialized == nil and property.fallback_serialized then serialized = property.fallback_serialized(entity) end

	local deserialized = if serialized ~= nil and property.deserialize
		then property.deserialize(serialized, entity)
		else serialized :: any

	return if deserialized == nil and property.fallback then property.fallback(entity) else deserialized
end
local function serialize_component<E, T, S>(entity: E, property: property<E, T, S>, deserialized: T?): S?
	if deserialized == nil and property.fallback then deserialized = property.fallback(entity) end

	local serialized = if deserialized ~= nil and property.serialize
		then property.serialize(deserialized, entity)
		else deserialized :: any

	return if serialized == nil and property.fallback_serialized
		then property.fallback_serialized(entity)
		else serialized
end

-- module
return table.freeze {
	deserialize = deserialize_component,
	serialize = serialize_component,
}
