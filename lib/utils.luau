local function ordered_insert(arr: { number }, value: number)
	local init = 1
	local range = #arr
	while range > 0 do
		range //= 2
		local mid = init + range
		local mid_value = arr[mid]
		init = if mid_value == nil then init elseif value <= mid_value then init else mid + 1
	end
	table.insert(arr, init, value)
end
local function ordered_remove(arr: { number }, value: number)
	local init = 1
	local range = #arr
	while range > 0 do
		range //= 2
		local mid = init + range
		local mid_value = arr[mid]
		init = if value <= mid_value then init else mid + 1
	end
	table.remove(arr, init)
end

-- module
return table.freeze {
	ordered_insert = ordered_insert,
	ordered_remove = ordered_remove,
}
