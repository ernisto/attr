local attr = require('../../lib')
local save = require('./save')

local focus = {}
local run = {}

function run.deserialize_data()
	local health = attr.any(0)

	local player_save = attr.id()
	save.include_attr(player_save, health, 'health')

	-- deserialization
	local ids = save.load(player_save, {
		{ health = 10 },
	})

	assert(#ids == 1)
	assert(health:find(ids[1]) == 10)

	-- serialization
	local data = save.save(player_save, ids[1])
	assert(data[1].health == 10)
end

function run.deserialize_linkeds()
	local health = attr.any(0)
	local owner, owneds = attr.ref()

	local player_save = attr.id()
	save.include_attr(player_save, health, 'health')

	local player_owneds_save = save.include_ids(player_save, owneds, 'owneds')
	save.include_attr(player_owneds_save, health, 'health')

	-- load
	local ids = save.load(player_save, {
		{ health = 10, owneds = { 2, 3 } } :: any,
		{ health = 15 },
		{ health = 05 },
	})

	-- deserialization
	assert(#ids == 3)

	assert(health:find(ids[1]) == 10)
	assert(health:find(ids[2]) == 15)
	assert(health:find(ids[3]) == 05)

	owneds:assert(ids[1], ids[2])
	owneds:assert(ids[1], ids[3])
	assert(owner:find(ids[2]) == ids[1])
	assert(owner:find(ids[3]) == ids[1])

	-- serialization
	local data = save.save(player_save, ids[1])
	assert(data[1].health == 10)

	assert(data[1].owneds[1] == 2)
	assert(data[1].owneds[2] == 3)

	-- stylua: ignore
	assert(
		(data[2].health == 15 and data[3].health == 05)
			or (data[2].health == 05 and data[3].health == 15)
	)
end

function run.dont_duplicate_entities_when_2_links()
	local health = attr.any(0)
	local owneds = attr.xrefs()
	local equipped = attr.xref()

	local player_save = attr.id()
	save.include_attr(player_save, health, 'health')
	save.include_id(player_save, equipped, 'equipped')

	local player_owneds_save = save.include_ids(player_save, owneds, 'owneds')
	save.include_attr(player_owneds_save, health, 'health')

	-- deserialization
	local ids = save.load(player_save, {
		{ health = 10, equipped = 2, owneds = { 2, 3 } } :: any,
		{ health = 15 },
		{ health = 05 },
	})

	assert(#ids == 3)
	assert(health:find(ids[1]) == 10)

	assert(health:find(ids[2]) == 15)
	assert(equipped:find(ids[1]) == ids[2])
	owneds:assert(ids[1], ids[2])

	assert(health:find(ids[3]) == 05)
	owneds:assert(ids[1], ids[3])

	-- serialization
	local data = save.save(player_save, ids[1])
	assert(data[1].health == 10)
	assert(data[1].equipped == 2)

	assert(table.find(data[1].owneds, 2))
	assert(table.find(data[1].owneds, 3))

	assert(data[2].health == 15)
	assert(data[3].health == 05)
end

function run.each_link_deserialize_own_attributes()
	local storeds = attr.xrefs()
	local equipped = attr.xref()

	local cooldown = attr.any(0)
	local slot = attr.any(0)

	local player_save = attr.id()
	local player_stored_save = save.include_ids(player_save, storeds, 'storeds')
	save.include_attr(player_stored_save, slot, 'slot')

	local player_equipped_save = save.include_id(player_save, equipped, 'equipped')
	save.include_attr(player_equipped_save, cooldown, 'cooldown')

	-- load
	local ids = save.load(player_save, {
		{ equipped = 2, storeds = { 3 } } :: any,
		{ slot = 1, cooldown = 10 }, -- equipped item
		{ slot = 1, cooldown = 10 }, -- stored item
	})
	assert(#ids == 3)

	-- equipped item
	assert(equipped:find(ids[1]) == ids[2])
	assert(slot:find(ids[2]) == nil)
	assert(cooldown:find(ids[2]) == 10)

	-- stored item
	storeds:assert(ids[1], ids[3])
	assert(slot:find(ids[3]) == 1)
	assert(cooldown:find(ids[3]) == nil)

	-- serialization
	local data = save.save(player_save, ids[1])
	assert(data[1].equipped == 2)
	assert(data[1].storeds[1] == 3)

	assert(data[2].slot == nil)
	assert(data[2].cooldown == 10)

	assert(data[3].slot == 1)
	assert(data[3].cooldown == nil)
end

return { run = run, focus = focus }
