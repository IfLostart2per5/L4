--types uded here come from node.d.lua

---@type { [string]: Typedef }
local types = {}

---@param name string
---@param attrs table?
---@return Typedef
local function typedef(name, attrs)
  local t = {name=name, attrs=attrs or {}}
  types[name] = t
  return t
end

---comment
---@param name string
---@return Typedef
local function ty(name)
  return types[name]
end



typedef("Int")
typedef("Float")
typedef("String")
typedef("Bool")
typedef("Void", {only_in_return_ty=true})

return {
  ty=ty,
  typedef=typedef,
  types=types
}
