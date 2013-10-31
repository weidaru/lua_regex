--[[ 
Syntax supported:
()	grouping
*	zero or more
?	zero or one
+	one or more 
|	or
Rules:
S->E$
E->E E
E->E '|' E
E->E POSTFIX
E->'(' E ')'
E->CHAR
E->'.'
--]]

--The module table.
local m = {}

local util= require("utility")
local stack = require("stack")

--Token table.
local node_type = util.immutable_table({CHAR=1, SPLIT=2, GROUP=3, POST=4, DOT=5, CAT=6})
local token = util.immutable_table({CHAR=1, POSTFIX=2, END=3, S=4, E=5})
local op_code = util.immutable_table({CHAR=1, BRANCH=2, ACCEPT=3, ANY=4, SAVE=5})


local function lexer(c)
	local temp = c
	local t = token.CHAR
	
	local post_terminals = "*?+";
	local as_it_is_terminals = "().|";

	if(string.find(post_terminals, temp, 1, true) ~= nil) then
		t = token.POSTFIX
	elseif(string.find(as_it_is_terminals, temp, 1, true) ~= nil) then
		t = temp
	end

	return t, temp
end

--[[
Do everything manually instead of using a parsing table which could be complicated and hard to debug
Look ahead is not implemented.
]]--
local function try_reduce(s)
	local p = stack.peek(s)
	if(p == nil) then
		return nil
	end
	
	if p[1] == token.CHAR then							-- E->CHAR
		stack.pop(s)
		stack.push(s, {token.E})		
		return {node_type.CHAR, p[2]}
	elseif p[1] == "." then								-- E->'.'
		stack.pop(s)
		stack.push(s, {token.E})
		return {node_type.DOT}
	elseif p[1] == token.POSTFIX then					-- E->E POSTFIX
		if s[#s-1][1] == token.E then
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {token.E})
			return {node_type.POST, p[2]}
		end
	elseif p[1] == ")" then								-- E->'(' E ')'
		if #s>=3 and s[#s-1][1]==token.E and s[#s-2][1]=="(" then
			stack.pop(s)
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {token.E})
			return {node_type.GROUP}
		end
	elseif p[1] == token.E then							--E-> E '|' E
		if #s>=3 and s[#s-1][1] == "|" and s[#s-2][1] == token.E then
			stack.pop(s)
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {token.E})
			return {node_type.SPLIT}
		elseif #s>=2 and s[#s-1][1] == token.E then		--E-> E E
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {token.E})
			return {node_type.CAT}
		end
	elseif p[1] == token.END then
		if #s == 2 and s[#s-1][1] == token.E then
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {token.S})
			return nil
		end
	else
		return nil
	end
end

local function find_key(t, value)
	for k,v in pairs(t) do
		if v == value then
			return k
		end
	end
	error(string.format("No key corresponding to value. %s", value))
end

local function dump_node_list(list)
	local str = ""
	for _,v in ipairs(list) do
		str = string.format("%s%s\t%s\n", str, find_key(node_type, v[1]), v[2])
	end
	return str
end

local function dump_stack(stack)
	local str = ""
	for _,v in ipairs(stack) do
		str = string.format("%s%d\t", str, v[1])
	end
end

local function dump_tree(tree)
	local function _dump_tree(node)
		if node then
			local left_str = _dump_tree(node.left)
			local right_str = _dump_tree(node.right)
			
			if left_str == nil and right_str == nil then
				return string.format("(%s)",find_key(node_type, node.type))
			elseif right_str == nil then
				return string.format("(%s %s)",find_key(node_type, node.type), left_str)
			else
				return string.format("(%s %s %s)",find_key(node_type, node.type), left_str, right_str)
			end
			assert(false)
		else 
			return nil
		end
	end
	
	return _dump_tree(tree)
end

local function dump_program(program)
	local str=""
	for i,inst in ipairs(program) do
		if i == #program then
			str = string.format("%s%d:\t%s %s %s", str, i, find_key(op_code, inst[1]), inst[2], inst[3])
		else
			str = string.format("%s%d:\t%s %s %s\n", str, i, find_key(op_code, inst[1]), inst[2], inst[3])
		end
	end
	return str
end

local function dump_match(result)
	local str = ""
	if not result then
		return "No match"
	end
	for i=0,#result,1 do
		local v = result[i]
		str = string.format("%s$%d:\t%s\t%d\t%d\n", str,i,v.match, v.s, v.e)
	end
	return str
end

