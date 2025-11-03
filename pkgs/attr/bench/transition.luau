local archetype = require '@lib/archetype'
local next_archetype_with = archetype.next_archetype_with

local entity_archetype = require '@lib/entity_archetype'
local key = require '@lib/key'
local id = key.ensure_id

local run = {}
local N = 1000

function run.several_archetype()
	local subject = key.ensure_id()
	local arch = next_archetype_with(nil, id() :: number)

	local a = os.clock()
	for i = 1, N do
		arch = next_archetype_with(arch, id() :: number)
	end
	entity_archetype.set(subject, arch)
	local b = os.clock()
	print(b - a)
end

function run.large_archetype()
	local attr = key.ensure_id()
	archetype.with_attr(attr)

	local a = os.clock()
	for i = 1, N do
		local ntt = key.ensure_id()
		entity_archetype.set(ntt, attr)
	end
	local b = os.clock()
	print('archetype with 1000 entities', b - a)
end

run.several_archetype()
run.large_archetype()
