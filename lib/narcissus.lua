local M = {}

local reflection = {}
if tonumber(norns.version.update) <= 221214 then
  reflection = include("lib/reflection")
else
  reflection = require "reflection"
end
local Narcissus = {}

local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.script.clear()
  norns.scripterror(msg)
end

local function process(event)
  if event.j then
    Narcissus.params[event.id][event.i][event.j](event.x)
  else
    Narcissus.params[event.id][event.i](event.x)
  end
end

local function hijack_param(param)
  local ret = {}
  local max = 7 * (param.id_minor and 7 or 1)
  for i = 0, max - 1 do
    ret[i] = {}
    if param.subparams then
      for j = 1, param.subparams do
        local p = params:lookup_param(param[1] .. "_" .. j .. "_" .. i)
        ret[i][j] = p.action
        p.action = function (x)
          local k = param.id_minor and i // 7 + 1 or i + 1
          Narcissus[k]:watch{
            id = param[1],
            i = i,
            j = j,
            x = x
          }
          ret[i][j](x)
        end
      end
    else
      local p = params:lookup_param(param[1] .. "_" .. i)
      ret[i] = p.action
      p.action = function (x)
        local k = param.id_minor and i // 7 + 1 or i + 1
        Narcissus[k]:watch{
          id = param[1],
          i = i,
          x = x
        }
        ret[i](x)
      end
    end
  end
  return ret
end

local function prep_param(param)
  if type(param) == "string" then param = {param} end
  norns_assert(type(param) == "table" and type(param[1]) == "string", 'config error: bad param in narcissus.args.params')
  if param.id_minor == nil then
    param.id_minor = true
  end
  if param.subparams == 0 then
    param.subparams = nil
  end
  local infix = param.subparams and "_" .. param.subparams or ""
  local find = params:lookup_param(param[1] .. infix .. "_0")
  norns_assert(find, 'config error: param not found; ' .. param[1] .. infix)
  Narcissus.params[param[1]] = hijack_param(param)
end

local function grid_long_press(x, y)
  -- a long press is one second
  clock.sleep(1)
  Press_Counter[x][y] = nil
  if not x == 4 then return end
  Narcissus[y]:clear()
  Narcissus[y].state = 0
end

function M.grid_key(x, y, z)
  if not x == 4 then return end
  if z ~=0 then Press_Counter[x][y] = clock.run(grid_long_press, x, y) return z end
  if not Press_Counter[x][y] then return z end
  clock.cancel(Press_Counter[x][y])
  if Narcissus[y].state == 0 then
    -- first play
    -- unless there is nothing recorded
    if Narcissus[y].endpoint == 0 then
      Narcissus[y]:set_rec(1)
      Narcissus[y]:start()
      Narcissus[y].state = 2
    else
      Narcissus[y]:start()
      Narcissus[y].state = 1
    end
  elseif Narcissus[y].state == 1 then
    -- then record (overdub)
    Narcissus[y]:set_rec(1)
    Narcissus[y].state = 2
  elseif Narcissus[y].state == 2 then
    -- finally stop
    Narcissus[y]:set_rec(0)
    Narcissus[y]:stop()
    Narcissus[y].state = 0
  end
  return z
end

function M.display()
  local ret = {}
  for y = 1, 7 do
    local state
    if Narcissus[y].state == 0 then
      state = 0
    elseif Narcissus[y].state == 1 then
      state = 9
    elseif Narcissus[y].state == 2 then
      state = Dance_Index % 2 == 1 and 15 or 9
    end
    ret[y] = {4, y, state}
  end
  return ret
end

function M.init(args)
  norns_assert(type(args.params) == "table", 'config error: narcissus.args.params must be list')
  for i = 1, 7 do
    Narcissus[i] = reflection.new()
    Narcissus[i].state = 0
    Narcissus[i]:set_loop(1)
    Narcissus[i].process = process
    Narcissus[i]:set_quantization(args.quantization)
  end
  for _, param in ipairs(args.params) do
    prep_param(param)
  end
end

return M
