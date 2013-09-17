local m = {}
local immutable_mt = {
	__newindex = function(t,k,v)
		error("Write to table is not allowed")
	end,
	__index = function(t,k)
		if(rawget(t,k) == nil) then
			error(string.format("Access to nonexisting key: %s", k))
		else
			return rawget(t,k)
		end
	end
}

function m.immutable_table(t)
	return setmetatable(t, immutable_mt)
end

return m
