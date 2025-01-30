package = "L4"  -- Package name
version = "0.0.2-1"      -- Package version
description = {
   summary = "A lua copy of LLVM",
   license = "MIT",
   detailed="A compilation library, which allows you build code programatically, optimize it, and generate code for any platform, if you makes the platforms config file.",
   maintainer = "Alexandre Barreto <iscooldev7@gmail.com>",
}

dependencies = {
   "lua >= 5.1",   -- Package dependencies
   "lpeg"
}

source = {
   url = "https://github.com/IfLostart2per5/L4.git"
}

build = {
   type = "builtin",
   modules = {
      builder = "src/builder.lua",  -- intermediate ast builder
      generator = "src/generator.lua", --generate final code when is given a config file, and the ast,
      optimizer = "src/optimizer.lua", --an optional phase that wildly "attacks" the code, optimizing it
   },
}
