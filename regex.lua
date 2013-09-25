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

--Do everything manually instead of using a parsing table which could be complicated and hard to debug
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
		str = string.format("%s%d:\t%s %s %s\n", str, i, find_key(op_code, inst[1]), inst[2], inst[3])
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

--Parse the regex input into syntax tree.
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
			program[1] = {op_code.SAVE, group_count*2+1}
			local sub = _compile(node.left)
			merge(program, sub)
			program[#program+1] = {op_code.SAVE, group_count*2+2}
			group_count = group_count+1
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
				table.insert(program, #program+1, {op_code.BRANCH, 0, #sub+1})
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

	local program = _compile(ast)
	table.insert(program, #program+1, {op_code.ACCEPT})
	return program
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
	
end

function m.partial_math(regex, input)
	--stub
end

--test code, delete later.
local ast = parse("(a+)|(b|c)")
local program = compile(ast)
print(dump_program(program))

--return the module
return m







