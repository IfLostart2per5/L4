--note: type definitions come from "node.d.lua" file.

---@class builder
local builder = {}
local builder_mt = {__index=builder}


function builder.new()
	return setmetatable({
		decls={}
	}, builder_mt)
end

---Creates a variable node
---@param name string
---@param val node
---@return assign
function builder:variable(name, val)
	return {
		tag="assign",
		name=name,
		val=val
	}
end

---Creates a variable getting node (or simply, an indentifier)
---@param name string
---@return id
function builder:id(name)
	return {
		tag="id",
		name=name
	}
end

--literals here

---@param vl integer
---@return int
function builder:int(vl)
	return {
		tag="int",
		value=vl
	}
end

---@param s string
---@return str
function builder:str(s)
	return {
		tag="str",
		value=s
	}
end


---@param vl boolean
---@return bool
function builder:bool(vl)
	return {
		tag="bool",
		value=vl
	}
end

--literals end 

--Declares an extern name (usually a function)
---@param name string
---@return extern
function builder:extern(name)
	local e = {
		tag="extern",
		name=name
	}

	table.insert(self.decls, e)
	return e
end

--Calls a function
---@param caller node
---@param ... node
---@return call
function builder:call(caller, ...)
	return {
		tag="call",
		caller=caller,
		args={...}
	}
end

--Creates a binary expression
---@param left node
---@param right node
---@param op operators
---@return binop
function builder:binop(left, right, op)
	return {
		tag="binop",
		left=left,
		right=right,
		op=op
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
---@return block
function builder:block(name)
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
			table.insert(s.body, i)
		end
	}
end

--creates a function, with a blocklist, and some methods
---@param name string
---@param params string[]
---@return func
function builder:func(name, params)
	local f = {
		tag="func",
		name=name,
		params=params,
		body={},
		block=nil,
		setblock=function(s, bl)
			s.block = bl
			if #s.body == 0 then
				bl.refc = bl.refc + 1 --o bloco principal q é usado pela funcao
			end
			table.insert(s.body, bl)
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
		arg=value
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
