-- functions
local function assert_unordered_array<V>(array: { V }, expecteds: { V })
	local missing = table.clone(array)
	for _, expected in expecteds do
		local index = table.find(missing, expected)
		if index == nil then error(`not found element '{expected}'`, 2) end
		table.remove(missing, index)
	end

	if #missing > 0 then error(`theres extra elements {table.concat(missing, ', ')}`, 2) end
	return true
end

-- module
return table.freeze {
	unordered_array = assert_unordered_array,
}
