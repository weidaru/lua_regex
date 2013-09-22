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

--Token table.
local node_type = {CHAR=1, SPLIT=2, GROUP=3, POST=4, DOT=5, CAT=6}
local token = {CHAR=1, POSTFIX=2, END=3}
local non_terminal = {S=1, E=2}
local util= require("utility")
local stack = require("stack")
util.immutable_table(node_type)
util.immutable_table(token)
util.immutable_table(non_terminal)

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
	if p[1] == token.CHAR then			-- E->CHAR
		stack.pop(s)
		stack.push({non_terminal.E})		
		return {node_type.CHAR, p[2]}
	elseif p[1] == "." then				-- E->'.'
		stack.pop(s)
		stack.push({non_terminal.E})
		return {node_type.DOT}
	elseif p[1] == token.POSTFIX then	-- E->E POSTFIX
		if s[#s-1][1] == non_terminal.E then
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {non_terminal.E})
			return {node_type.POST, p[2]}
		end
	elseif p[1] == ")" then				-- E->'(' E ')'
		if s[#s-1][1]==non_terminal.E and s[#-2][1]=="(" then
			stack.pop(s)
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {non_terminal.E})
			return {node_type.GROUP}
		end
	elseif p[1] == non_terminal.E then	--E-> E '|' E
		if s[#s-1][1] == "|" and s[#s-2][1] == non_terminal.E then
			stack.pop(s)
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {non_terminal.E})
			return {node_type.SPLIT}
		elseif s[#s-1][1] == non_terminal.E then
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {non_terminal.E})
			return {node_type.CAT}
		end
	elseif p[1] == token.END then
		if #s == 2 and s[#s-1][1] == non_terminal.E then
			stack.pop(s)
			stack.pop(s)
			stack.push(s, {non_terminal.S})
			return nil
		end
	else
		return nil
	end
end

local function build_tree(node_list)
	local dump_node_list = function(list)
		local str = ""
		for _,v in ipairs(list) do
			str = str .. v[0] .. v[1] .."\n"
		end
		return str
	end

	local s = stack.new_stack()
	local leaf_type = {node_type.CHAR="", node_type.DOT=""}
	local unary_type = {node_type.GROUP="", node_type.POST=""}
	local binary_type = {node_type.SPLIT="", node_type.CAT=""}
	for i=1,#node_list,1 do
		local cur = node_list[i]
		if unary_type[cur[1]] ~= nil		--unary node type
			local temp = stack.pop(s)
			assert(temp, "Error when building trees.\n" .. dump_node_list(node_list))
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2], ["left"]=temp})
		elseif binary_type[cur[1]] ~= nil	--binary node type
			local temp1 = stack.pop()
			local temp2 = stack.pop()
			assert(temp1, "Error when building trees.\n" .. dump_node_list(node_list))
			assert(temp2, "Error when building trees.\n" .. dump_node_list(node_list))
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2], ["left"]=temp1, ["right"]=temp2})
		elseif leaf_type[cur[1]] ~= nil		--leaf node type
			stack.push(s, {["type"]=cur[1], ["data"]=cur[2]})
		else
			error(string.format("Unknown node type %s", cur[0]))
		end
	end
	return nil
end

--Parse the regex input into syntax tree.
local function parse(input)
	local s  = stack.new_stack()
	--ndoe list is built such that the node appears in reverse polish notation.
	local node_list = {}
	
	--shift each iteration
	for i=1,string.len(input),1 do
		local c = string.sub(input, i, i)
		local lexval = {lexer(c)}
		stack.push(s, lexval)
		while true
			local node = try_reduce(s)
			if node == nil 
				break
			table.insert(node_list, #node_list+1, node)
		end
	end
	stack.push(s, {token.END})
	try_reduce(s)
	if(stack.peek(s)[1] != nonterminal.S)
		return nil
	--build the tree
	return build_tree(node_list)
end

--Compile the syntax tree into bytecode.
local function compile(ast)
	
end

function m.full_match(regex, input) 
	--stub
end

function m.partial_math(regex, input)
	--stub
end

for t, d in lexer("someth+*in?g()") do
	print(t, d)
end

--return the module

return m







