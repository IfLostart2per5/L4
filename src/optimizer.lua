unpack = unpack or table.unpack

--a deeply deep clone
local function clone(tbl)
	local tbl2 = {}

	for k, v in pairs(tbl) do
		if type(v) == "table" then
			tbl2[k] = clone(v)
		else
			tbl2[k] = v
		end
	end
	return tbl2
end

--checks if a node can be evaluated as "falsy"
--  1: if this value is bool and it's value is false, okay, falsy
--  2: if this value is of other types, it's truthy.
--  3: if this value is another expression, the result is undeterminated
local function isfalsy(node)
	if node.tag == "bool" and node.value == false then
		return true
	elseif node.tag == "bool" and node.value then
		return false

	elseif node.tag == "int" or node.tag == "float" or node.tag == "string" then
		return false
	end

	return
end

--Injects a table into another
local function absorb(host, symbiose)
	for k, v in pairs(symbiose) do
		host[k] = v
	end
end

--"kills" a table, and fill it with an other
local function wither(corpse, consumer)
	local k, v = next(corpse)
	while k do
		local nk, nv = next(corpse, k)
		corpse[k] = nil
		k, v = nk, nv
	end

	absorb(corpse, consumer)
end


--- DEBUG ------------------------------------
--a counter :)
local function counter()
	local i = 0

	return function()
		print(i)
		i = i + 1
	end
end

local function show_ctx(level)
	local info = debug.getinfo(level + 1)
	print(level .. " Context {")
	for k, v in pairs(info) do
		print(" ", k, v)
	end
	print "}"
end

----- THE OPTIMIZER -------------------------
local asg_c = counter()
local optimizer = {}
local optmt = {__index=optimizer}
function optimizer.new()
	local gbl = {names={}, changed={}}
	return setmetatable({curscope=gbl, scopes={global=gbl}}, optmt)
end
local ops = {
	["+"] = function(a, b) return a + b end,
	["-"] = function(a, b) return a - b end,
	["*"] = function(a, b) return a * b end,
	["/"] = function(a, b, isint) return isint and math.floor(a / b) or a / b end,
	["<"] = function(a, b) return a < b end,
	[">"] = function(a, b) return a > b end,
	["=="] = function(a, b) return a == b end,
	["!="] = function(a, b) return a ~= b end,
	[">="] = function(a, b) return a >= b end,
	["<="] = function(a, b) return a <= b end,
	["^"] = function(a, b) return a and b end,
	["v"] = function(a, b) return a or b end,
	
}


local emptydata = {}

function optimizer:newscope(name, ...)
	local parents = {...}
	self.scopes[name] = setmetatable({names={}, changed={}, used={}}, {__index=function(t, k)
		local r = self.scopes.global.names[k]
		if not r then
			for i = 1, #parents do
				if parents[i].names[k] then
					return parents[i].names[k]
				end
			end
		end
		return r
	end})
end

function optimizer:scope(name)
	if name == "@" then
		return self.curscope
	end
	return self.scopes[name]
end
function optimizer:move2scope(sc)
	self.curscope = sc
end


function optimizer:declare(name, node)
	local cur = self:scope "@"
	if rawget(cur.names, name) then
		cur.changed[name] = true
	end
	cur.names[name] = node
end

function optimizer:get(name)
	return self:scope("@").names[name]
end


function optimizer:inline_args(params, args)
	local names = {}
	for i = 1, #params do
		names[#names + 1] = {
			tag="assign",
			name=params[i],
			val=args[i]
		}
	end

	return names
end