local function build_tree(node_list)
	local s = stack.new_stack()
	local leaf_type = {[node_type.CHAR]="", [node_type.DOT]=""}
	local unary_type = {[node_type.GROUP]="", [node_type.POST]=""}
	local binary_type = {[node_type.SPLIT]="", [node_type.CAT]=""}
	for i=1,#node_list,1 do
		local cur = node_list[i]
		if unary_type[cur[1]] ~= nil then		--unary node type
			local temp = stack.pop(s)
			assert(temp, "Error when building trees.\n" .. dump_node_list(node_list))
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2], ["left"]=temp})
		elseif binary_type[cur[1]] ~= nil then	--binary node type
			local temp1 = stack.pop(s)
			local temp2 = stack.pop(s)
			assert(temp1, "Error when building trees.\n" .. dump_node_list(node_list))
			assert(temp2, "Error when building trees.\n" .. dump_node_list(node_list))
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2], ["left"]=temp2, ["right"]=temp1})
		elseif leaf_type[cur[1]] ~= nil	then	--leaf node type
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2]})
		else
			error(string.format("Unknown node type %s", cur[0]))
		end
	end
	assert(#s == 1)
	return s[1]
end

--[[
Parse the regex input into syntax tree. 
As look ahead is not implemented, there is no precedence to different operators.
All the operator associate from left to right.
]]--
local function parse(input)
	local s  = stack.new_stack()
	--node list is built such that the node appears in reverse polish notation.
	local node_list = {}
	
	--shift each iteration
	for i=1,string.len(input),1 do
		local c = string.sub(input, i, i)
		local lexval = {lexer(c)}
		stack.push(s, lexval)
		while true do
			local node = try_reduce(s)
			if node == nil then
				break
			end
			table.insert(node_list, #node_list+1, node)
		end
	end
	stack.push(s, {token.END})
	try_reduce(s)
	
	if stack.peek(s)[1] ~= token.S then
		return nil
	end
	--build the tree
	local tree = build_tree(node_list)
	--print(dump_tree(tree))
	return tree
end

--Compile the syntax tree into bytecode.
local function compile(ast)
	--merge the second list into the first
	local function merge(first, second)
		for i=1,#second,1 do
			table.insert(first, #first+1, second[i])
		end
	end

	local group_count = 0
	local function _compile(node)
		if node.type == node_type.CHAR then
			local program = {}
			program[1] = {op_code.CHAR, node.data}
			return program
		elseif node.type == node_type.DOT then
			local program = {}
			program[1] = {op_code.ANY}
			return program
		elseif node.type == node_type.CAT then
			local first = _compile(node.left)
			local second = _compile(node.right)
			merge(first, second)
			return first
		elseif node.type == node_type.GROUP then
			local program = {}
			local old_gc  = group_count
			program[1] = {op_code.SAVE, group_count*2+1}
			group_count = group_count+1
			local sub = _compile(node.left)
			merge(program, sub)
			program[#program+1] = {op_code.SAVE, old_gc*2+2}
			
			return program
		elseif node.type == node_type.POST then
			local program = {}
			local sub = _compile(node.left)
			if node.data == "+" then
				merge(program, sub)
				table.insert(program, #program+1, {op_code.BRANCH, -#sub, 1})
			elseif node.data == "?" then
				table.insert(program, #program+1, {op_code.BRANCH, 1, #sub+1})
				merge(program, sub)
			elseif node.data == "*" then
				table.insert(program, #program+1, {op_code.BRANCH, 1, #sub+2})
				merge(program, sub)
				table.insert(program, #program+1, {op_code.BRANCH, -#sub, 1})
				
			else
				error("Unknown symbol for POSTFIX token. ".. node.data)
			end
			return program
		elseif node.type == node_type.SPLIT then
			local program = {}
			local sub1 = _compile(node.left)
			local sub2 = _compile(node.right)
			table.insert(program, #program+1, {op_code.BRANCH, 1, #sub1+2})
			merge(program, sub1)
			table.insert(program, #program+1, {op_code.BRANCH, #sub2+1})
			merge(program, sub2)
			return program
		else
			error("Unknown node type. " .. find_key(node_type, node.type))
		end
	end

	--add a group node on top
	ast = {["type"]=node_type.GROUP, ["left"]=ast}
	local program = _compile(ast)
	table.insert(program, #program+1, {op_code.ACCEPT})
	return program
end

local function thread_create()
	return {["pc"]=1, ["sub"]={}, ["sp"]=1}
end

local function thread_copy(t) 
	local new_t = thread_create()
	new_t.pc = t.pc
	new_t.sp = t.sp
	for k,v in pairs(t.sub) do
		new_t.sub[k] = v
	end
	return new_t
end

local function thread_add(program, thread, input, list)
	local c = string.sub(input, thread.sp, thread.sp)
	local inst = program[thread.pc]
	if inst[1] == op_code.ANY then
		thread.pc = thread.pc+1
		thread.sp = thread.sp+1
		table.insert(list, #list+1, thread)
	elseif inst[1] == op_code.BRANCH then
		if inst[3] then			--two branches
			--first
			local new_thread = thread_copy(thread)
			new_thread.pc = new_thread.pc + inst[2]
			table.insert(list, #list+1, new_thread)
			--second
			thread.pc = thread.pc+inst[3]
			table.insert(list, #list+1, thread)
		else					--one branch, same as jmp
			thread.pc = thread.pc+inst[2]
			table.insert(list, #list+1, thread)
		end
	elseif inst[1] == op_code.SAVE then
		thread.pc = thread.pc+1
		thread.sub[inst[2]] = thread.sp
		table.insert(list, #list+1, thread)
	elseif inst[1] == op_code.ACCEPT then
		return true
	else
		error("Unknown op_code " .. inst[1])
	end
	
	return false
end

function m.full_match(regex, input)
	local program = 0
	if type(regex) == "string" then
		local ast = parse(regex)
		program = compile(ast)
	elseif type(regex) == "table" then
		program = regex
	else
		error("Bad input, regex")
	end
	
	local clist = {}
	
	table.insert(clist, 1, thread_create())
	local matched = false
	local matched_sub = 0
	while #clist ~= 0 do
		local nlist = {}
		for j=1,#clist,1 do
			local inst = program[clist[j].pc]
			local c = string.sub(input, clist[j].sp, clist[j].sp)
			if inst[1] == op_code.CHAR then
				if inst[2] == c then
					clist[j].pc = clist[j].pc+1
					clist[j].sp = clist[j].sp+1
					table.insert(nlist, #nlist+1, clist[j])
				end
			elseif thread_add(program, clist[j], input, nlist) then
				local match_thread = clist[j]
				--Check whether thats a full match or not
				if match_thread.sub[1] == 1 and match_thread.sub[2] == #input+1 then
					matched = true
					matched_sub = match_thread.sub
					assert(#matched_sub%2 == 0)
					break
				end
			end
		end
		if matched then
			break
		end
		clist = nlist
	end

	if matched then
		local result = {}
		for i=1,#matched_sub/2,1 do
			result[i-1] = {match = string.sub(input, matched_sub[i*2-1], matched_sub[i*2]-1), 
						 s = matched_sub[i*2-1], e =  matched_sub[i*2]-1}
		end
		return result
	else
		return nil
	end
end

function m.partial_match(regex, input)
	local program = 0
	if type(regex) == "string" then
		local ast = parse(regex)
		program = compile(ast)
	elseif type(regex) == "table" then
		program = regex
	else
		error("Bad input, regex")
	end
	
	
	local matched = false
	local matched_sub = 0
	for i=1,#input,1 do 
		local clist = {}
		table.insert(clist, 1, thread_create())
		clist[1].sp = i
		while #clist ~= 0 do
			local nlist = {}
			for j=1,#clist,1 do
				local inst = program[clist[j].pc]
				local c = string.sub(input, clist[j].sp, clist[j].sp)
				if inst[1] == op_code.CHAR then
					if inst[2] == c then
						clist[j].pc = clist[j].pc+1
						clist[j].sp = clist[j].sp+1
						table.insert(nlist, #nlist+1, clist[j])
					elseif clist[j].sp < #input then			--Cannot match, start over but keep sp increased
						clist[j].pc = 1
						clist[j].sub = {}
						clist[j].sp = clist[j].sp+1
						table.insert(nlist, #nlist+1, clist[j])
					end
				elseif thread_add(program, clist[j], input, nlist) then
					local match_thread = clist[j]
					matched = true
					matched_sub = match_thread.sub
					assert(#matched_sub%2 == 0)
					break
				end
			end
			if matched then
				break
			end
			clist = nlist
		end
		if matched then
			break
		end
	end

	if matched then
		local result = {}
		for i=1,#matched_sub/2,1 do
			result[i-1] = {match = string.sub(input, matched_sub[i*2-1], matched_sub[i*2]-1), 
						 s = matched_sub[i*2-1], e =  matched_sub[i*2]-1}
		end
		return result
	else
		return nil
	end
end

--test code, delete later.
local ast = parse("ab")
print("Tree:")
print(dump_tree(ast))
local program = compile(ast)
print("Program:")
print(dump_program(program))
local result = m.partial_match(program, "aab")
print("Result:")
print(dump_match(result))

--return the module
return m







