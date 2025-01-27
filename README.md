# L4 (Low Level Lua Library)

Welcome to the docs of L4! Here, we'll describe how to use this library to generate a hello world! First, install this with

```sh
luarocks install l4
```

and let's go!

This tutorial will suppose that you already know how to use lua.

## The builder

To start, open a file "hello.lua", import this lib, and initialize the builder:

```lua
local L4 = require "L4"
local builder = L4.builder.new()
```

okay, now, let's import a important function: the print!
```lua
builder:extern("print") -- this doesn't load it instantly. Instead, the generator will take care of this
```

made this, we can build our main function, becausethe generator only works with functions:

```lua
local main = builder:func("main", {}) --creates a function main with no parameters

local entry = builder:block("entry") --creates a entry block (yes, quite based on llvm)

main:setblock(entry) -- configure the entry block as the current block of function

--now, we can push instructions on both main and entry, but now I'll choose the main

local call = builder:call(builder:id "print", builder:str "Hello world") -- creates a call, where the first argument is the caller, and the rest are arguments to the caller

main:push(call) --pushes the call into main
```


well, now the function building is done. But we're unable to run it! Now lets talk about the generation.


# The generator

After building our code, we need to run it, right? So, to do this, in the same file, write:

```lua
local gen = L4.generator.new()
```

okay? Now, use a config generator file, a text file containing how the node should be generated. Wesll use a ready one: [luagen.lua](./generators/lua.txt). Download this and put it into the same folder of hello.lua.

Now, write:

```lua
local decls = builder:get() -- get the builder declarations
gen:config("lua.txt") -- configures the generator file
gen:generate(decls)
local comp = gen:get() --obtains the resultant object
```

Here, the comp object contains two things:

- funcs: the compiled functions
- code: the generated code

to run this, run:

```lua
comp.funcs.main()
```

and with this, you'll see Hello world, and we're done!

# Other things

You can use the optimizer class, a experimental ast optimizer. I'll explain this in other doc
