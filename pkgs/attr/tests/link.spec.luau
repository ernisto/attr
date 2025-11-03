local cleanup = require '@lib/cleanup'
local key = require '@lib/key'
local link = require '@lib/link'
local run, focus, skip = {}, {}, {}

function run.link_11_sets_and_syncs_both_sides()
	local a_to_b, b_to_a = link.link_11()
	local _, a = key.ensure_id()
	local _, b = key.ensure_id()

	-- set forward (types for link1 use set(id, value=id))
	a_to_b:set(a, b)
	assert(a_to_b:find(a) == b, 'a should link to b')
	assert(b_to_a:find(b) == a, 'b should back-link to a')

	-- change link
	local _, c = key.ensure_id()
	a_to_b:set(a, c)
	assert(a_to_b:find(a) == c, 'a should link to c now')
	assert(b_to_a:find(c) == a, 'c should back-link to a')
	assert(b_to_a:find(b) == nil, 'b back-link cleared')

	-- remove
	a_to_b:remove(a)
	assert(a_to_b:find(a) == nil, 'a link removed')
	assert(b_to_a:find(c) == nil, 'back-link removed too')
end

function run.link_1N_enforces_single_backlink()
	local a_to_bs, b_to_a = link.link_1N()
	local _, a1 = key.ensure_id()
	local _, a2 = key.ensure_id()
	local _, b = key.ensure_id()

	-- add b under a1
	a_to_bs:add(a1, b)
	assert(b_to_a:find(b) == a1, 'b should back-link to a1')

	-- setting from a2 should move backlink
	a_to_bs:add(a2, b)
	assert(b_to_a:find(b) == a2, 'b back-link moved to a2')
	assert(not a_to_bs:has(a1, b), 'b removed from a1 list')
end

function run.link_NN_syncs_both_directions()
	local a_to_bs, b_to_as = link.link_NN()
	local _, a = key.ensure_id()
	local _, b1 = key.ensure_id()
	local _, b2 = key.ensure_id()

	a_to_bs:add(a, b1)
	a_to_bs:add(a, b2)
	assert(b_to_as:has(b1, a), 'b1 has backlink to a')
	assert(b_to_as:has(b2, a), 'b2 has backlink to a')

	-- remove one link
	a_to_bs:remove(a, b1)
	assert(not a_to_bs:has(a, b1), 'forward removed')
	assert(not b_to_as:has(b1, a), 'backward removed')
end

function run.link_N1_is_inverse_of_1N()
	local As_B, B_As = link.link_N1()
	local _, a1 = key.ensure_id()
	local _, b = key.ensure_id()

	As_B:set(a1, b)
	assert(As_B:has(a1), 'removed 1 target')
	assert(B_As:has(b, a1), 'backwards contains a1')

	As_B:remove(a1)
	assert(not As_B:has(a1), 'removed 1 target')
	assert(not B_As:has(b, a1), 'removed from N side too')
end

function run.link_removal_on_destroy_id()
	local a_to_b, b_to_a = link.link_11()
	local _, a = key.ensure_id()
	local _b, b = key.ensure_id()

	a_to_b:set(a, b)
	assert(a_to_b:find(a) == b, 'link set')
	assert(b_to_a:find(b) == a, 'back-link set')

	-- local _ = (collectgarbage :: any)('collect')

	cleanup.destroy(b)
	assert(a_to_b:find(a) == nil, 'forward removed when a destroyed')
	assert(b_to_a:find(_b) == nil, 'back removed when a destroyed')
end

function run.link_11_removes_when_target_destroyed()
	local a_to_b, b_to_a = link.link_11()
	local _, a = key.ensure_id()
	local _b, b = key.ensure_id()

	a_to_b:set(a, b)
	assert(a_to_b:find(a) == b, 'a -> b set')
	assert(b_to_a:find(b) == a, 'b -> a set')

	cleanup.destroy(b)
	assert(a_to_b:find(a) == nil, 'forward removed when b destroyed')
	assert(b_to_a:find(_b) == nil, 'back removed when b destroyed')
end

function run.link_1N_removes_when_source_destroyed()
	local a_to_bs, b_to_a = link.link_1N()
	local _a, a = key.ensure_id()
	local _, b1 = key.ensure_id()
	local _, b2 = key.ensure_id()

	a_to_bs:add(a, b1)
	a_to_bs:add(a, b2)
	assert(b_to_a:find(b1) == a, 'b1 backlink set')
	assert(b_to_a:find(b2) == a, 'b2 backlink set')

	cleanup.destroy(a)
	assert(not a_to_bs:has(_a, b1), 'b1 removed from a list on destroy(a)')
	assert(not a_to_bs:has(_a, b2), 'b2 removed from a list on destroy(a)')
	assert(b_to_a:find(b1) == nil, 'b1 backlink cleared on destroy(a)')
	assert(b_to_a:find(b2) == nil, 'b2 backlink cleared on destroy(a)')
