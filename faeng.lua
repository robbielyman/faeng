-- faeng is a sequencer
-- inspired by kria
-- configured by you
-- connect a grid
-- and take wing
--
-- v 1.1   @alanza
--    ▼ instructions below ▼
--
-- llllllll.co/t/faeng-is-a-sequencer/
--
-- by default, requires Timber,
-- and the norns UI is Timber's.
-- the bottom row of the grid is
-- the "nav bar";
-- key 1 is the track page,
-- keys 3 and 4 scroll the active track
-- keys 6 through 10 are the main pages
-- (each page has an alt page)
-- keys 12 through 14 are the mods
-- and key 16 is the pattern page
-- 
-- track page:
-- from left to right in each row
-- you can select, mute or reset.
-- further to the right is reserved
-- for configurable "modules".
-- by default the 4th key
-- is a pattern recorder per track.
--
-- main pages:
-- enter and view data for
-- the selected track.
-- long pressing on a step
-- will activate SubSequins mode
-- by default the pages are
-- 1. trigger / velocity
-- 2. sample / slice
-- 3. note / alt_note
-- 4. acctave / filter
-- 5. ratchet / pan.
-- pages are configurable.
--
-- mods:
-- there are three mods,
-- loop, division and probability.
-- loop operates on the track view
-- press one pad to move the loop,
-- two to resize.
-- division nad probability
-- give their own views,
-- representing page clock divider
-- (and swing)
-- or page probability.
--
-- the pattern page is adapted
-- from kria's metasequencer.
-- the top row represents the patterns,
-- while the middle row represents
-- the current pattern chain,
-- which may have SubSequins.
-- select a pattern to change
-- the value of the currently
-- selected step of the pattern chain,
-- long press to copy to from
-- the previous selection.
-- Each step of the pattern chain
-- has its own clock divider,
-- displayed on the bottom.
--
-- faeng wants to be extended
-- and configured.
-- dive into the README
-- or the default_config
-- and xD1_config files to learn more.

local sequins = require "sequins"
local Lattice = {}

norns.version.required = 221214

Lattice = require "lattice"
local MusicUtil = require "musicutil"
Grid = grid.connect()
local config = include "lib/init"

Presses = {}
Press_Counter = {}
Playing = {}
TRACKS = 7
Tracks = {}
PATTERNS = 16
PAGES = 5
Page = 0
Alt_Page = false
Pattern = 1
MODS = 3
Mod = 0
SubSequins = 0
Active_Track = 1
Grid_Dirty = true
Scale_Names = {}
Keys = {0, 0, 0}
for i = 1, #MusicUtil.SCALES do
  table.insert(Scale_Names, MusicUtil.SCALES[i].name)
end
Dance_Index = 1

Play_Note = config.play_note

-- useful for making config errors fail hard and fast
local function norns_assert(cond, msg)
  if not msg then msg = "" end
  if cond then return end
  norns.scripterror(msg)
end

-- get and set current voice

function Get_Current_Voice()
  return 7 * (Active_Track - 1)  + Tracks[Active_Track].id_minor
end

norns_assert(type(Set_Current_Voice) == "function", 'config error: Set_Current_Voice undefined')

-- modules

local Modules = {}

local function setup_module(name, data)
  if not data.enabled then return end
  local found
  local places = {norns.state.lib, norns.state.path, norns.state.data}
  for _, place in ipairs(places) do
    if util.file_exists(place .. name .. '.lua') then
      found = place .. name .. '.lua'
      break
    end
  end
  norns_assert(found, 'config error: module ' .. name .. ' not found')
  local module = dofile(found)
  norns_assert(type(module.init) == "function", 'config error: module ' .. name .. ' must have init()')
  module.init(data.args)
  Modules[name] = module
end

-- notes

function Scale(_) return 0 end

local function build_scale()
  local note_nums = MusicUtil.generate_scale_of_length(params:get('root_note'), params:get('scale'), 127)
  Scale = function (note)
    if note_nums then
      return note_nums[note]
    end
  end
end

-- import / export

