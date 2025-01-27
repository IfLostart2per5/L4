local config = require "configparser"
local map = {}
config.parse("soma { return node.a + node.b }", map)
print(map.soma(nil, {a=2, b=3}))
