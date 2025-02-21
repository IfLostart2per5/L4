--note: type definitions come from "node.d.lua" file.
---@alias basictypes
---| "Int"
---| "Float"
---| "String"

local tys =require("src.std")
---@class Signature : Typedef
---@field attrs {params: Typedef[], returns: Typedef}

---@alias scope { [string]: [Typedef, node] }

---@class builder
---@field decls node[]
---@field types { [string]: Typedef } 
---@field scopes { [string]: scope }
---@field assign_counters { [string]: assign }
---@field scope scope
local builder = {}
local builder_mt = {__index=builder}

--UNIQUE OBJECT
local vararg = {}
---Blocks void values
---@param node node
---@return node?
local function blockvoid(node)
  if node.ty == tys.ty "Void" then
    return error("Expected a a value, but got nothing.")
  end
  return node
end

---comment
---@param ty Typedef
---@return Typedef?
local function blockvoidty(ty)
  return assert(ty ~= tys.ty "Void" and ty, "Tyoe void for values is forbidden")
end
 

function builder.new()
  local glb = {}
	return setmetatable({
		decls={},
    scopes={global=glb},
    scope=glb,
    currentf=nil,
    types=tys.types
	}, builder_mt)
end


---@param name string | Typedef
---@return Typedef
function builder:ty(name)
  if type(name) == "table" then
    return name
  end
  assert(self.types[name], ("Type %s doesn't exists"):format(name))
  return self.types[name]
end
---Creates a variable node
---@param name string
---@param val node
---@return assign
function builder:assign(name, ty, val)
  local typ = blockvoidty(self:ty(ty))

  if self.scope[name] then
    assert(self.scope[name][1] == typ, ("Expected type %s, but got %s"):format(self.scope[name][1].name, typ.name))
    self.scope[name][2] = blockvoid(val)
  else
    self.scope[name] = {typ, blockvoid(val)}
  end
	return {
		tag="assign",
		name=name,
		val=val,
    refc=0,
    ty=typ
	}
end

function builder:_put_scope(name)
  local sc = setmetatable({}, {__index=self.scopes.global})
  self.scopes[name] = sc
  self.scope = sc
end

function builder:getid(name)
  return self.scope[name]
end

---Creates a variable getting node (or simply, an indentifier)
---@param name string
---@return id
function builder:id(name)
	return {
		tag="id",
		name=name,
    ty=assert(self:getid(name), "id "..name.." not found")[1], 
	}
end

--literals here

---@param vl integer
---@return int
function builder:int(vl)
	return {
		tag="int",
		value=assert(type(vl) == "number" and math.floor(vl), "Expected a number"),
    ty=self:ty "Int"
	}
end

---@param vl number
---@return float
function builder:float(vl)
  return {
    tag="float",
    value=assert(type(vl) == "number" and vl, "Expected a float"),
    ty=self:ty "Float"
  }
end

---@param s string
---@return str
function builder:str(s)
	return {
		tag="str",
		value=assert(type(s) == "string" and s, "Expected a string"),
    ty=self:ty "String"
	}
end


---@param vl boolean
---@return bool
function builder:bool(vl)
	return {
		tag="bool",
		value=vl,
    ty=self:ty "Bool"
	}
end

--literals end 

--Declares an extern name (usually a function)
---@param name string
---@return extern
function builder:extern(name, ty)
	local e = {
		tag="extern",
		name=name,
    ty=self:ty(ty)
	}

  self.scopes.global[name] = {e.ty, e}
	table.insert(self.decls, e)
	return e
end

