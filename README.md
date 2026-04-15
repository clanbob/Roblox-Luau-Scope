# Roblox Luau Scope

`Scope.luau` is a lightweight lifetime and cleanup manager for Roblox projects written in Luau.

It helps you group objects and asynchronous tasks under a single scope so they can all be cleaned up together.

## Features

- Add Roblox instances, tweens, and connections to a scope.
- Create child scopes for nested ownership.
- Register async work through scope-bound helpers:
  - `Delay`
  - `Defer`
  - `Spawn`
  - `Interval`
  - `Wait`
- Cancel registered tasks automatically during cleanup.

## Basic usage

```luau
local ScopeModule = require(path.To.Scope)

local scope = ScopeModule.New()

-- Add an object with a cleanup method (e.g. Instance:Destroy())
scope:Add(somePart)

-- Run task work bound to this scope
scope.ScopeTasks:Delay(1, function()
	print("Delayed work")
end)

-- Create a child scope
local child = scope:CreateChild()

-- Clean everything in this scope (and child scopes)
scope:CleanUp()

-- or fully destroy the scope
scope:Destroy()
```

## API summary

### Module

- `New(): Scope` — creates a new scope.

### Scope methods

- `Add(object)`
- `AddTask(thread)`
- `CreateChild()`
- `CleanUp()`
- `Destroy()`

### ScopeTasks methods

- `Delay(time, fn, ...)`
- `Wait(time)`
- `Defer(fn, ...)`
- `Interval(time, fn)`
- `Wrap(fn, ...)`
- `Spawn(fn, ...)`
- `CleanUp()`

## Notes

- `CleanUp()` clears tracked tasks and objects but keeps the scope usable.
- `Destroy()` calls `CleanUp()`, then removes the scope internals and metatable.
- Functions and raw threads are not supported via `Add`; use `AddTask(thread)` for threads.