local function export_tracks()
  local data = {}
  for i = 1, TRACKS do
    data[i] = {}
    local track = Tracks[i]
    local keys = {
      "id_minor", "probabilities", "divisions", "swings",
      "muted", "bounds", "data",
    }
    for _, k in ipairs(keys) do
      data[i][k] = track[k]
    end
  end
  data[TRACKS + 1] = {}
  local track = Tracks[TRACKS + 1]
  local keys = {
    "probabilities", "divisions", "swings", "lengths",
    "bounds", "data", "selected"
  }
  for _, k in ipairs(keys) do
    data[TRACKS + 1][k] = track[k]
  end
  return data
end

local function import_tracks(data)
  for i = 1, TRACKS do
    local datum = data[i]
    local keys = {
      "id_minor", "probabilities", "divisions", "swings",
      "muted", "bounds", "data"
    }
    for _, k in ipairs(keys) do
      Tracks[i][k] = datum[k]
    end
    for j = 1, 2*PAGES do
      Tracks[i]:make_sequins(j)
      Tracks[i]:update(j)
    end
  end
  local datum = data[TRACKS + 1]
  local keys = {
    "probabilities", "divisions", "swings", "lengths",
    "bounds", "data", "selected"
  }
  for _, k in ipairs(keys) do
    Tracks[TRACKS + 1][k] = datum[k]
  end
end

-- grid

local function nav_bar(x, z)
  if x == 1 then
    -- track button
    if z == 0 then
      if SubSequins > 0 then
        SubSequins = 0
      elseif SubSequins == 0 then
        -- enter track view
        Page = 0
        Mod = 0
        Alt_Page = false
      end
    end
    return z
  elseif x == 3 then
    -- scroll left
    if z == 0 then
      Active_Track = Active_Track - 1 < 1 and TRACKS or Active_Track - 1
      Set_Current_Voice(Get_Current_Voice())
      Engine_UI.screen_callback()
    end
    return z
  elseif x == 4 then
    -- scroll right
    if z == 0 then
      Active_Track = Active_Track + 1 > TRACKS and 1 or Active_Track + 1
      Set_Current_Voice(Get_Current_Voice())
      Engine_UI.screen_callback()
    end
    return z
  elseif x >= 5 + 1 and x <= 5 + PAGES then
    if z ~= 0 then return z end
    if Page == x - 5 then
      -- active page pressed; toggle alt page
      Alt_Page = not Alt_Page
    end
    Page = x - 5
    SubSequins = 0
    return z
  elseif x >= 5 + PAGES + 1 + 1 and x <= 5 + PAGES + 1 + MODS then
    if z ~= 0 then return z end
    if Mod == x - (5 + PAGES + 1) then
      -- active mod pressed
      Mod = 0
    elseif Page ~= 0 then
      Mod = x - (5 + PAGES + 1)
      SubSequins = 0
    end
    return z
  elseif x == 16 then
    -- pattern page pressed
    if z == 0 then
      Mod = 0
      SubSequins = 0
      Page = -1
    end
    return z
  end
end

local function loop_mod(x, y, z)
  local track = Tracks[Active_Track]
  local page = Page
  if Page == -1 then
    track = Tracks[TRACKS+1]
  end
  if Alt_Page then page = page + PAGES end
  if z ~= 0 then return z end
  for i = 1, 16 do
    if Presses[i][y] == 1 and i ~= x then
      -- set new bounds
      if i < x then
        return z, i, x
      else
        return z, x, x
      end
    end
  end
  -- move bounds
  local length
  if track.type == 'track' then
    length = track.bounds[page][Pattern][2] - track.bounds[page][Pattern][1]
  else
    length = track.bounds[2] - track.bounds[1]
  end
  return z, x, math.min(x + length, 16)
end

local function handle_subsequins(x, y, z, handler, default)
  if z ~= 0 then return z end
  local track = Tracks[Active_Track]
  local page = Page
  if Page == -1 then
    track = Tracks[TRACKS+1]
  end
  if Alt_Page then page = page + PAGES end
  local datum
  if track.type == 'track' then
    datum = track.data[page][Pattern][SubSequins]
  else
    datum = track.data[SubSequins]
  end
  if Presses[1][y] == 1 and 1 ~= x then
    -- alter SubSequins length
    if x > #datum then
      for i = #datum, x do
        datum[i] = default
      end
    elseif x < #datum then
      for i = x+1, #datum do
        datum[i] = nil
      end
    end
    return z
  elseif x == 1 then
    for i = 2, 16 do
      if Presses[i][y] == 1 then
        -- remove SubSequins, exit SubSequins mode
        datum = datum[1]
        SubSequins = 0
        return z
      end
    end
  end
  datum[x] = handler(y, datum[x])
  return z