--Calls a function
---@param caller node
---@param ... node
---@return call
function builder:call(caller, ...)
  local sign = caller.ty
  ---@cast sign Signature
  
  for i, a in ipairs({...}) do
    blockvoid(a)
    if a.ty ~= sign.attrs.params[i] and (not sign.attrs.params[i] == vararg) then
      error(("Expected %s, but got %s"):format(sign.attrs.params[i].name, a.ty.name))
    end
  end
  if caller.tag == "id" then
    ---@cast caller id
    local f = self:getid(caller.name)[2]
    if f.tag == "func" then
      ---@cast f func 
      f.refc = f.refc + 1
    end
  end
	return {
		tag="call",
		caller=caller,
		args={...},
    ty=sign.attrs.returns
	}
end

--Creates a binary expression
---@param left node
---@param right node
---@param op operators
---@return binop
function builder:binop(ty, left, right, op)
  local isbool = not (op == "+" or op == "-" or op == "*" or op == "/")
  local t = blockvoidty(self:ty(ty))
	return {
		tag="binop",
		left=blockvoid(left),
		right=blockvoid(right),
		op=op,
    ty=assert((not isbool and ( left.ty == t and right.ty == t) and t or nil) or (t == self:ty "Bool" and t), ("Types %s and %s are imcompatible with %s"):format(left.ty.name, right.ty.name, ty.name))
	}
end

--Creates a branch or conditional branching, depending on arguments

---@overload fun(tblock: block): br
---@param condition node
---@param tblock block
---@param fblock block?
---@return table
function builder:branch(condition, tblock, fblock)
	local cond = "cond"
  blockvoid(condition)
	if not tblock then
		tblock = condition
		condition = nil
		cond = ""
	end
	tblock.refc = tblock.refc + 1
	if fblock then
		fblock.refc = fblock.refc + 1
	end
	return {
		tag=cond .. "br",
		to=tblock,
		alt=fblock,
		condition=condition
	}
end

---Creates a named statments list (block)
---@param name string
---@param func Signature?
---@return block
function builder:block(name, func)
  local retty = func and func.attrs.returns
	return {
		tag="block",
		name=name,
		refc=0,
		body={},
		push = function(s, i)
			if i.tag == "br" or i.tag == "condbr" then
				if i.to == s or i.alt == s then
					s.isloop = true
				end
			end
      if retty then
        if i.tag == "return" then
          assert(i.arg.ty == retty, ("Expected %s, but got %s"):format(retty == self:ty "Void" and "no value" or retty.name .. " type", retty == self:ty "Void" and "one" or retty.name .. " type"))
        end
      end
			table.insert(s.body, i)
		end
	}
end


---@return table
function builder:vararg()
	return vararg
end

---@return Signature
function builder:signature(...)
  local args = {...}

  local params = {}
  for i = 1, #args - 1 do
    if args[i] == vararg then
	    break
    end
    params[#params+1] = self:ty(args[i])
  end

  local returns = self:ty(args[#args])
  return {name="function", attrs={params=params, returns=returns}}
end
--creates a function, with a blocklist, and some methods
---@param name string
---@param params string[]
---@param signature Signature
---@return func
function builder:func(name, params, signature)
  self:_put_scope(name)
  for i, v in ipairs(params) do
    self.scope[v] = {signature.attrs.params[i], {tag="boiler"}}
  end
	local f = {
		tag="func",
		name=name,
		params=params,
    sign=signature,
		body={},
    refc=0,
    previous={},
		block=nil,
		setblock=function(s, bl)
			s.block = bl
			if #s.body == 0 then
				bl.refc = bl.refc + 1 --o bloco principal q é usado pela funcao
			end
      if not s.previous[bl] then
			  table.insert(s.body, bl)
        s.previous[bl] = true
      end
		end,
		push=function(s, i)
			s.block:push(i)
		end
	}

	table.insert(self.decls, f)

	return f
end

--Creates a return statment 
---@param value node
---@return return
function builder:ret(value)
	return {
		tag="return",
		arg=value or {
      tag="void",
      ty=self:ty "Void"
    }
	}
end

---Finalize the program building
---@return program
function builder:get()
	self.decls.tag = "program"
	local decls = self.decls
	self.decls = {}
	return decls
end

return builder
