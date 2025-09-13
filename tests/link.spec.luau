local key = require('@lib/key')
local link = require('@lib/link')
local run, focus, skip = {}, {}, {}

function run.link_11_sets_and_syncs_both_sides()
	local a_to_b, b_to_a = link.link_11(true)
	local a = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	-- set forward (types for link1 use set(id, value=id))
	a_to_b:set(a, b)
	assert(a_to_b:find(a) == b, 'a should link to b')
	assert(b_to_a:find(b) == a, 'b should back-link to a')

	-- change link
	local c = key.assert_ensure_id()
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
	local a_to_bs, b_to_a = link.link_1N(true)
	local a1 = key.assert_ensure_id()
	local a2 = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	-- add b under a1
	a_to_bs:set(a1, b, true)
	assert(b_to_a:find(b) == a1, 'b should back-link to a1')

	-- setting from a2 should move backlink
	a_to_bs:set(a2, b, true)
	assert(b_to_a:find(b) == a2, 'b back-link moved to a2')
	assert(a_to_bs:find(a1, b) == nil, 'b removed from a1 list')
end

function run.link_NN_syncs_both_directions()
	local a_to_bs, b_to_as = link.link_NN(true)
	local a = key.assert_ensure_id()
	local b1 = key.assert_ensure_id()
	local b2 = key.assert_ensure_id()

	a_to_bs:set(a, b1, true)
	a_to_bs:set(a, b2, true)
	assert(b_to_as:find(b1, a) == true, 'b1 has backlink to a')
	assert(b_to_as:find(b2, a) == true, 'b2 has backlink to a')

	-- remove one link
	a_to_bs:set(a, b1, nil)
	assert(a_to_bs:find(a, b1) == nil, 'forward removed')
	assert(b_to_as:find(b1, a) == nil, 'backward removed')
end

function run.link_N1_is_inverse_of_1N()
	local As_B, B_As = link.link_N1(true)
	local a1 = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	As_B:set(a1, b)
	assert(As_B:has(a1), 'removed 1 target')
	assert(B_As:has(b, a1) == true, 'backwards contains a1')

	As_B:remove(a1)
	assert(not As_B:has(a1), 'removed 1 target')
	assert(not B_As:has(b, a1), 'removed from N side too')
end

function run.link_removal_on_destroy_id()
	local a_to_b, b_to_a = link.link_11(true)
	local a = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	a_to_b:set(a, b)
	assert(a_to_b:find(a) ~= nil, 'link set')
	assert(b_to_a:find(b) == a, 'back-link set')

	-- local _ = (collectgarbage :: any)('collect')

	key.destroy_id(b)
	assert(a_to_b:find(a) == nil, 'forward removed when a destroyed')
	assert(b_to_a:find(b) == nil, 'back removed when a destroyed')
end

function run.link_11_removes_when_target_destroyed()
	local a_to_b, b_to_a = link.link_11(true)
	local a = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	a_to_b:set(a, b)
	assert(a_to_b:find(a) == b, 'a -> b set')
	assert(b_to_a:find(b) == a, 'b -> a set')

	key.destroy_id(b)
	assert(a_to_b:find(a) == nil, 'forward removed when b destroyed')
	assert(b_to_a:find(b) == nil, 'back removed when b destroyed')
end

function run.link_1N_removes_when_source_destroyed()
	local a_to_bs, b_to_a = link.link_1N(true)
	local a = key.assert_ensure_id()
	local b1 = key.assert_ensure_id()
	local b2 = key.assert_ensure_id()

	a_to_bs:set(a, b1, true)
	a_to_bs:set(a, b2, true)
	assert(b_to_a:find(b1) == a, 'b1 backlink set')
	assert(b_to_a:find(b2) == a, 'b2 backlink set')

	key.destroy_id(a)
	assert(a_to_bs:find(a, b1) == nil, 'b1 removed from a list on destroy(a)')
	assert(a_to_bs:find(a, b2) == nil, 'b2 removed from a list on destroy(a)')
	assert(b_to_a:find(b1) == nil, 'b1 backlink cleared on destroy(a)')
	assert(b_to_a:find(b2) == nil, 'b2 backlink cleared on destroy(a)')
