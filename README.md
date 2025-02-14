![A big globe being surrounded by a fast moon, leaving a blue trace](./imgs/logo.jpg)
# L4 (Low Level Lua Library)

Welcome to the docs of L4! Here, we'll describe how to use this library to generate a 'hello world!' program.
First, install this with

```sh
git clone https://www.github.com/IfLostart2per5/L4
cd L4
luarocks make l4-0.0.2-1.rockspec
```

Note: a great change ocurred: the introduction of a more strict type system for the builder, to make easier the generation for typed languages, or typed-optimizations

and let's go!

This tutorial will suppose that you already know how to use lua.

## The builder

To start, open a file "hello.lua", import this lib, and initialize the builder:

```lua
local L4 = require "L4"
local builder = L4.builder.new()
```

okay, now, let's import an important function: the print!
```lua
builder:extern("print", builder:signature(builder:ty "String", builder:ty "Void")) -- this doesn't load it instantly. Instead, the generator will take care of this
--about the signature, it represents (String) -> Void

```

having done this, we can build our main function, because the generator only works with functions:

```lua
local mainsign = builder:signature(builder:ty "Void") --() -> Void
local main = builder:func("main", {}, mainsign) --creates a function main with no parameters

local entry = builder:block("entry", mainsign) --creates an entry block, with tje signature of the function for return-checking reasons (yes, quite based on llvm)

main:setblock(entry) -- configure the entry block as the current block of function

--now, we can push instructions on both main and entry, but now I'll choose the main

local call = builder:call(builder:id "print", builder:str "Hello world") -- creates a call, where the first argument is the caller, and the rest are arguments to the caller

main:push(call) --pushes the call into main
main:push(builder:ret())
```


well, now the function building is done. But we're unable to run it! Now lets talk about the generation.


# The generator

After building our code, we need to run it, right? So, to do this, in the same file, write:

```lua
local gen = L4.generator.new()
```

okay? Now, use a config generator file, a text file containing how the node should be generated. We'll use a ready-made one: [lua](./generators/lua.txt). Download this and put it into the same folder of hello.lua.
Now, write:

```lua
local decls = builder:get() -- get the builder declarations
gen:config("lua.txt") -- configures the generator file
gen:generate(decls)
local comp = gen:get() --obtains the resulting object
```

Here, the comp object contains two things:

- funcs: the compiled functions
- code: the generated code

to run this, run:

```lua
comp.funcs.main()
```

and with this, you'll see Hello world, and we're done!

# The optimizer

Optionally, you can apply a optimization into the built code before generation, but, currently this optimizer makes small optimizations: constant folding, function inlining, branch inline and dead code elimination.

To add this into code, write this before generation

```lua
--... previous code before generation
local opt = L4.optimizer.new()
local decls = builder:get()
local optimized = opt:attack(decls)

--...generation
```

so, you'll get a optimized ast. With our example, hello world won't need anything more, so, we can produce a function to this:

```lua
local sumsign = builder:signature(builder:ty "Int", builder:ty "Int", builder:ty "Int") -- (Int, Int) -> Int
local sum = builder:func("sum", {'x', 'y'}, sumsign)
local sumblock = builder:block("sumblk", sumsign)

sum:setblock(sumblock)
local add = builder:binop(builder:ty "Int", builder:id "x", builder:id "y", "+")
sum:push(builder:ret(add))

---...main function
```

okay, and, in the main function:

```lua
---...sum function
builder:extern("tostring", builder:signature(builder:ty "Int", builder:ty "String")) --due to the new type system, this is necessary. and the type is (Imt) -> String.
local mainsign = builder:signature(builder:ty "Void")
local main = builder:func("main", {}, mainsign)
local entry = builder:block("entry", mainsign)            
main:setblock(entry)              
local result = builder:call(builder:id "sum", builder:int(2), builder:int(3))
local str = builder:call(b:id "tostring", result)
local call = builder:call(builder:id "print", str)
main:push(call) --pushes the call into main
main:push(builder:ret())
```

Now, when we run the code, and print the generated code, we'll get something like this:

```lua
--generated lua code by L4 (Low Level Lua Library)
function sum(x, y)
::sumblk::
return (x+y)

--::sumblk::
end
function main()
::entry::
print((2+3)) --(that's my comment) here's the inlined result of sum(2, 3) 
--::entry::
end
```

as i said, it does small optimizations, and, it's experimental (like this whole project hahaha).

well, I hope that this was a goood tutorial for the basic use of L4, I'll make more detailed documentation later, okay?
