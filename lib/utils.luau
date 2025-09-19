local function ordered_find(arr: { number }, value: number)
	local init = 1
	local range = #arr
	while range > 0 do
		range //= 2
		local mid = init + range
		local mid_value = arr[mid]
		init = if mid_value == nil then init elseif value <= mid_value then init else mid + 1
	end
	return init
end
local function ordered_insert(arr: { number }, value: number)
	table.insert(arr, ordered_find(arr, value), value)
end
local function ordered_remove(arr: { number }, value: number)
	table.remove(arr, ordered_find(arr, value))
end

-- module
return table.freeze {
	ordered_insert = ordered_insert,
	ordered_remove = ordered_remove,
}
