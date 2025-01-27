local builder = require "src.builder"
local generator = require "src.generator"
local opt = require "src.optimizer"

local b = builder.new()
b:extern("print")

local soma = b:func("soma", {"x", "y"})
local somablock = b:block("somab")
soma:setblock(somablock)

local add = b:binary_op(b:id"x", b:id "y", "+")
soma:push(b:ret(add))

local main = b:func("main", {})
local entryblock = b:block("entry")
main:setblock(entryblock)
local somacall = b:call(b:id "soma", b:int(2), b:int(6))
--main:push(b:int(6))
main:push(b:call(b:id("print"), somacall))
main:push(b:ret(b:int(0)))

local decls = b:get()
local o = opt.new()

local decls = o:attack(decls)
local gen = generator.new()
gen:config("luagen.txt")
gen:generate(decls)
local funcs = gen:get()
print(funcs.code)

