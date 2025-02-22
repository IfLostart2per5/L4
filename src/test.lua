local builder = require "src.builder"
local generator = require "src.generator"
local opt = require "src.optimizer"

local OUTPUT = arg[1] or "lua"
local b = builder.new()


b:extern("printf", b:signature("String", b:vararg(), "Void"))

printf = function(fmt, ...)
	io.write(fmt:format(...))
end

local fty = b:signature("Void")
local main = b:func("main", {}, fty)
local entry = b:block("entry", fty)


local mul = b:binop("Int", b:int(3), b:int(6), "*")
local op = b:binop("Int", b:int(5), mul, "+")
local asg = b:assign("pindola", "Int", op)
entry:push(asg)
local prnt = b:call(b:id "printf", b:str "%s: %d\n", b:str "Resultado de 5 + (3 * 6):", b:id "pindola")
entry:push(prnt)
entry:push(b:ret())
main:setblock(entry)

local o = opt.new()
local decl = b:get()
decl = o:attack(decl)
local g = generator.new()
if OUTPUT == "native" then
  g:config("./generators/asm.txt")
elseif OUTPUT == "lua" then
	g:config("./generators/lua.txt")
end
g:generate(decl)
local c = g:get()

local f, err = io.open("a.output", "w")
if OUTPUT == "lua" then
	f:write("function printf(fmt, ...) io.write(fmt:format(...)) end\n") --pra disponibilizar pro arquivo
end
if not f then error(err) end
f:write(c.code)
if OUTPUT == "lua" then f:write("\nmain()") end
f:close()
if OUTPUT == "native" then
	os.rename("a.output", "a.s")
  os.execute("clang a.s -o a.out -fPIC -nostartfiles")
elseif OUTPUT == "lua" then
	os.rename("a.output", "a.lua")
end
