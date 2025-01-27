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

function builder:block(name)
	return {
		tag="block",
		name=name,
		body={},
		push = function(s, i)
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
