local graph = require "src.graph"

local detector = {}
local detector_mt = {__index=detector}
function detector.new()
  local obj = setmetatable({
    callgraph = graph.graph()
  }, detector_mt)

  return obj
end

--let's assume we're receiving a node of type "func"
function detector:isrecursive(node)
  if self.callgraph:get(node.name) then
    local gotnode = self.callgraph:get(node.name)
    return gotnode.isrecursive
  end
  local fv = graph.vertix(node.name, node)

  self.callgraph:insert(fv)
  for _, bl in ipairs(node.body) do
    for _, l in ipairs(bl.body) do
      local calls = self:HUNT_CALLS(l)
      for i = 1, #calls do
        graph.bind(fv, calls[i])
      end
    end
  end

  node.isrecursive = self.callgraph:iscyclic(fv.id)

  return node.isrecursive
end

function detector:getfnode(name)
  return self.callgraph:get(name.name and name.name or name)
end
function detector:HUNT_CALLS(node)
  local calls = {}
  --print(node and node.tag)
  if node.tag == "call" then
    calls[1] = self:getfnode(node.caller)
    
    for _, i in ipairs(node.args) do
      for _,j in ipairs(self:HUNT_CALLS(i)) do 
        calls[#calls + 1] = j
      end
    end
    
  elseif node.tag == "binop" then
    local left = self:HUNT_CALLS(node.left)
    local right = self:HUNT_CALLS(node.right)
    --print(node.right.tag)
    for i = 1, #left do
      calls[#calls + 1] = left[i]
    end

    for i = 1, #right do
      calls[#calls + 1] = right[i]
    end
  elseif node.tag == "assign" then
    for _, i in ipairs(self:HUNT_CALLS(node.val)) do
      calls[#calls + 1] = i
    end
  elseif node.tag == "return" then
    for _, i in ipairs(self:HUNT_CALLS(node.arg)) do
      calls[#calls + 1] = i
    end
  elseif node.tag == "condbr" then
    for _, i in ipairs(self:HUNT_CALLS(node.condition)) do
      calls[#calls + 1] = i
    end
  end

  return calls
end

return detector
