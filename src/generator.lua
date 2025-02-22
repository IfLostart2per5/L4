local configparser = require "src.configparser"
local generator = {}
local generator_mt = {__index=generator}

function generator.new()
	return setmetatable({
		maps = {},
		code = {},
		funcs={},
		attrs={},
		env = {}
	}, generator_mt)
end

local fenv = {math=math, table=table, string=string, load=load, ipairs=ipairs, pairs=pairs, extends = function(tbl1, tbl2) return setmetatable(tbl1, {__index=tbl2}) end, tys=require("src.std")}

configparser.setenv(fenv)
function generator:loadpass(filename)
	local f, err = io.open(filename, "r")
	if not f then error(err) end
	local l = f:read "*a"
	f:close()
	local obj = configparser.createPass(l)
	
	return obj
end

function generator:config(filename)
	self.maps = self:loadpass(filename)
end

function generator:generate(node, ...)
	local f = self.maps[node.tag]
	--print(node.tag)
	f(self, node, ...)
end

function generator:write(ln)
	table.insert(self.code, ln)
end
function generator:get()
	return {
		funcs=self.funcs,
		code=table.concat(self.code)
	}
end

function generator:define_attr(name, initial)
	if not self.attrs[name] then
		self.attrs[name] = initial
	end
end

function generator:change_attr(name, vl)
	assert(self.attrs[name] ~= nil, "attr "..name.." doesn't exists")
	self.attrs[name] = vl
end

function generator:get_attr(name)
	return self.attrs[name]
end
function generator:table()
	return {}
end

function generator:list(...)
	return {...}
end

function generator:show(...)
	print(...)
end
function generator:getglobal()
	return _G or getfenv(1)
end
return generator
