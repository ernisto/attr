local archetype = require('../lib/archetype')
local graph = require('../lib/archetype/graph')
local key = require('../lib/key')
local run = {}

local N = 1000

local id = key.ensure_id
local next_archetype_with = graph.next_archetype_with

function run.several_archetype()
	local subject = key.ensure_id()
	local arch = next_archetype_with(nil, id())

	local a = os.clock()
	for i = 1, N do
		arch = next_archetype_with(arch, id())
	end
	archetype.set(subject, arch)
	local b = os.clock()
	print(b - a)
end

function run.large_archetype()
	local attr = key.ensure_id()
	archetype.with_attr(attr)

	local a = os.clock()
	for i = 1, N do
		local ntt = key.ensure_id()
		archetype.set(ntt, attr)
	end
	local b = os.clock()
	print('archetype with 1000 entities', b - a)
end

run.several_archetype()
run.large_archetype()