function optimizer:attack(node, data)
	data = data or emptydata

	if node.tag == "binop" and not data.useless_expr then
		local left = self:attack(node.left
		, {subst_id=true,
		block=data.block,
		index=data.index})


		local right = self:attack(node.right
		,{subst_id=true,
		block=data.block,
		index=data.index})

		node.left, node.right = left, right
		if (left.canattack and right.canattack) then
			local r = {
				tag=node.op:match "[+%-%*/]" and left.tag or "bool",
				value=ops[node.op](left.value, right.value, left.tag == "int"),
				canattack=true
			}
			wither(node, r)
			return r
		else
			return node
		end
	elseif (node.tag == "int" or
		node.tag == "float" or
		node.tag == "string" or
		node.tag == "bool") and not data.useless_expr then

		if node.tag == "float" and (math.floor(node.value) == node.value) then
			node.tag = "int"
		end

		node.canattack = true
		return node
	elseif node.tag == "id" then
		local sc = self:scope "@"
		local got = self:get(node.name)

		if sc.names[node.name] and  not sc.changed[node.name] then
			
			return got
		end
		
		return node
	elseif node.tag == "assign" then
		node.val = self:attack(node.val, {subst_id=true, block=data.block, index=data.index})
		--show_ctx(2)
		self:declare(node.name, node.val)
		return node
	elseif node.tag == "func" then
		local caninline = false
		self:declare(node.name, node)
		local oldsc = self:scope "@"
		self:newscope(node.name, oldsc)
		
		for i = 1, #node.params do
			self:declare(node.params[i], {tag="id", name=node.params[i]})
		end

		
		for i = 1, #node.body do
			local block = node.body[i]
			if #block.body == 0 then
				block.tag = "nogenerate"
				goto continue
			end
			if block.refc == 0 then
				block.tag = "nogenerate"
			end
			--desculpe pelo loop duplo, mas é pra facilitar o inlining de constantes e funcoes (processar primeiro assignes pra dps ir pra outras instrucoes)
			for j = 1, #block.body do
				if block.body[j].tag == "assign" then
					self:attack(block.body[j], {block=block, index=j})
				end
			end

			for j = 1, #block.body do
				--print(block.body[j].tag)
				if block.body[j].tag == "assign" then goto continue end        
				self:attack(block.body[j], {useless_expr=true, tomarkret=node, block=block, index=j})
        if block.body[j].tag == "br" and block.body[j].to == node.body[i + 1] then
          block.body[j].tag = "nogenerate"
        end
				::continue::
			end
			if #block.body <= 5 and node.name ~= "main" then
				caninline=true
			end
			::continue::
		end
		self:move2scope(oldsc)
		node.caninline = caninline
		return node
	elseif node.tag == "return" then
		node.arg = self:attack(node.arg, {subst_id=true, block=data.block, index=data.index})
		if data.tomarkret then
			data.tomarkret.retexpr = node.arg
		end
		return node
	elseif node.tag == "call" then
		--print("dai callee", node.caller.tag)
		local caller = self:attack(node.caller)
		data.callcounter = data.callcounter and data.callcounter + 1 or 1
		local oldsc = self:scope "@"
		if caller.caninline then
			node.tag = "nogenerate"
			self:newscope(data.callcounter, self:scope "@", self:scope(caller.name))
			self:move2scope(self:scope(data.callcounter))
			local args = self:inline_args(caller.params, node.args)

			for i = 1, #args do
				local asg = args[i]

				if self:scope("@").changed[asg.name] then
					self:attack(asg, {block=data.block, index=data.index})
					table.insert(data.block, data.index == 1 and 1 or data.index - 1, asg)
				else
					self:declare(asg.name, self:attack(asg.val, {subst_id=true}))
				end
			end

			for _, bl in ipairs(caller.body) do
				for _2, l in ipairs(bl.body) do
					if l.tag == "return" then
						local retexp = clone(l.arg)
						self:attack(retexp, {callcounter=data.callcounter, subst_id=true, block=data.block, index=data.index})
						self:move2scope(oldsc)
						return retexp
					end
					local l2 = clone(l)
					table.insert(data.block.body, data.index == 1 and 1 or data.index - 1, l2)
					self:attack(l2, {callcounter=data.callcounter, block=data.block, index=data.index})
				end
			end
		else
		  for i = 1, #node.args do
			  node.args[i] = self:attack(node.args[i], {subst_id=true, block=data.block, index=data.index})
		  end

		  return node
	        end
	elseif node.tag == "program" then
		for i = 1, #node do
			self:attack(node[i])
		end
		return node
	elseif node.tag == "extern" then
		--print(node.name)
		self.scopes.global[node.name] = node
		return node
	elseif node.tag == "br" then
		 
		
		return node
	elseif node.tag == "condbr" then
		local mdata = {subst_id=true, block=data.block, index=data.index}
		local cond = self:attack(node.condition, mdata)
		
		if isfalsy(cond) then
			node.tag = "br"
			node.to.tag = "nogenerate"
			node.to = node.alt
			node.alt = nil
			node.condition = nil
			self:attack(node, mdata)
		elseif isfalsy(cond) == false then
			node.tag ="br"
			node.alt.tag = "nogenerate"
			node.alt = nil
			node.condition = nil
			self:attack(node, mdata)
		end

		return node			
	else
		if data.useless_expr then
			--prit("useless", node.tag)
			node.tag = "nogenerate"
		end
		return node
	end					
end

optimizer.pass = optimizer.attack
return optimizer
