local m = {}

function m.new_stack() 
	return setmetatable({}, {
		__newindex = function(t,k,v)
			error("Mutate statck through index is not allowed.")
		end
	})
end

function m.push(stack, data)
	table.insert(stack, #stack+1, data)
end

function m.pop(stack)
	data = stack[#stack]
	table.remove(stack, #stack)
	return data
end

function m.peek(stack)
	return stack[#stack]
end

function m.dump_stack(stack, sep)
	return table.concat(stack, sep)
end

return m