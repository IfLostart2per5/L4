--Node type definitions to make the IDE's users work easier


--EXPRESSIONS---------------------------------

---@class node
---@field tag string the nodetype
local node = {}

--literals here

---@class int : node
---@field value integer
local int = {}

---@class float : node
---@field value number
local float = {}

---@class str : node
---@field value string
local str = {}

---@class bool : node
---@field value boolean
local bool = {}

--an identifier (only used in expressions)
---@class id : node
---@field name string
local id = {}

--function call
---@class call : node
---@field caller node
---@field args node[]
local caller = {}

--allowed operators for binary expressions
---@enum operators
local operators = {
  ["+"] = "+",
  ["-"] = "-",
  ["*"] = "*",
  ["/"] = "/",
  [">"] = ">",
  ["<"] = "<",
  ["=="] = "==",
  ["!="] = "!=",
  [">="] = ">=",
  ["<="] = "<=",
  ["^"] = "^", --this is the "and" operator (from math/boolean logic)
  ["v"] = "v", --this is the "or" operator (from math/boolean logic too)
}

---@class binop : node
---@field left node
---@field right node
---@field op operators
local binop = {}

--EXPRESSIONS---------------------------------

--STATEMENTS----------------------------------

---@class assign : node
---@field name string
---@field val node
local assign = {}

---@class func : node
---@field name string
---@field params string[]
---@field previous { [table]: boolean }
---@field body block[]
---@field block block
local func = {}

---Pushes an instruction into the current block
---@param i node
function func:push(i)
end

---Sets and push a new block into the blocklist, as the current block
---@param bl block
function func:setblock(bl)
end

--a block is a named list of statements (useful for labels)
---@class block : node
---@field name string
---@field body node[]
---@field refc integer --reference counting (yes, it is ............................ just to identify useless blocks :D)
---@field isloop boolean?
local block = {}

---Pushes an instruction into this block
---@param i node
function block:push(i)  
end


---@class br : node
---@field to block
local br = {}

---@class condbr : br
---@field alt block
---@field condition node
local condbr = {}

--useful to use extern functions?
---@class extern : node
---@field name string
local ext = {}

---@class return : node
---@field arg node
local ret = {}

--STATEMENTS----------------------------------


--pls, forgive foreigmers, I really need write it in portuguese :>
 

--agora respeita... É ELE!!!!!!!!!!!!!!!!
--o gerenciador de todos os outros nós 
--o pai solo
--perdeu a esposa para o desenvolvedor, que friamente se recusou a cria-la 
--é rei de um oedação de memória
--que é aleatória
--parabenizem ele por se sobressair nessa historiaaaa
--.... 
--ELPROGRAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMMMMMMMMMMMMMMMMM

---@class program
---@field [number] node
local program = {}