end

local function grid_long_press(x, y)
  -- a long press is one second
  clock.sleep(1)
  Press_Counter[x][y] = nil
  if y == 8 or Mod > 0 or SubSequins > 0 then return end
  if Page == -1 and y == 1 then
    -- copy pattern
    for i = 1, TRACKS do
      local track = Tracks[i]
      track:copy(Tracks[TRACKS+1].data[Tracks[TRACKS+1].selected], x)
    end
    Grid_Dirty = true
    Engine_UI.screen_callback()
  elseif Page == -1 and y == 4 then
    SubSequins = x
    Grid_Dirty = true
    Engine_UI.screen_callback()
  else
    SubSequins = x
    Grid_Dirty = true
    Engine_UI.screen_callback()
  end
end

local function patterns_key(x, y, z)
  if Mod == 1 and y == 4 then
    local press, left, right = loop_mod(x, y, z)
    if left and right then
      Tracks[TRACKS+1].bounds[1] = left
      Tracks[TRACKS+1].bounds[2] = right
    end
    return press
  end
  if SubSequins > 0 and y == 4 then
    return handle_subsequins(x, y, z, function (_, current)
      if x <= #Tracks[TRACKS+1].data[SubSequins] then
        Tracks[TRACKS+1].selected = x
      end
      Tracks[TRACKS+1]:make_sequins()
      return current
    end, 1)
  end
  if SubSequins > 0 and y == 1 then
    if z ~= 0 then return z end
    -- set selection
    Tracks[TRACKS+1].data[SubSequins][Tracks[TRACKS+1].selected] = x
    Tracks[TRACKS+1]:make_sequins()
    return z
  end
  if y == 1 then
    if z ~= 0 then Press_Counter[x][y] = clock.run(grid_long_press, x, y) return z end
    if not Press_Counter[x][y] then return z end
    clock.cancel(Press_Counter[x][y])
    Tracks[TRACKS+1].data[Tracks[TRACKS+1].selected] = x
    Tracks[TRACKS+1]:make_sequins()
    return z
  end
  if y == 4 then
    if z ~= 0 then Press_Counter[x][y] = clock.run(grid_long_press, x, y) return z end
    if not Press_Counter[x][y] then return z end
    clock.cancel(Press_Counter[x][y])
    Tracks[TRACKS+1].selected = x
    return z
  end
  if y == 6 then
    if z ~= 0 then return z end
    Tracks[TRACKS+1].lengths[Tracks[TRACKS+1].selected] = x
    return z
  end
end

local function division_key(x, y, z)
  local track = Tracks[Active_Track]
  local page = Page
  if Alt_Page then page = page + PAGES end
  if y == 2 then
    if z ~= 0 then return z end
    if Page == -1 then
      Tracks[TRACKS+1].divisions = x
      Tracks[TRACKS+1]:update()
    else
      track.divisions[page][Pattern] = x
      track:update()
    end
    return z
  elseif y == 4 then
    if z ~= 0 then return z end
    if Page == -1 then
      Tracks[TRACKS+1].swings = x
      Tracks[TRACKS+1]:update()
    else
      track.swings[page][Pattern] = x
      track:update()
    end
    return z
  end
end

local function probability_key(x, y, z)
  local track = Tracks[Active_Track]
  local page = Page
  if Alt_Page then page = page + PAGES end
  if y < 3 then return end
  if z ~= 0 then return z end
  if Page == -1 then
    Track[TRACKS + 1].probabilities[x] = 7 - y
  else
    track.probabilities[page][Pattern][x] = 7 - y
  end
  return z
end

local function module_key(module, x, y, z)
  if not module.grid_key then return end
  if not type(module.grid_key) == "function" then return end
  return module.grid_key(x, y, z)
end

local function modules_key(x, y, z)
  local ret
  local name = ""
  for key, module in pairs(Modules) do
    local press = module_key(module, x, y, z)
    norns_assert(not ret or not press, 'config error: ' .. name .. ' and ' .. key .. ' both respond to press: (' .. x .. ',' .. y .. ',' .. z .. ')')
    name = key
    ret = ret or press
  end
  return ret
