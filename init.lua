-- Obtém o diretório onde este script (`init.lua`) está localizado
local current_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
if package.config:sub(1,1) == "\\" then  -- Se for Windows, ajusta para usar `\`
    current_dir = current_dir:gsub("/", "\\")
end

local opath, ocpath = package.path, package.cpath
-- Adiciona o diretório ao package.path (para módulos Lua)
package.path = current_dir .. "?.lua;" .. package.path

-- Adiciona o diretório ao package.cpath (para módulos C)
package.cpath = current_dir .. "?.so;" .. current_dir .. "?.dll;" .. package.cpath

local l4 = {}

l4.builder = require "src.builder"
l4.generator = require "src.generator"
l4.optimizer = require "src.optimizer"

package.path = opath
package.cpath = ocpath

return l4

