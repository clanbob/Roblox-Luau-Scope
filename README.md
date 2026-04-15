# Roblox Luau Scope

`Scope.luau` is a lightweight lifecycle manager for Roblox projects written in Luau.

It gives you one place to register **objects**, **connections**, **tweens**, **threads**, and **scope-bound async tasks**, then clean all of them up together when a system is no longer needed.

---

## Why use Scope?

Roblox gameplay code often creates temporary resources:

- UI screens and their event connections
- Character ability loops and timers
- VFX tweens and delayed callbacks
- Background threads started with `task.spawn`

Without a central owner, these resources can keep running after the feature that created them is gone. `Scope` solves this by grouping ownership and teardown into one object.

---

## What Scope tracks

A `Scope` instance can track:

- **Instances** → cleaned with `:Destroy()`
- **Tweens** → cleaned with `:Cancel()`
- **RBXScriptConnections** → cleaned with `:Disconnect()`
- **Child scopes** → cleaned with `:CleanUp()`
- **Registered threads/tasks** via `ScopeTasks` and `AddTask`

---

## Quick start

```luau
local ScopeModule = require(path.To.Scope)

local scope = ScopeModule.New()

-- Track instances/connections/tweens
scope:Add(workspace.TempPart)
scope:Add(button.MouseButton1Click:Connect(function()
	print("clicked")
end))

-- Scope-bound async work
scope.ScopeTasks:Delay(1, function()
	print("Delayed work")
end)

local child = scope:CreateChild()
child.ScopeTasks:Interval(0.5, function()
	print("running in child")
end)

-- Stop all tracked work/resources for this scope and its children
scope:CleanUp()

-- Optional final teardown of the scope table itself
scope:Destroy()
```

---

## API reference

### Module API

#### `ScopeModule.New(): Scope`
Creates and returns a fresh scope.

### Scope methods

#### `scope:Add(object)`
Registers an object for cleanup. Supported default cleanup methods are determined by `typeof`:

- `Instance` → `Destroy`
- `Tween` → `Cancel`
- `RBXScriptConnection` → `Disconnect`
- Other table/userdata values attempt `Destroy`

Functions and raw threads are rejected by `Add`.

#### `scope:AddTask(thread)`
Registers an existing thread so it will be cancelled when the scope is cleaned.

#### `scope:CreateChild(): Scope`
Creates a nested child scope and registers it under the current scope. Cleaning the parent also cleans the child.

#### `scope:CleanUp()`
Cancels registered scope tasks, invokes cleanup methods on tracked objects, then clears internal tracking tables. The scope remains reusable after cleanup.

#### `scope:Destroy()`
Calls `CleanUp()`, then clears the scope object and removes its metatable. Use when the scope itself should no longer be used.

### `scope.ScopeTasks` methods

#### `scope.ScopeTasks:Delay(time, fn, ...)`
Runs `fn(...)` after `time` seconds via `task.delay`, while still being cancellable through scope cleanup.

#### `scope.ScopeTasks:Wait(time)`
Registers the current coroutine with the scope, waits for `time`, then unregisters if still active.

#### `scope.ScopeTasks:Defer(fn, ...)`
Schedules `fn(...)` with `task.defer`, tracked by the scope.

#### `scope.ScopeTasks:Spawn(fn, ...)`
Schedules `fn(...)` with `task.spawn`, tracked by the scope.

#### `scope.ScopeTasks:Interval(time, fn)`
Starts a loop that waits `time` and calls `fn()` repeatedly until the scope is cleaned.

#### `scope.ScopeTasks:Wrap(fn)`
Returns a function wrapper that runs `fn` through `Spawn`, automatically tying each call to the scope.

#### `scope.ScopeTasks:CleanUp()`
Cancels all tracked task threads and clears the task registry.

---

## Recommended usage patterns

- **One scope per controller/system** (UI controller, combat state, quest tracker, etc.).
- **Create child scopes** for sub-features that should die with their parent.
- **Prefer `ScopeTasks`** over raw task helpers when work should stop on teardown.
- **Call `CleanUp()`** when reusing a controller.
- **Call `Destroy()`** when the controller itself is permanently removed.

---

## Example pattern (controller lifecycle)

```luau
local ScopeModule = require(path.To.Scope)

local Controller = {}
Controller.__index = Controller

function Controller.new(gui)
	local self = setmetatable({}, Controller)
	self.scope = ScopeModule.New()
	self.gui = gui

	self.scope:Add(gui)
	self.scope:Add(gui.Button.MouseButton1Click:Connect(function()
		print("pressed")
	end))

	self.scope.ScopeTasks:Spawn(function()
		while true do
			task.wait(1)
			print("heartbeat")
		end
	end)

	return self
end

function Controller:Destroy()
	self.scope:Destroy()
end

return Controller
```

This keeps all controller-created resources bound to a single lifecycle owner.