end

function run.link_1N_removes_when_target_destroyed()
	local a_to_bs, b_to_a = link.link_1N(true)
	local a1 = key.assert_ensure_id()
	local a2 = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	a_to_bs:set(a1, b, true)
	a_to_bs:set(a2, b, true)
	assert(a_to_bs:find(a1, b) == nil, 'moved to a2 only')
	assert(a_to_bs:find(a2, b) == true, 'set under a2')
	assert(b_to_a:find(b) == a2, 'backlink to a2')

	key.destroy_id(b)
	assert(a_to_bs:find(a2, b) == nil, 'removed from a2 on destroy(b)')
	assert(b_to_a:find(b) == nil, 'backlink cleared on destroy(b)')
end

function run.link_N1_removes_when_source_destroyed()
	local As_B, B_As = link.link_N1(true)
	local a = key.assert_ensure_id()
	local b1 = key.assert_ensure_id()
	local b2 = key.assert_ensure_id()

	As_B:set(a, b1)
	As_B:set(a, b2)
	assert(not B_As:has(b1, a), 'b1 should not contain a after move')
	assert(B_As:has(b2, a) == true, 'back contains a under b2')

	key.destroy_id(a)
	assert(As_B:find(a) == nil, 'forward cleared on destroy(a)')
	assert(B_As:find(b1, a) == nil, 'b1 backlink cleared on destroy(a)')
	assert(B_As:find(b2, a) == nil, 'b2 backlink cleared on destroy(a)')
end

function run.link_N1_removes_when_target_destroyed()
	local As_B, B_As = link.link_N1(true)
	local a1 = key.assert_ensure_id()
	local a2 = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	As_B:set(a1, b)
	As_B:set(a2, b)
	assert(B_As:has(b, a2) == true, 'back contains a2 for b')

	key.destroy_id(b)
	assert(As_B:find(a1) == nil, 'a1 cleared when b destroyed')
	assert(As_B:find(a2) == nil, 'a2 cleared when b destroyed')
	assert(B_As:find(b, a2) == nil, 'back cleared when b destroyed')
end

function run.link_NN_removes_when_source_destroyed()
	local a_to_bs, b_to_as = link.link_NN(true)
	local a = key.assert_ensure_id()
	local b1 = key.assert_ensure_id()
	local b2 = key.assert_ensure_id()

	a_to_bs:set(a, b1, true)
	a_to_bs:set(a, b2, true)
	assert(b_to_as:find(b1, a) == true, 'b1 backlink set')
	assert(b_to_as:find(b2, a) == true, 'b2 backlink set')

	key.destroy_id(a)
	assert(a_to_bs:find(a, b1) == nil, 'forward b1 removed on destroy(a)')
	assert(a_to_bs:find(a, b2) == nil, 'forward b2 removed on destroy(a)')
	assert(b_to_as:find(b1, a) == nil, 'b1 backlink cleared on destroy(a)')
	assert(b_to_as:find(b2, a) == nil, 'b2 backlink cleared on destroy(a)')
end

function run.link_NN_removes_when_target_destroyed()
	local a_to_bs, b_to_as = link.link_NN(true)
	local a1 = key.assert_ensure_id()
	local a2 = key.assert_ensure_id()
	local b = key.assert_ensure_id()

	a_to_bs:set(a1, b, true)
	a_to_bs:set(a2, b, true)
	assert(b_to_as:find(b, a1) == true, 'back contains a1')
	assert(b_to_as:find(b, a2) == true, 'back contains a2')

	key.destroy_id(b)
	assert(a_to_bs:find(a1, b) == nil, 'a1 -> b removed on destroy(b)')
	assert(a_to_bs:find(a2, b) == nil, 'a2 -> b removed on destroy(b)')
	assert(b_to_as:find(b, a1) == nil, 'back a1 cleared on destroy(b)')
	assert(b_to_as:find(b, a2) == nil, 'back a2 cleared on destroy(b)')
end

return { run = run, skip = skip, focus = focus }
