unpack = unpack or table.unpack

--tyoes here come from node.d.lua
local detector = require "src.detect_recursion"
local tys = require "src.std"
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

---i
---@param node bool | int | float | string | node
---@return boolean?
local function isfalsy(node)
  if not node.ty then
    return
  end
	if node.ty == tys.ty "Bool" and node.value == false then
		return true
	elseif node.ty == tys.ty "Bool" and node.value then
		return false 
  else
		return false
	end
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

local optimizer = {}
local optmt = {__index=optimizer}


function optimizer.new(config)
  config = config or {
    unfold_consts = true,
    assumpt_conditions=true,
    discard_deads=true,
    expand_functions=true
  }
  
	local gbl = {names={}, changed={}}
	return setmetatable({config=config, recursion_detector=detector.new(), curscope=gbl, scopes={global=gbl}}, optmt)
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


function optimizer:inline_args(paramtypes, params, args)
	local names = {}
	for i = 1, #params do
		names[#names + 1] = {
			tag="assign",
			name=params[i],
			val=args[i],
      ty=paramtypes[i]
		}
	end

	return names
end


--"Oh, poor AST. Too inefficient. Sorry, I need to attack you violently to make your efficiency better!!!"
function optimizer:attack(node, data)
	data = data or emptydata

	if self.config.unfold_consts and node.tag == "binop" and not data.useless_expr then
    --here, we have constant foldimg optimizing.
		local left = self:attack(node.left
		, {subst_id=true,
		block=data.block,
		index=data.index})


		local right = self:attack(node.right
		,{subst_id=true,
		block=data.block,
		index=data.index})

    --to reflect the changes in the ast
		node.left, node.right = left, right
		if (left.canattack and right.canattack) then
			local r = {
				tag=node.op:match "[+%-%*/]" and left.tag or "bool",
				value=ops[node.op](left.value, right.value,node.ty == tys.ty "Int"),
        ty=node.ty,
				canattack=true
			}

      --other reflect
			wither(node, r)
			return r
		else
			return node
		end
	elseif self.config.unfold_consts and(node.tag == "int" or
		node.tag == "float" or
		node.tag == "string" or
		node.tag == "bool") and not data.useless_expr then

		node.canattack = true
		return node
	elseif self.config.unfold_consts and node.tag == "id" then
		local sc = self:scope "@"
		local got = self:get(node.name)
    --constant propagation: if the name wasn't changed, it's safe to get its value
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

    local isrecursive = self.recursion_detector:isrecursive(node)
		for i = 1, #node.params do
			self:declare(node.params[i], {tag="id", name=node.params[i], ty=node.sign.attrs.params[i]})
		end
    local j = 1
    local i = 1
		while i <= #node.body  do
			local block = node.body[i]

      --eliminate useless blocks
      if self.config.discard_deads then
			  if #block.body == 0 then
				  table.remove(node.body, i)
          i = i - 1
				  goto continue
			  end
			  if block.refc == 0 then
				  table.remove(node.body, i) 
          i = i - 1
          goto continue
			  end
      end
			--double loops for assignment dumps! :D (poethickkkkk)
      --actually, it's to verify if some var was changed
			for j = 1, #block.body do
				if block.body[j].tag == "assign" then
					self:attack(block.body[j], {block=block, index=j})
				end
			end
      
			while j <= #block.body do
				--print(block.body[j].tag)
				if block.body[j].tag == "assign" then goto continue end        
				self:attack(block.body[j], {useless_expr=self.config.discard_deads, tomarkret=node, block=block, index=j})

        --branch elimination if it's followed by the block it appoints
        if self.config.discard_deads then 
          if block.body[j].tag == "nogenerate" then
            table.remove(block.body, j)
          elseif block.body[j].tag == "br" then
            local n = block.body[j]
            if n.to == node.body[i + 1] or n.to == node.body[i + 2] then
              if node.body[i + 1] and node.body[i + 1].refc == 0 then
                table.remove(node.body, i + 1)
              end

              table.remove(block.body, j)
            end
          end
        end
				::continue::
        j = j + 1
			end

      --simple heuristic to optimize: if the function body is shorter, INLINE!
			if self.config.expand_functions and not isrecursive and #block.body <= 5 and node.name ~= "main" then
				caninline=true
			end
			::continue::
      i = i + 1
		end


		self:move2scope(oldsc)
		node.caninline = caninline
		return node
	elseif node.tag == "return" then
    if node.arg.tag == "void" then
      node.desconsider = true
      return node
    end
    
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

    --inline logic
		if self.config.expand_functions and caller.caninline then
      caller.refc = caller.refc - 1
			node.tag = "nogenerate"
  
			self:newscope(data.callcounter, self:scope "@", self:scope(caller.name)) --creates a temp scope
			self:move2scope(self:scope(data.callcounter))
			local args = self:inline_args(caller.params, node.args)

			for i = 1, #args do
				local asg = args[i]
        --imsert args, enabling direct substiruition if one wasn't changed
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
            --returns the retexpr to the caller
            if l.desconsider then
              return l
            end 
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
      --just do normal call, attacling args
		  for i = 1, #node.args do
			  node.args[i] = self:attack(node.args[i], {subst_id=true, block=data.block, index=data.index})
		  end

		  return node
	        end
	elseif node.tag == "program" then
		for i = 1, #node do
			self:attack(node[i])
		end

    --second pass to eliminate nin-used functiond
    if not self.config.discard_deads then return node end
    for i = 1, #node do
      if node[i].tag == "nogenerate" then
        table.remove(node, i)
      end
      if node[i].tag == "func" then
        if node[i].refc == 0 and node[i].name ~= "main" then
          table.remove(node, i)
          self.curscope[node[i].name] = nil
        end
      end
    end
		return node
	elseif node.tag == "extern" then
		
    --declare extern names
		self.scopes.global[node.name] = node
		return node
	elseif node.tag == "br" then 
    --unfortunately I don't know that to do directly here :(
		return node
	elseif node.tag == "condbr" then
		local mdata = {subst_id=true, block=data.block, index=data.index}
		local cond = self:attack(node.condition, mdata)
		if not self.config.assumpt_conditions then
		  return node
		end
    --inlines a conditional branch, if the condition is constant
		if isfalsy(cond) then
			node.tag = "br"
			node.to.refc = node.to.refc - 1

			node.to = node.alt
			node.alt = nil
			node.condition = nil
			self:attack(node, mdata)
		elseif isfalsy(cond) == false then
			node.tag ="br"
			node.alt.refc = node.alt.refc - 1
			node.alt = nil
			node.condition = nil
			self:attack(node, mdata)
		end

		return node			
	else
    --discard statement-expressions (such as a 2 + 1; statmemt)
		if data.useless_expr then
			--prit("useless", node.tag)
			node.tag = "nogenerate"
		end
		return node
	end					
end

optimizer.pass = optimizer.attack --enables passimg it to a generalized passing structure
return optimizer
