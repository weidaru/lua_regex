--[[ 
Syntax supported:
()	grouping
*	zero or more
?	zero or one
+	one or more 
|	or
Rules:
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
local token = {CHAR=1, POSTFIX=2}
local util= require("utility")
util.immutable_table(token)


local function lex_iter(state)
	if state.cur > string.len(state.input) then
		return nil
	else
		local temp = string.sub(state.input, state.cur, state.cur)
		local t = token.CHAR
		
		local post_terminals = "*?+";
		local as_it_is_terminals = "().|";

		if(string.find(post_terminals, temp, 1, true) ~= nil) then
			t = token.POSTFIX
		elseif(string.find(as_it_is_terminals, temp, 1, true) ~= nil) then
			t = temp
		end
		
		state.cur = state.cur+1
		return t, temp
	end
end

--Lexcical analysis
local function lexer(str)
	local state = {input = str, cur=1}
	return lex_iter, state, nil
end

--Parse the regex input into syntax tree.
local function parse(input)
	for t,d in lexer(input) do
		--stub do rule match.
	end
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