end

function run.link_1N_removes_when_target_destroyed()
	local a_to_bs, b_to_a = link.link_1N()
	local _, a1 = key.ensure_id()
	local _, a2 = key.ensure_id()
	local _b, b = key.ensure_id()

	a_to_bs:add(a1, b)
	a_to_bs:add(a2, b)
	assert(not a_to_bs:has(a1, b), 'moved to a2 only')
	assert(a_to_bs:has(a2, b), 'set under a2')
	assert(b_to_a:find(b) == a2, 'backlink to a2')

	cleanup.destroy(b)
	assert(not a_to_bs:has(a2, _b), 'removed from a2 on destroy(b)')
	assert(b_to_a:find(_b) == nil, 'backlink cleared on destroy(b)')
end

function run.link_N1_removes_when_source_destroyed()
	local As_B, B_As = link.link_N1()
	local _a, a = key.ensure_id()
	local _, b1 = key.ensure_id()
	local _, b2 = key.ensure_id()

	As_B:set(a, b1)
	As_B:set(a, b2)
	assert(not B_As:has(b1, a), 'b1 should not contain a after move')
	assert(B_As:has(b2, a), 'back contains a under b2')

	cleanup.destroy(a)
	assert(As_B:find(_a) == nil, 'forward cleared on destroy(a)')
	assert(not B_As:has(b1, _a), 'b1 backlink cleared on destroy(a)')
	assert(not B_As:has(b2, _a), 'b2 backlink cleared on destroy(a)')
end

function run.link_N1_removes_when_target_destroyed()
	local As_B, B_As = link.link_N1()
	local _, a1 = key.ensure_id()
	local _, a2 = key.ensure_id()
	local _b, b = key.ensure_id()

	As_B:set(a1, b)
	As_B:set(a2, b)
	assert(B_As:has(b, a1), 'back contains a1 for b')
	assert(B_As:has(b, a2), 'back contains a2 for b')

	cleanup.destroy(b)
	assert(As_B:find(a1) == nil, 'a1 cleared when b destroyed')
	assert(As_B:find(a2) == nil, 'a2 cleared when b destroyed')
	assert(not B_As:has(_b, a1), 'back cleared when b destroyed')
	assert(not B_As:has(_b, a2), 'back cleared when b destroyed')
end

function run.link_NN_removes_when_source_destroyed()
	local a_to_bs, b_to_as = link.link_NN()
	local _a, a = key.ensure_id()
	local _, b1 = key.ensure_id()
	local _, b2 = key.ensure_id()

	a_to_bs:add(a, b1)
	a_to_bs:add(a, b2)
	assert(b_to_as:has(b1, a), 'b1 backlink set')
	assert(b_to_as:has(b2, a), 'b2 backlink set')

	cleanup.destroy(a)
	assert(not a_to_bs:has(_a, b1), 'forward b1 removed on destroy(a)')
	assert(not a_to_bs:has(_a, b2), 'forward b2 removed on destroy(a)')
	assert(not b_to_as:has(b1, _a), 'b1 backlink cleared on destroy(a)')
	assert(not b_to_as:has(b2, _a), 'b2 backlink cleared on destroy(a)')
end

function run.link_NN_removes_when_target_destroyed()
	local a_to_bs, b_to_as = link.link_NN()
	local _, a1 = key.ensure_id()
	local _, a2 = key.ensure_id()
	local _b, b = key.ensure_id()

	a_to_bs:add(a1, b)
	a_to_bs:add(a2, b)
	assert(b_to_as:has(b, a1), 'back contains a1')
	assert(b_to_as:has(b, a2), 'back contains a2')

	cleanup.destroy(b)
	assert(not a_to_bs:has(a1, _b), 'a1 -> b removed on destroy(b)')
	assert(not a_to_bs:has(a2, _b), 'a2 -> b removed on destroy(b)')
	assert(not b_to_as:has(_b, a1), 'back a1 cleared on destroy(b)')
	assert(not b_to_as:has(_b, a2), 'back a2 cleared on destroy(b)')
end

return { run = run, skip = skip, focus = focus }
