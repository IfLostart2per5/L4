unpack = unpack or table.unpack

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
	["/"] = function(a, b, isint) return isint and math.floor(a / b) or a / b end
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
		--print("olha "..name.." sendo alterado denovo")
		cur.changed[name] = true
	end
	cur.names[name] = node
end

function optimizer:get(name)
	--swlf:scope("@").used[name] = true
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
	--print(node.tag)
	if node.tag == "binop" and not data.useless_expr then
		local left = self:attack(node.left, {subst_id=true, block=data.block, index=data.index})
		local right = self:attack(node.right, {subst_id=true, block=data.block, index=data.index})
		--print("OPERACAO", left.tag, right.tag)
		node.left, node.right = left, right
		if (left.canattack and right.canattack) then
			return {
				tag=left.tag,
				value=ops[node.op](left.value, right.value, left.tag == "int"),
				canattack=true
			}
		else
			return node
		end
	elseif (node.tag == "int" or node.tag == "float" or node.tag == "string") and not data.useless_expr then
		--print("was", node.value)
		node.canattack = true
		return node
	elseif node.tag == "id" then
		local sc = self:scope "@"
		local got = self:get(node.name)
		--print("vamos ver se vai... com "..node.name)
		if sc.names[node.name] and  not sc.changed[node.name] then
			--print("foi!!", got.tag)
			return got
		end
		--print("nao?", sc.names[node.name], sc.changed[node.name])
		return node
	elseif node.tag == "assign" then
		node.val = self:attack(node.val, {subst_id=true, block=data.block, index=data.index})
		self:declare(node.name, node.val)
		return node
	elseif node.tag == "func" then
		local caninline = false
		self:declare(node.name, node)
		local oldsc = self:scope "@"
		self:newscope(node.name, oldsc)
		--print("body", node.body, #node.body)
		for i = 1, #node.params do
			self:declare(node.params[i], {tag="id", name=node.params[i]})
		end	
		for i = 1, #node.body do
			local block = node.body[i]
			--print(node.name, #block.body)
			
			--desculpe pelo loop duplo, mas é pra facilitar o inlining de constantes e funcoes (processar primeiro assignes pra dps ir pra outras instrucoes)
			for j = 1, #block.body do
				if block.body[j].tag == "assign" then
					self:attack(block.body[j], {block=block, index=j})
				end
			end

			for j = 1, #block.body do
				--print(block.body[j].tag)
				if node.tag == "assign" then goto continue end
				self:attack(block.body[j], {useless_expr=true, tomarkret=node, block=block, index=j})

				::continue::
			end
			if #block.body <= 5 and node.name ~= "main" then
				caninline=true
			end
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
					self:declare(asg.name, self:attack(asg.val, {subst_id=true}, true))
				end
			end

			for _, bl in ipairs(caller.body) do
				for _2, l in ipairs(bl.body) do
					if l.tag == "return" then
						local retexp = clone(l.arg)
						self:attack(retexp, {callcounter=data.callcounter, subst_id, block=data.block, index=data.index})
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
