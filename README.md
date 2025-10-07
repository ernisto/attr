## About

**attr** is a small and flexible Entity Component (EC) library for the Luau/Roblox ecosystem, focused on performance, simplicity, and extensibility. It helps you organize data and behavior for entities efficiently, using archetypes and dynamic attributes.

## Main Concepts

- **Entity:** A unique identifier (id) for an object in the world.
    - Can be attached into a `source` value, such as tables, Instances and functions
    - When the id `source` is garbage collected, the id is destroyed next frame.
    - Internally the library itself never keeps a strong reference for a `source`.
    - If does have a `source`, could be repentinally destroyed if you don not keep a external strong reference to `source`, such as a Instance.Parent.
    - If doesnt have a `source`, it is never destroyed until you manually call `attr.destroy()`

- **Attribute (attr):** A data storage indexed by entities.
    - Never keep stored destroyed object/ids.
    - Propagates changes to observers.
    - Includes helper functions.

- **Links:** A attribute representing a relationship between entities (1:1, 1:N, N:1, N:N)
    - Never keep stored destroyed object/ids.
    - Replaces any tables in your data structure.
    - Never keep stored destroyed object/ids.
    - Also propagate changes to observers, useful to replace shallow table diffs.

- **Archetype:** A set of attributes that defines a "type" of entity.
    - Used as target for observers and entities filter.
    - As many different attribute combinations of a entity, more archetypes exists.

## Basic Usage Example

```lua
local attr = require 'attr'

-- Create an attribute to store positions
local position = attr.any({ x = 0, y = 0 })

-- Create an entity
local id = attr.id()

-- Add a value to the attribute
position:set(id, { x = 10, y = 20 })

-- Access the value
local pos = position:find(id)
print(pos.x, pos.y) -- 10 20

-- Remove the value
position:remove(id)
```

## Entity Links

```lua
local attr = require 'attr'

-- 1:1 Link
local a_to_b, b_to_a = attr.xref()
local id_a = attr.id()
local id_b = attr.id()
a_to_b:set(id_a, id_b)
print(b_to_a:find(id_b) == id_a) -- true

-- N:N Link
local a_to_bs, b_to_as = attr.refs()
a_to_bs:add(id_a, id_b)
print(b_to_as:has(id_b, id_a)) -- true
```

## Main API

```lua
local attr = require 'attr'

-- Attribute creation
local my_attr = attr.any(default)

-- Generate entity ids
local id = attr.id()

-- Attribute methods
my_attr:set(id, value)
my_attr:find(id) -- returns value
my_attr:remove(id)
my_attr:has(id) -- returns boolean
my_attr:all() -- returns all ids

-- Links
local a_to_b, b_to_a = attr.xref()
local a_to_bs, b_to_a = attr.refs()

-- Events
attr.on_add(id, callback)
attr.on_remove(id, callback)
attr.on_change(id, callback)

-- Destruction
attr.destroy(id)
attr.on_destroy(id, callback)

-- Map (iteration system)
attr.map(archetype, callback)
```

## Tests

To run the tests:

```sh
pesde x ernisto/test
```

## Quick Reference

- `attr.any(default)` — Creates an attribute with a default value `default`.
- `attr.id()` — Creates a new entity id.
- `attr.id(source)` — Creates a new entity id attached into `source`.
- `attr.destroy(id)` — Destroys an entity.
- `attr.xref()` — Creates a 1:1 link.
- `attr.refs()` — Creates an N:N link.
- `attr.map(archetype, callback)` — Iterates over entities of an archetype.

See the test files in `tests/` for advanced examples.

---

> Project is in early stage. Suggestions and PRs are welcome!
