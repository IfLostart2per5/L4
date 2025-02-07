
local function vertix(id, data)
  return {id=id, data, bindings={}}
end

local function bind(v1, v2)
  table.insert(v1.bindings, v2.id)
end

local function graph()
  return {
    space = {},
    insert = function(s, v)
      s.space[v.id] = v
    end,
    get = function(s, id)
      return s.space[id]
    end,
    iscyclic = function(s, id, visited, recstack) --unfortunately, this algorithm wasn't written by me :( I'll looooooooooooooooose, my work, cause i'am not searching... SOME GOOD WAY/ to learn and my attention pay. But Instead, AI I used :c
      visited = visited or {}
      recstack = recstack or {}

      if not visited[id] then
        visited[id] = true
        recstack[id] = true
        for _, k in ipairs(s.space[id].bindings) do
          if not visited[k] and s:iscyclic(k, visited, recstack) then
            return true
          elseif recstack[k] then
            return true
          end
        end
      end
      recstack[id] = false
      return false
    end
  }
end

return {
  graph = graph,
  vertix = vertix,
  bind = bind
}
