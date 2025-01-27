local configparser = require "src.configparser"
local generator = {}
local generator_mt = {__index=generator}

function generator.new()
	return setmetatable({
		maps = {},
		passes = {},
		code = {},
		funcs={},
		env = {}
	}, generator_mt)
end

local fenv = {math=math, table=table, string=string, load=load, ipairs=ipairs, pairs=pairs, extends = function(tbl1, tbl2) return setmetatable(tbl1, {__index=tbl2}) end}

configparser.setenv(fenv)
function generator:loadmap(filename, maps)
	local f, err = io.open(filename, "r")
	maps = maps or {}
	if not f then error(err) end
	local l = f:read "*a"
	f:close()
	configparser.parse(l, maps)
	
	return maps
end

function generator:config(filename)
	self:loadmap(filename, self.maps)
end

function generator:loadpass(filename)
	table.insert(self.passes, self:loadmap(filename))
end

function generator:generate(node)
	local f = self.maps[node.tag]
	--print(node.tag)
	f(self, node)
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

function generator:show(...)
	print(...)
end
function generator:getglobal()
	return _G or getfenv(1)
end
return generator
