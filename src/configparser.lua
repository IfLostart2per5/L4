local lpeg = require "lpeg"
local P, S, V, C, Ct = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct
DEBUG = false
local locale = lpeg.locale()

local space = locale.space^0
local alpha = locale.alpha
local alnum = locale.alnum

local cfg = {
  env = nil
}
local id = C((alpha + "_") * (alnum + "_")^0) * space
local function sym(s)
	return P(s) * space
end

local function rule(p)
	return space * p
end

local G = P {
	"decls",
	decls = Ct(V"decl" * ((sym ";" + sym "\n") * V"decl")^0 * (sym ";")^-1),
	decl = rule(id * V("params")^-1 * V"code"/ function(name, params, block)
		if not block then
			block = params
			params = {"node"}
		end
		if DEBUG then
			print("last node", name)
		end
		return {name, load("return function(self, "..table.concat(params, ", ")..") "..block.." end", name .. " treater", nil, cfg.env)()}
	end),
	params = sym "(" * (id^-1 * (sym "," * id)^0) * sym ")" / function(...) return {...} end,
	code = sym "{" * C((P(1) - "}")^0)  * sym "}"
}


local unpack = unpack or table.unpack

local module = {
	createPass = function(code)
    local obj = {}
		local rules = G:match(code)
		for _, kv in ipairs(rules) do
			obj[kv[1]] = kv[2]
		end
		return obj
	end,
	setenv = function(env)
		cfg.env = env
	end
}

return module

