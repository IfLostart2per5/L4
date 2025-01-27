local enshorter = {}
local enshorter_mt = {__index=enshorter}

function enshorter.new()
	return setmetatable({
		namel = {'a'},
		name_scope={'A'},
		curscope='A',
		identifiers={A={}},
		scopetifiers={global='A'}
	}, enshorter_mt)
end

function enshorter:make_short(name)
	local sname = ''
	for i = 1, #self.namel - 1 do
		local c = self.namel[i]
		sname = sname .. c
	end
	local last = self.namel[#self.namel]
	if last == 'z' then
		table.insert(self.namel, 'a')
		last = 'a'
	else
		self.namel[#self.namel] = string.char(last:byte() + 1)
	end

	sname = self.curscope .. sname
	self:register(name, sname)
	return sname
end

function enshorter:register(name, shorten)
	self.identifiers[self.curscope][name] = shorten
end

function enshorter:get(name, scope)
	scope = scope and self:getscope(scope) or self.curscope
	return self.identifiers[scope][name]
end

function enshorter:getscope(name)
	return self.scopetifiers[name]
end

function enshorter:registerscope(name, shorten)
	self.scopetifiers[name] = shorten
end

function enshorter:make_shortscope(name)
	local sname = ''
	for i = 1, #self.name_scope - 1 do
		local c = self.name_scope[i]
		sname = sname .. c
	end

	local last = self.name_scope[#self.name_scope]

	if last == 'Z' then
		table.insert(self.name_scope, 'A')
		last = 'A'
	else
		self.name_scope[#self.name_scope] = string.char(last:byte() + 1)
		last = self.name_scope[#self.name_scope]
	end

	sname = sname .. last
	self:registerscope(name, sname)

	return sname
end

function enshorter:move2(name, ispure)
	self.curscope = ispure and name or self:getscope(name)
end

function enshorter:pass(node)
	if node.tag == "assign" then
		local name = node.name
		node.name = self:make_short(name)
		return node
	elseif node.tag == "id" then
		node.name = self:get(node.name) or node.name
		return node
	elseif node.tag == "binop" then
		node.left = self:pass(node.left)
		node.right = self:pass(node.right)
		return node
	elseif node.tag == "func" then
		local nm = node.name
		node.name = self:make_short(nm)
		local oldsc = self.curscope
		self:make_shortscope(nm)
		self:move2(nm)
		for i = 1, #node.params do
			node.params[i] = self:make_short(node.params[i])
		end

		for _, bl in ipairs(node.body) do
			for _2, l in ipairs(bl.body) do
				self:pass(l)

			end
		end

		self:move2(old, true)

		return node
	elseif node.tag == "call" then
		self:pass(node.caller)
		
		for _, a in ipairs(node.args) do
			self:pass(a)
		end

		return node
	elseif node.tag == "return" then
		self:pass(node.arg)
		return node
	elseif node.tag == "program" then
		for _, s in ipairs(node) do
			self:pass(s)
		end

		return node
	else
		return node
	end
end

return enshorter
