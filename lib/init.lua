local config, DEFAULTS = include "lib/default_config"
local args, def = {}, {}
if util.file_exists(norns.state.data .. "/config.lua") then
  print "### found config file"
  args, def = dofile(norns.state.data .. "/config.lua")
end

local function tbl_isempty(table)
  return next(table) == nil
end

local function tbl_islist(table)
  local count = 0
  for k, _ in pairs(table) do
    if type(k) == 'number' then
      count = count + 1
    else
      return false
    end
  end
  return count > 0
end

local function can_merge(table)
  return type(table) == 'table' and (tbl_isempty(table) or not tbl_islist(table))
end

-- furthest right key wins
local function tbl_deep_extend(...)
  local ret = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    if tbl then
      for k, v in pairs(tbl) do
        if can_merge(v) and can_merge(ret[k]) then
          ret[k] = tbl_deep_extend(ret[k], v)
        else
          ret[k] = v
        end
      end
    end
  end
  return ret
end

local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.script.clear()
  norns.scripterror(msg)
end

local function N(c, m)
  norns_assert(c, m)
end

local extargs, extdef = {}, {}
if args.extends then
  N(type(args.extends) == "string", 'config error: args.extends must be string')
  if util.file_exists(norns.state.lib .. args.extends .. '.lua') then
    extargs, extdef = dofile(norns.state.lib .. args.extends .. '.lua')
  elseif util.file_exists(norns.state.path .. args.extends .. '.lua') then
    extargs, extdef = dofile(norns.state.path .. args.extends .. '.lua')
  elseif util.file_exists(norns.state.data .. args.extends .. '.lua') then
    extargs, extdef = dofile(norns.state.data .. args.extends .. '.lua')
  else
    N(false, 'config error: file ' .. args.extends .. ' not found.')
  end
end

config = tbl_deep_extend(config, extargs, args)
DEFAULTS = tbl_deep_extend(DEFAULTS, extargs.DEFAULTS, extdef, args.DEFAULTS, def)

N(config.engine, "config error: config.engine must not be nil")

if not config.engine.name then
  config.engine.name = "None"
end

N(type(config.engine.name) == 'string', "config error: engine.name must be string")

engine.name = config.engine.name

if config.engine.lua_file then
  N(type(config.engine.lua_file) == 'string', 'config error: engine.lua_file must be string')
  -- N(util.file_exists(config.engine.lua_file), 'config error: no such engine.lua_file')
  Engine = include(config.engine.lua_file)
  N(Engine, 'config error: including ' .. config.engine.lua_file .. ' returned nil')
end

if config.engine.ui_file then
  N(type(config.engine.ui_file) == 'string', 'config error: engine.ui_file must be string')
  -- N(util.file_exists(config.engine.ui_file), 'config error: no such engine.ui_file')
  Engine_UI = include(config.engine.ui_file)
  N(Engine_UI, 'config error: including ' .. config.engine.ui_file .. ' returned nil')
end

N(config.page, 'config error: config.page must not be nil')
N(type(config.page.pages) == 'table' and #config.page.pages == 10, 'config error: page.pages must be list of ten')
local keys = {'length', 'division', 'probability', 'data', 'swing', 'priority'}
for _, k in ipairs(keys) do
  N(type(config.page[k]) == 'number', 'config error: page.' .. k .. ' must be number')
end
for i = 1, 10 do
  local key = config.page.pages[i]
  N(config[key], 'config error: no page found matching ' .. key)
  for _, k in ipairs(keys) do
    if config[key][k] then
      N(type(config[key][k]) == 'number', 'config error: ' .. key .. '.' .. k .. ' must be number')
    end
  end
  N(config[key].main, 'config error: ' .. key .. '.main must not be nil')
  for _, k in ipairs({'min', 'max'}) do
    if config[key].main[k] then
      N(type(config[key].main[k]) == 'number', 'config error: ' .. key .. '.main.' .. k .. ' must be number')
    end
  end
  N(type(config[key].main.display) == 'function', 'config error: ' .. key .. '.main.display must be callable')
  local success, test = pcall(config[key].main.display, 1, true, true, 1)
  if not success then
    N(false, 'config error: ' .. key .. '.main.display(1, true, true, 1) failed with error '.. test)
  end
  for _, v in ipairs(test) do
    N(#v == 2, 'config error: ' .. key .. '.main.display must return list of pairs')
    for j = 1, 2 do
      N(type(v[j]) == 'number', 'config error: ' .. key .. 'main.display pairs must be numbers')
    end
  end
  success, test = pcall(config[key].main.display, 1, true, false, nil)
  if not success then
    N(false, 'config error: ' .. key .. '.main.display(1, true, false, nil) failed with error ' .. test)
  end
  N(type(config[key].main.key) == 'function', 'config error: ' .. key .. '.main.key must be callable')
  test = config[key].main.key(3, 1)
  if test then
    N(type(test) == 'number', 'config error: ' .. key .. '.main.key did not return number')
  end
  if config[key].subsequins then
    for _, k in ipairs({'min', 'max'}) do
      if config[key].subsequins[k] then
        N(type(config[key].subsequins[k]) == 'number', 'config error: ' .. key .. '.subsequins.' .. k .. ' must be number')
      end
    end
    if config[key].subsequins.display then
      N(type(config[key].subsequins.display) == 'function', 'config error: ' .. key .. '.subsequins.display must be callable')
      success, test = pcall(config[key].subsequins.display, 3)
      if not success then
        N(false, 'config error: ' .. key .. '.subsequins.display(3) failed with error ' .. test)
      end
      for _, v in ipairs(test) do
        N(#v == 2, 'config error: ' .. key .. '.subsequins.display must return list of pairs')
        for j = 1, 2 do
          N(type(v[j]) == 'number', 'config error: ' .. key .. 'subsequins.display pairs must be numbers')
        end
      end
    end
    if config[key].subsequins.key then
      N(type(config[key].subsequins.key) == 'function', 'config error: ' .. key .. '.subsequins.key must be callable')
      test = config[key].subsequins.key(3, 1)
      if test then
        N(type(test) == 'number', 'config error: ' .. key .. '.subsequins.key did not return number')
      end
    end
  end
  N(type(config[key].action) == 'function', 'config error: ' .. key .. '.action must be callable')
end

N(type(config.setup_hook) == 'function', 'config error: config.setup_hook must be callable')

N(type(config.play_note) == 'function', 'config error: config.play_note must be callable')

config.tbl_deep_extend = tbl_deep_extend

return config
