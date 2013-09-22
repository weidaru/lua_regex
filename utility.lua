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

function m.typecheck(...)
	local mt = { 
		__concat =
		function(a,f)
			return function(...)
				--do paramter type check, must match one by one.
				assert(#a == select("#",...), 
						string.format("Incorrect number of paramters, expect %d, got %d.", #a, select("#", ...)))
				for i=1,#a,1 do
					assert(a[i] == type(select(i, ...)),
						string.format("Parater #%d does not match, expect %s, got %s.", i, a[i], type(select(i, ...))))
				end
				return f(...)
			end
		end
	}
  return setmetatable({...}, mt)
end

local docstrings = setmetatable({}, {__mode = "kv"})

function m.get_docstring(f)
	return docstrings[f];
end

function m.docstring(...)
	local mt = {
		__concat =
		function(a,f)
			--store docstring, only accept the first parameter to the docstring function.
			docstrings[a[1]] = a[2];
			return function(...)
				return f(...)
			end
		end
	}
	return setmetatable({...}, mt)
end

return m
