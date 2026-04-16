--[[
	SCOPE

	Purpose:
		Scope is a lifetime and cleanup manager for Roblox objects and asynchronous tasks.
		It allows instances, connections, tweens, child scopes, and running threads to be
		grouped under a single scope and cleaned up together.

		Scope also provides scope-bound task helpers such as Delay, Defer, Spawn, Interval,
		and Wait. Tasks registered through ScopeTasks are tied to the scope's lifetime and
		can be automatically cancelled when the scope is cleaned up or destroyed.

		This is useful for managing temporary systems such as UI controllers, AI behaviors,
		abilities, effects, and other logic that should stop running once its owning scope
		no longer exists.

	Author:
		TheRoyalDrew
]]




local Scope = {}
Scope.__index = Scope


local ScopeTasks = {}
ScopeTasks.__index = ScopeTasks

local function generate_locked_index(table : {}): number
	local index = 0
	repeat
		index += 1
		if table[index] == nil then
			return index
		end
	until false
end

function ScopeTasks:Delay(time : number, fn : (...any) -> (), ...)
	local index = generate_locked_index(self.items)
	self.items[index] = 
		task.delay(time, function(...)
			self.items[index] = nil
			fn(...)
		end, ...)
	
	return index
end



-- NOTE: Registers the current coroutine to this scope, then waits for `time` seconds.
-- If the scope is destroyed before the wait finishes, this thread will be
-- cancelled via ScopeTasks:CleanUp(), preventing any code after this from running.
function ScopeTasks:Wait(time : number)
	local index = generate_locked_index(self.items)
	self.items[index] = coroutine.running()

	
	task.wait(time)
	self.items[index] = nil
end

function ScopeTasks:Defer(fn : (...any) -> (), ...)
	local index = generate_locked_index(self.items)
	self.items[index] = 
		task.defer(function(...)
			self.items[index] = nil
			fn(...)
		end, ...)
	
	return index
end


function ScopeTasks:Interval(time: number, fn: () -> ())
	local index
	index = self:Spawn(function()
		pcall(function()
			while true do
				task.wait(time)
				fn()
			end
		end)
		
		self.items[index] = nil
	end)
	
	return index
end

function ScopeTasks:Wrap(fn : (...any) -> (), ...)
	return function(...)
		self:Spawn(fn, ...)
	end
end

function ScopeTasks:Spawn(fn : (...any) -> (), ...)
	local index = generate_locked_index(self.items)
	self.items[index] = 
		task.spawn(function(...)
			pcall(fn, ...)
			self.items[index] = nil
		end, ...)
	
	return index
end

function ScopeTasks:CleanUp()
	for _, item in pairs(self.items) do
		pcall(task.cancel, item)
	end
	
	table.clear(self.items)
end

-- stores the univerisal defaults for 
-- "destroy" methods to prevent adding method
-- method name for every add call
local DEFAULTS = {
	Instance = "Destroy", 
	Tween = "Cancel",
	RBXScriptConnection = "Disconnect", 
}

-- NOTE: use ["function"] to bypass the
-- keyword for function
local INVALID_DEFAULTS = {
	["function"] = true,
	thread = true
}

-- determines the method to use to clean up an object
-- defualts to "Destroy" if no method is found
local function determine_method_for_scope_removal(object : any): string
	local object_type = typeof(object)
	local method_call = DEFAULTS[object_type]
	
	if method_call then
		return method_call
	end
	
	local is_invaild = INVALID_DEFAULTS[object_type]
	if is_invaild then
		return false
	else
		return "Destroy"
	end
end



function Scope:Add(object : any, method_name : string)
	local call = method_name or determine_method_for_scope_removal(object)
	if not call then
		warn(`{object} is not a valid object to add to scope`)
		return
	end
	
	if self.items[object] then
		warn(`{object} is already in scope`)
		return
	end
	
	self.items[object] = call
end


-- not recommended to use this for anything but a Spawn call
-- that will not end, due to the nature of the scope
-- such as it will not know when it ends, thus leaving the
-- the thread reference in memory for the duration of a
-- clean up call
function Scope:AddTask(thread: thread)
	local index = generate_locked_index(self.ScopeTasks.items)
	self.ScopeTasks.items[index] = thread
end


function Scope:CreateChild()
	local child = Scope.new()
	self:Add(child, "CleanUp")
	
	return child
end

function Scope:CancelScopeTask(index: number)
	self.ScopeTasks.items[index] = nil
end

function Scope:CleanUp()
	self.ScopeTasks:CleanUp()
	
	for object, call in pairs(self.items) do
		object[call](object)
	end
	
	table.clear(self.items)
end

-- will call :Cleanup()
function Scope:Destroy()
	self:CleanUp()
	
	table.clear(self)
	setmetatable(self, nil)
end


function Scope.new(): Scope
	local self = setmetatable({
		items = {},
		ScopeTasks = 
			setmetatable({
				items = {},
			}, ScopeTasks)
	}, Scope)
	
	return self
end

local Public = {}

function Public.New()
	return Scope.new()
end 

export type ScopeTaskItem = {
	thread: thread,
}

export type ScopeObjectItem = {
	call: string,
}

export type ScopeTasks = {
	items: {[number]: ScopeTaskItem},

	Delay: (self: ScopeTasks, time: number, fn: (...any) -> (), ...any) -> number,
	Wait: (self: ScopeTasks, time: number) -> (),
	Defer: (self: ScopeTasks, fn: (...any) -> (), ...any) -> number,
	Interval: (self: ScopeTasks, time: number, fn: () -> ()) -> number,
	Wrap: (self: ScopeTasks, fn: (...any) -> (), ...any) -> (...any) -> (),
	Spawn: (self: ScopeTasks, fn: (...any) -> (), ...any) -> number,
	CleanUp: (self: ScopeTasks) -> (),
}

export type Scope = {
	ScopeTasks: ScopeTasks,

	Add: (self: Scope, object: any, method_name: string) -> (),
	AddTask: (self: Scope, thread: thread) -> (),
	CreateChild: (self: Scope) -> Scope,
	CleanUp: (self: Scope) -> (),
	CancelScopeTask: (self: Scope, index: number) -> (),
	Destroy: (self: Scope) -> (),
}

export type ScopeModule = {
	new: () -> Scope,
}

return Public