end

local function tracks_key(x, y, z)
  if x == 1 then
    -- select track
    if z ~= 0 then return z end
    Active_Track = y
    Set_Current_Voice(Get_Current_Voice())
    Engine_UI.screen_callback()
    return z
  elseif x == 2 then
    -- mute / unmute track
    if z ~= 0 then return z end
    Tracks[y].muted = not Tracks[y].muted
    return z
  elseif x == 3 then
    if z ~= 0 then return z end
    for i = 1, 2 * PAGES do
      Tracks[y].reset_flag[i] = true
    end
    return z
  else
    -- columns 4 through 16 are for modules!
    return modules_key(x, y, z)
  end
end

local function grid_key(x, y, z)
  local press
  if y == 8 then
    press = nav_bar(x, z)
  elseif Page == 0 then
    -- tracks page
    press = tracks_key(x, y, z)
  elseif Mod == 2 then
    -- division mod
    press = division_key(x, y, z)
  elseif Mod == 3 then
    -- probability mod
    press = probability_key(x, y, z)
  elseif Page == -1 then
    -- pattern page
    press = patterns_key(x, y, z)
  else
    local page = Page
    if Alt_Page then page = page + PAGES end
    press = Tracks[Active_Track].keys[page](x, y, z)
  end
  if z == 0 then press = 0 end
  if press then
    Presses[x][y] = press
    Engine_UI.screen_callback()
    Grid_Dirty = true
  end
end

local function nav_bar_view()
  -- tracks page
  if SubSequins > 0 and Mod == 0 then
    Grid:led(1, 8, Dance_Index % 2 == 1 and 15 or 9)
  else
    Grid:led(1, 8, Page == 0 and 15 or 9)
  end

  -- track scroll
  for i = 1, 2 do
    Grid:led(2+i, 8, 9)
  end

  -- pages
  for x = 1, PAGES do
    if Alt_Page then
      Grid:led(x + 5, 8, x == Page and Dance_Index % 2 == 1 and 15 or 9)
    else
      Grid:led(x + 5, 8, x == Page and 15 or 9)
    end
  end

  -- mods
  for x = 1, MODS do
    Grid:led(x + 5 + PAGES + 1, 8, x == Mod and Dance_Index % 2 == 1 and 15 or 9)
  end

  -- pattern page
  Grid:led(16, 8, Page == -1 and 15 or 9)
end

local function division_view()
  if Page == 0 then
    Mod = 0
    Grid_Dirty = true
    return
  end
  for x = 1, 16 do
    Grid:led(x, 2, 4)
  end
  local page = Page
  if Alt_Page then page = page + PAGES end
  if Page ~= -1 then
    Grid:led(Tracks[Active_Track].divisions[page][Pattern], 2, 15)
    Grid:led(Tracks[Active_Track].swings[page][Pattern], 4, 15)
  else
    Grid:led(Tracks[TRACKS+1].divisions, 2, 15)
    Grid:led(Tracks[TRACKS+1].swings, 4, 15)
  end
end

local function probability_view()
  if Page == 0 then
    Mod = 0
    Grid_Dirty = true
    return
  end
  local page = Page
  if Alt_Page then page = page + PAGES end
  local track = Tracks[Active_Track]
  if Page ~= -1 then
    for x = 1, 16 do
      local value = track.probabilities[page][Pattern][x]
      local left = track.bounds[page][Pattern][1]
      local right = track.bounds[page][Pattern][2]
      local check = x >= left and x <= right
      for i = 4, value, -1 do
        Grid:led(x, 7-i, check and 9 or 4)
      end
      if track.index[page] == x then
        Grid:led(x, 7 - value, 15)
      end
    end
  else
    for x = 1, 16 do
      local value = Tracks[TRACKS+1].probabilities[x]
      local left = Tracks[TRACKS+1].bounds[1]
      local right = Tracks[TRACKS+1].bounds[2]
      local check = x >= left and x <= right
      for i = 4, value, -1 do
        Grid:led(x, 7-i, check and 9 or 4)
      end
      if Tracks[TRACKS+1].index == x then
        Grid:led(x, 7-value, 15)
      end
    end
  end
