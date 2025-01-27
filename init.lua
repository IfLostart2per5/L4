local oldpath = package.path

local sep = package.config:sub(1,1)
local folder = debug.getinfo("S").source:gsub("@", ""):match("(.*"..sep..")")

package.path = folder .. "?.lua;" .. package.path

local L4 = {}
L4.builder = require "src.builder"
L4.generator = require "src.generator"
L4.optimizer = require "src.optimizer"

package.path = oldpath

return mod
