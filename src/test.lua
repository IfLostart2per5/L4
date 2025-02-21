local builder = require "src.builder"
local generator = require "src.generator"
local opt = require "src.optimizer"

local b = builder.new()
b:extern("printf", b:signature("String", b:vararg(), "Void"))

ftos, itos = tostring, tostring

local fty = b:signature("Void")
local main = b:func("main", {}, fty)
local entry = b:block("entry", fty)

local op = b:binop("Int", b:int(5), b:int(2), "*")
local prnt = b:call(b:id "printf", b:str "%d\n", op)
entry:push(prnt)
entry:push(b:ret())
main:setblock(entry)

local o = opt.new()
local decl = b:get()
decl = o:attack(decl)
local g = generator.new()
g:config("./generators/asm.txt")

g:generate(decl)
local c = g:get()
local f, err = io.open("a.s", "w")
if not f then error(err) end
f:write(c.code)
f:close()
os.execute("clang a.s -o a.out -fPIC -nostartfiles")