end

local function light_module(module)
  if not module.display then return end
  if not type(module.display) == "function" then return end
  return module.display()
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

local function check_light_in_list(list, light)
  for _, datum in ipairs(list) do
    if datum[1] == light[2] and datum[2] == light[2] then
      return datum.name
    end
  end
  return false
end

local function validate_lights(module_lights)
  local ret = {}
  for name, lights in pairs(module_lights) do
    norns_assert(type(lights) == "table" and tbl_islist(lights), 'config error: module ' .. name .. '.display() returned non-list')
    for _, light in ipairs(lights) do
      norns_assert(type(light[1]) == 'number' and type(light[2]) == 'number' and type(light[3]) == 'number', 'config error: module ' .. name .. '.display() returned bad light data')
      norns_assert(light[1] > 3 and light[2] < 8, 'config error: module ' .. name .. '.display() attempting to light (' .. light[1] .. ',' .. light[2] .. ')')
      light.name = name
      local clobber = check_light_in_list(ret, light)
      if clobber then
        norns_assert(false, 'config error: modules ' .. clobber .. ' and ' .. name .. ' attempting to light (' .. light[1] .. ',' .. light[2] ..')')
      end
      ret[#ret+1] = light
    end
  end
  return ret
end

local function tracks_view()
  for y = 1, 7 do
    Grid:led(3,y,4)
    Grid:led(2,y,Tracks[y].muted and 4 or 9)
    if Active_Track == y then
      Grid:led(1, y, Playing[y] == 1 and 15 or 12)
    else
      Grid:led(1, y, Playing[y] == 1 and 9 or 4)
    end
  end
  local module_lights = {}
  for name, module in pairs(Modules) do
    module_lights[name] = light_module(module)
  end
  module_lights = validate_lights(module_lights)
  for _, light in ipairs(module_lights) do
    Grid:led(light[1], light[2], light[3])
  end
end

local function patterns_view()
  for x = 1, 16 do
    Grid:led(x, 1, 4)
  end
  local track = Tracks[TRACKS + 1]
  local left = track.bounds[1]
  local right = track.bounds[2]
  if SubSequins > 0 then
    if type(track.data[SubSequins]) == "number" then
      track.data[SubSequins] = {track.data[SubSequins]}
      track:make_sequins()
    end
    local datum = track.data[SubSequins]
    for x = 1, #datum do
      Grid:led(x, 4, 9)
    end
    if track.selected > #datum then
      track.selected = #datum
      Grid_Dirty = true
      return
    end
    Grid:led(track.selected, 4, 12)
    Grid:led(datum[track.selected], 1, 12)
  else
    local datum = track.data[track.selected]
    if type(datum) == "number" then
      Grid:led(datum, 1, 12)
    else
      Grid:led(datum[Dance_Index % #datum + 1], 1, 12)
    end
    Grid:led(Pattern, 1, 15)
    for x = 1, 16 do
      local check = x >= left and x <= right
      Grid:led(x, 4, check and 9 or 4)
    end
    Grid:led(track.selected, 4, 12)
    Grid:led(track.index, 4, Dance_Index % 2 == 1 and 15 or 0)

    for x = 1, track.lengths[Pattern] do
      Grid:led(x, 6, 4)
    end

    Grid:led(track.lengths[Pattern], 6, 9)
    Grid:led(track.lengths[track.selected], 6, 12)
    Grid:led(track.counters, 6, 15)
  end
end

local function page_view()
  if Page == 0 then tracks_view() return
  elseif Page == -1 then patterns_view() return
  end
  local page = Page
  if Alt_Page then page = page + PAGES end
  local track = Tracks[Active_Track]
  local left = track.bounds[page][Pattern][1]
  local right = track.bounds[page][Pattern][2]
  if SubSequins > 0 then
    if type(track.data[page][Pattern][SubSequins]) == "number" then
      track.data[page][Pattern][SubSequins] = {track.data[page][Pattern][SubSequins]}
      track:make_sequins(page, Pattern)
    end
    local datum = track.data[page][Pattern][SubSequins]
    for x = 1, #datum do
      local lights = track.subsequins_displays[page](datum[x], true, false, nil)
      for _, light in ipairs(lights) do
        Grid:led(x, light[1], light[2])
      end
    end
    if not track.overlay[page] then return end
  end
  for x = 1, 16 do
    local datum = track.data[page][Pattern][x]
    datum = type(datum) == "number" and datum or datum[Dance_Index % #datum + 1]
    local check = x >= left and x <= right
    local lights = track.displays[page](datum, check, x == track.index[page], track.counters[page])
    for _, light in ipairs(lights) do
      Grid:led(x, light[1], light[2])
    end
  end
end

local function grid_redraw()
  Grid_Dirty = false
  Grid:all(0)
  -- nav bar
  nav_bar_view()
  -- main view
  if Mod == 1 and Page == 0 then
    Mod = 0
    Grid_Dirty = true
  end
  if Mod == 2 then division_view()
  elseif Mod == 3 then probability_view()
  else page_view()
  end
  for x = 1, 16 do
    for y = 1, 8 do
      if Presses[x][y] == 1 then
        if Press_Counter[x][y] then
          Grid:led(x,y,15)
        else
          Grid:led(x,y,Dance_Index % 2 == 1 and 15 or 9)
        end
      end
    end
  end
  Grid:refresh()
end

-- init

function init()
  -- scale params first so they don't get buried
  params:add{
    type = 'number',
    id = 'root_note',
    name = 'root note',
    min = 0,
    max = 127,
    default = 60,
    formatter = function (param)
      return MusicUtil.note_num_to_name(param:get(), true)
    end,
    action = build_scale
  }
  params:add{
    type = 'option',
    id = 'scale',
    name = 'scale',
    options = Scale_Names,
    default = 5,
    action = build_scale
  }
  params:bang()
  build_scale()

  -- sets up engine and ui
  config.setup()

  -- grid presses
  for x = 1, 16 do
    Presses[x] = {}
    for y = 1, 8 do
      Presses[x][y] = 0
    end
    Press_Counter[x] = {}
  end

  -- tracks setup
  local lattice = Lattice:new()
  Tracks = {}
  for i = 1, TRACKS do
    Tracks[i] = Track.new(i, lattice)
  end
  Tracks[TRACKS+1] = Track.pattern_new(lattice)
  
  -- params
  params.action_read = function (_, _, number)
    local tracks_data = tab.load(norns.state.data .. "/pset_track_data_" .. number .. ".data")
    import_tracks(tracks_data)
  end
  params.action_write = function (_, _, number)
    tab.save(export_tracks(), norns.state.data .. "/pset_track_data_" .. number .. ".data")
  end
  params.action_delete = function (_, _, number)
    if util.file_exists(norns.state.data .. "/pset_track_data_" .. number .. ".data") then
      util.os_capture("rm " .. norns.state.data .. "/pset_track_data_" .. number .. ".data")
    end
  end

  for name, data in pairs(config.modules) do
    setup_module(name, data)
  end

  -- Grid!
  Grid.key = grid_key
  local grid_redraw_metro = metro.init()
  grid_redraw_metro.event = function ()
    if Grid.device and Grid_Dirty then grid_redraw() end
  end

  lattice:new_sprocket{
    division = 1/8,
    order = 1,
    action = function ()
      Dance_Index = Dance_Index % 16 + 1
      Grid_Dirty = true
    end
  }

  -- let's gooooooo!!!
  if grid_redraw_metro then
    grid_redraw_metro:start(1/25)
  end
  lattice:start()
  Engine_UI.screen_callback()
end

-- lightly hijack UI from UI file

function key(n, z)
  for name, module in pairs(Modules) do
    if module.key then
      norns_assert(type(module.key) == "function", 'config error: module ' .. name .. ' defines key; must be callable')
      module.key(n, z)
    end
  end
  Keys[n] = z
  Engine_UI.key(n, z)
end

function enc(n, d)
  for name, module in pairs(Modules) do
    if module.enc then
      norns_assert(type(module.enc) == "function", 'config error: module ' .. name .. ' defines enc; must be callable')
      module.enc(n, d)
    end
  end
  if Keys[1] == 1 then
    Tracks[Active_Track]:set_id_minor(Tracks[Active_Track].id_minor + d)
    Set_Current_Voice(Get_Current_Voice())
    Engine_UI.screen_callback()
    return
  end
  Engine_UI.enc(n, d)
end

function redraw()
  Engine_UI.redraw()
end

-- Track class

Track = {}

function Track.new(id, lattice)
  local t = {
    type = "track",
    id = id,
    id_minor = 0,
    data = {},
    probabilities = {},
    divisions = {},
    swings = {},
    bounds = {},
    sprockets = {},
    index = {},
    sequins = {},
    muted = false,
    counters = {},
    counters_max = {},
    displays = {},
    subsequins_displays = {},
    overlay = {},
    keys = {},
    values = {},
    reset_flag = {},
  }
  setmetatable(t, { __index = Track })
  for i = 1, 2*PAGES do
    local minmax = {
      main = {
        min = 1,
        max = 7,
      }
    }
    local defaults = config.tbl_deep_extend(minmax, config.page, config[config.page.pages[i]])
    t.counters_max[i] = defaults.counter and defaults.counter or 1
    t.reset_flag[i] = false
    t.data[i] = {}
    t.probabilities[i] = {}
    t.divisions[i] = {}
    t.bounds[i] = {}
    t.swings[i] = {}
    t.counters[i] = 1
    t.index[i] = 1
    for n = 1, PATTERNS do
      t.bounds[i][n] = {1, util.clamp(defaults.length, 1, 16)}
      t.swings[i][n] = util.clamp(defaults.swing, 1, 16)
      t.divisions[i][n] = util.clamp(defaults.division, 1, 16)
      t.data[i][n] = {}
      t.probabilities[i][n] = {}
      for j = 1, 16 do
        t.data[i][n][j] = defaults.data
        t.probabilities[i][n][j] = util.clamp(defaults.probability, 1, 4)
      end
    end
    t.sequins[i] = sequins(t.data[i][1])
    t.values[i] = t.sequins[i]()
    t.sequins[i]:select(1)
    t.displays[i] = defaults.main.display
    local subsequins_config = config.tbl_deep_extend(defaults.main, defaults.subsequins)
    t.subsequins_displays[i] = subsequins_config.display
    t.overlay[i] = subsequins_config.overlay
    t.keys[i] = function (x, y, z)
      local page = Page
      if Alt_Page then page = page + PAGES end
      if Mod == 1 then
        local press, left, right = loop_mod(x, y, z)
        if left and right then
          t.bounds[page][Pattern][1] = left
          t.bounds[page][Pattern][2] = right
        end
        return press
      end
      if SubSequins > 0 then
        if y < subsequins_config.min or y > subsequins_config.max then return end
        return handle_subsequins(x, y, z, subsequins_config.key, defaults.data)
      end
      if y < defaults.main.min or y > defaults.main.max then return end
      if z ~= 0 then Press_Counter[x][y] = clock.run(grid_long_press, x, y) return z end
      if not Press_Counter[x][y] then return z end
      clock.cancel(Press_Counter[x][y])
      t.data[i][Pattern][x] = defaults.main.key(y, t.data[i][Pattern][x])
      return z
    end
    t.sprockets[i] = lattice:new_sprocket{
      division = t.divisions[i][1] / (16 * t.counters_max[i]),
      order = defaults.priority,
      swing = t.swings[i][1] * 100 / 16,
      action = function ()
        t.counters[i] = t.counters[i] % t.counters_max[i] + 1
        if t.counters[i] == 1 then
          t:increment(i)
        end
        local cond = (i <= PAGES and Page == i) or Page == i - PAGES
        if cond and Active_Track == t.id then Grid_Dirty = true end
        if Page == 0 then Grid_Dirty = true end
        local r = math.random()
        if r > t.probabilities[i][Pattern][t.index[i]] then return end
        defaults.action(t, config.page.pages[i], t.sequins[i](), t.counters[i])
      end
    }
  end
  return t
end

function Track.pattern_new(lattice)
  local defaults = config.page
  local t = {
    type = "pattern",
    id = TRACKS + 1,
    data = {},
    probabilities = {},
    divisions = util.clamp(defaults.division, 1, 16),
    bounds = {1, 1},
    index = 1,
    swings = util.clamp(defaults.swing, 1, 16),
    counters = 0,
    selected = 1,
    lengths = {},
    sequins = nil,
    reset_flag = false
  }
  setmetatable(t, { __index = Track })
  for n = 1, PATTERNS do
    t.data[n] = 1
    t.probabilities[n] = defaults.probability
    t.lengths[n] = defaults.length
  end
  t.sequins = sequins.new(t.data)
  t.sprockets = lattice:new_sprocket{
    division = t.divisions / 16,
    order = 1,
    swing = 100 * t.swings / 16,
    action = function ()
      t.counters = t.counters % t.lengths[Pattern] + 1
      if t.counters == 1 then
        t:increment()
      end
      if Page == -1 then
        Grid_Dirty = true
      end
      local r = math.random()
      if r > t.probabilities[Pattern] / 4 then return end
      Pattern = t.sequins()
      for i = 1, TRACKS do
        Tracks[i]:update()
        for j = 1, 2*PAGES do
          Tracks[i].reset_flag[j] = true
          Tracks[i]:make_sequins(j)
        end
      end
    end
  }
  return t
end

function Track:update()
  if self.type ~= 'track' then
    self.sprockets:set_division(self.divisions / 16)
    self.sprockets:set_swing(self.swings * 100 /16)
  else
    for i = 1, 2*PAGES do
      self.sprockets[i]:set_division(self.divisions[i][Pattern] / (self.counters_max[i] * 16))
      self.sprockets[i]:set_swing(self.swings[i][Pattern] * 100 / 16)
    end
  end
end

function Track:make_sequins(i)
  local s = {}
  if self.type == 'pattern' then
    for j = 1, 16 do
      if type(self.data[j]) ~= "number" then
        s[j] = sequins(self.data[j])
      else
        s[j] = self.data[j]
      end
    end
    self.sequins:settable(s)
  else
    for j = 1, 16 do
      if type(self.data[i][Pattern][j]) ~= "number" then
        s[j] = sequins(self.data[i][Pattern][j])
      else
        s[j] = self.data[i][Pattern][j]
      end
    end
    self.sequins[i]:settable(s)
  end
end

function Track:increment(i)
  if self.type == 'pattern' then
    if self.reset_flag == true then
      self.index = self.bounds[1]
      self.reset_flag = false
    elseif self.index + 1 > self.bounds[2] or self.index + 1 < self.bounds[1] then
      self.index = self.bounds[1]
    else
      self.index = self.index + 1
    end
    self.sequins:select(self.index)
  else
    if self.reset_flag[i] == true then
      self.index[i] = self.bounds[i][Pattern][1]
      self.reset_flag[i] = false
    elseif self.index[i] + 1 < self.bounds[i][Pattern][1] or self.index[i] + 1 > self.bounds[i][Pattern][2] then
      self.index[i] = self.bounds[i][Pattern][1]
    else
      self.index[i] = self.index[i] + 1
    end
    self.sequins[i]:select(self.index[i])
  end
end

function Track:set_id_minor(n)
  while n > 6 do
    n = n - 7
  end
  while n < 0 do
    n = n + 7
  end
  self.id_minor = n
end

function Track:get(name)
  local list = config.page.pages
  local i
  for k, v in ipairs(list) do
    if v == name then i = k break end
  end
  norns_assert(i, 'config error: track:get() called with ' .. name)
  return self.values[i]
end

function Track:set(name, datum)
  local list = config.page.pages
  local i
  for k, v in ipairs(list) do
    if v == name then i = k break end
  end
  norns_assert(i, 'config error: track:set() called with ' .. name)
  self.values[i] = datum
end

function Track:copy(source, target)
  for i = 1, 2*PAGES do
    self.divisions[i][target] = self.divisions[i][source]
    for j = 1, 16 do
      self.probabilities[i][target][j] = self.probabilities[i][source][j]
      if type(self.data[i][target][j]) ~= "number" then
        self.data[i][target][j] = {}
        for k = 1, #self.data[i][source][j] do
          self.data[i][target][j][k] = self.data[i][source][j][k]
        end
      else
        self.data[i][target][j] = self.data[i][source][j]
      end
    end
    for k = 1, 2 do
      self.bounds[i][target][k] = self.bounds[i][source][k]
    end
    if Pattern == target then
      self:make_sequins(i)
    end
  end
end
