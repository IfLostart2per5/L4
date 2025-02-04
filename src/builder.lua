local builder = {}
local builder_mt = {__index=builder}


function builder.new()
	return setmetatable({
		decls={}
	}, builder_mt)
end

function builder:variable(name, val)
	return {
		tag="assign",
		name=name,
		val=val
	}
end

function builder:id(name)
	return {
		tag="id",
		name=name
	}
end

function builder:int(vl)
	return {
		tag="int",
		value=vl
	}
end

function builder:str(s)
	return {
		tag="str",
		value=s
	}
end

function builder:bool(vl)
	return {
		tag="bool",
		value=vl
	}
end
function builder:extern(name)
	local e = {
		tag="extern",
		name=name
	}

	table.insert(self.decls, e)
	return e
end

function builder:call(caller, ...)
	return {
		tag="call",
		caller=caller,
		args={...}
	}
end

function builder:binary_op(left, right, op)
	return {
		tag="binop",
		left=left,
		right=right,
		op=op
	}
end

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

function builder:ret(value)
	return {
		tag="return",
		arg=value
	}
end

function builder:get()
	self.decls.tag = "program"
	local decls = self.decls
	self.decls = {}
	return decls
end

return builder
